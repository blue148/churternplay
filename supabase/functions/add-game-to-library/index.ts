// Supabase Edge Function to add a game to the calling user's library.
//
// shared_games writes are admin-only under RLS, so clients can't create the
// shared row themselves. This function authenticates the caller via their JWT,
// resolves (or creates) the shared_games row with a service-role client — using
// BGG details fetched server-side, never client-supplied game data — and then
// inserts the user_library row. The user_id always comes from the verified JWT.
//
// Request body:
//   { bggId: number, barcode?: string }   — preferred; dedupes by bgg_id
//   { barcode: string, name: string, publisher?: string }
//                                          — bare entry when a barcode lookup
//                                            found a name but no BGG match
//
// Response: { status: 'added' | 'already_in_library', game: <shared_games row> }

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { BggApiError, fetchBggDetails } from '../_shared/bgg.ts';

interface AddGameRequest {
  bggId?: number;
  barcode?: string;
  name?: string;
  publisher?: string;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const MANUAL_BARCODE_PREFIX = 'MANUAL-';

// Postgres unique_violation
const UNIQUE_VIOLATION = '23505';

const json = (payload: unknown, status = 200) =>
  new Response(JSON.stringify(payload), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  });

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        ...corsHeaders,
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
      },
    });
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  // Require a valid user JWT — identifies whose library to add to.
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return json({ error: 'Unauthorized' }, 401);
  }

  const authClient = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: authHeader } } }
  );

  // Pass the JWT explicitly: without a session, newer auth-js versions
  // ignore the global Authorization header and return AuthSessionMissingError.
  const jwt = authHeader.replace(/^Bearer\s+/i, '');
  const { data: { user }, error: authError } = await authClient.auth.getUser(jwt);
  if (authError || !user) {
    return json({ error: 'Unauthorized' }, 401);
  }

  try {
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!serviceRoleKey) {
      console.error('SUPABASE_SERVICE_ROLE_KEY not configured');
      return json({ error: 'Server configuration error' }, 500);
    }

    // Privileged client for shared_games writes (admin-only under RLS).
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      serviceRoleKey
    );

    const body: AddGameRequest = await req.json();
    const bggId = typeof body.bggId === 'number' ? body.bggId : undefined;
    const barcode = body.barcode?.trim() || undefined;
    const name = body.name?.trim() || undefined;

    if (barcode?.startsWith(MANUAL_BARCODE_PREFIX)) {
      return json({ error: 'Invalid barcode' }, 400);
    }

    let game: Record<string, unknown> | null = null;

    if (bggId) {
      const { data: existing, error: lookupError } = await adminClient
        .from('shared_games')
        .select()
        .eq('bgg_id', bggId)
        .limit(1)
        .maybeSingle();
      if (lookupError) throw lookupError;

      if (existing) {
        game = existing;
        // Upgrade a placeholder barcode to the real one now that we have it.
        const existingBarcode = existing.barcode as string | null;
        if (barcode && existingBarcode?.startsWith(MANUAL_BARCODE_PREFIX)) {
          const { data: updated, error: updateError } = await adminClient
            .from('shared_games')
            .update({ barcode })
            .eq('id', existing.id)
            .select()
            .single();
          // A unique violation means another row already owns this barcode —
          // keep the placeholder rather than failing the add.
          if (updateError && updateError.code !== UNIQUE_VIOLATION) throw updateError;
          if (updated) game = updated;
        }
      } else {
        const details = await fetchBggDetails(bggId);
        const { data: inserted, error: insertError } = await adminClient
          .from('shared_games')
          .upsert(
            {
              // Games without a scanned barcode get a stable placeholder so the
              // unique barcode column is satisfied without colliding.
              barcode: barcode ?? `${MANUAL_BARCODE_PREFIX}${bggId}-${Date.now()}`,
              bgg_id: bggId,
              name: details.name,
              publisher: details.publisher,
              year: details.year?.toString() ?? null,
              cover_image: details.cover_image,
              min_players: details.min_players,
              max_players: details.max_players,
              playtime_minutes: details.playtime_minutes,
              game_type: details.game_type ?? [],
              game_category: details.game_category ?? [],
              game_mechanic: details.game_mechanic ?? [],
            },
            { onConflict: 'barcode' }
          )
          .select()
          .single();
        if (insertError) throw insertError;
        game = inserted;
      }
    } else if (barcode && name) {
      // No BGG match — reuse an existing row for this barcode, else create a
      // minimal entry from the barcode lookup.
      const { data: existing, error: lookupError } = await adminClient
        .from('shared_games')
        .select()
        .eq('barcode', barcode)
        .maybeSingle();
      if (lookupError) throw lookupError;

      if (existing) {
        game = existing;
      } else {
        const { data: inserted, error: insertError } = await adminClient
          .from('shared_games')
          .insert({
            barcode,
            name,
            publisher: body.publisher?.trim() || null,
          })
          .select()
          .single();
        if (insertError) throw insertError;
        game = inserted;
      }
    } else {
      return json({ error: 'Either bggId, or barcode and name, are required' }, 400);
    }

    // The library row is written as the caller, so user_library RLS still applies.
    const { error: libraryError } = await authClient
      .from('user_library')
      .insert({ user_id: user.id, game_id: game!.id });

    if (libraryError) {
      if (libraryError.code === UNIQUE_VIOLATION) {
        return json({ status: 'already_in_library', game });
      }
      throw libraryError;
    }

    return json({ status: 'added', game });
  } catch (error) {
    if (error instanceof BggApiError) {
      return json({ error: 'BGG API request failed', status: error.status }, 502);
    }

    console.error('Error in add-game-to-library function:', error);
    return json(
      { error: error instanceof Error ? error.message : 'Unknown error' },
      500
    );
  }
});
