// Supabase Edge Function to permanently delete the calling user's account.
//
// A client cannot delete its own auth user — auth.admin.deleteUser() requires
// the service-role key, which must never ship in the app. This function
// authenticates the caller via their JWT, then uses a service-role client to
// remove their avatar files and delete the auth user. The user_id is always
// taken from the verified JWT, never the request body, so a user can only ever
// delete themselves.
//
// Relational data (profiles, user_library, user_wishlist, game_sessions,
// session_victories, user_friends, shared_library_access) is removed via
// ON DELETE CASCADE from auth.users. Storage objects are NOT cascaded, so the
// user's avatar files are deleted explicitly first.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

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
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { status: 405, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  // Require a valid user JWT — identifies which account to delete.
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(
      JSON.stringify({ error: 'Unauthorized' }),
      { status: 401, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  // Authenticate the caller with an anon client scoped to their JWT.
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
    return new Response(
      JSON.stringify({ error: 'Unauthorized' }),
      { status: 401, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  try {
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!serviceRoleKey) {
      console.error('SUPABASE_SERVICE_ROLE_KEY not configured');
      return new Response(
        JSON.stringify({ error: 'Server configuration error' }),
        { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    }

    // Privileged client for storage cleanup + user deletion.
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      serviceRoleKey
    );

    // 1. Delete the user's avatar files (avatars/{userId}/*). Not cascaded by FKs.
    //    Best-effort: a storage failure should not block account deletion.
    const { data: avatarFiles, error: listError } = await adminClient.storage
      .from('avatars')
      .list(user.id);

    if (listError) {
      console.error('Failed to list avatar files (continuing):', listError.message);
    } else if (avatarFiles && avatarFiles.length > 0) {
      const paths = avatarFiles.map((f) => `${user.id}/${f.name}`);
      const { error: removeError } = await adminClient.storage
        .from('avatars')
        .remove(paths);
      if (removeError) {
        console.error('Failed to remove avatar files (continuing):', removeError.message);
      }
    }

    // 2. Delete the auth user. Cascades remove all relational data.
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(user.id);
    if (deleteError) {
      console.error('Failed to delete user:', deleteError.message);
      return new Response(
        JSON.stringify({ error: 'Failed to delete account' }),
        { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    }

    console.log(`Account deleted: ${user.id}`);

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  } catch (error) {
    console.error('Error in delete-account function:', error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Unknown error',
      }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }
});
