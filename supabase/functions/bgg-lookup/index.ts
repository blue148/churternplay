// Supabase Edge Function to securely lookup BGG data
// This keeps the BGG API token server-side only

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { BggApiError, fetchBggDetails, searchBgg } from '../_shared/bgg.ts';

interface BggLookupRequest {
  bggId?: number;
  searchName?: string;
}

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

  try {
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { status: 405, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    }

    // Require a valid user JWT — prevents unauthenticated callers from burning API quota
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    }

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    );

    // Pass the JWT explicitly: without a session, newer auth-js versions
    // ignore the global Authorization header and return AuthSessionMissingError.
    const jwt = authHeader.replace(/^Bearer\s+/i, '');
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser(jwt);
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    }

    const body: BggLookupRequest = await req.json();
    const { bggId, searchName } = body;

    let gameData: unknown;
    if (bggId) {
      // Lookup by BGG ID
      gameData = await fetchBggDetails(bggId);
    } else if (searchName) {
      // Search by name
      gameData = { results: await searchBgg(searchName) };
    } else {
      return new Response(
        JSON.stringify({ error: 'Either bggId or searchName is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    }

    return new Response(
      JSON.stringify(gameData),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders,
        }
      }
    );

  } catch (error) {
    if (error instanceof BggApiError) {
      return new Response(
        JSON.stringify({
          error: 'BGG API request failed',
          status: error.status
        }),
        { status: error.status, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    }

    console.error('Error in bgg-lookup function:', error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Unknown error'
      }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders,
        }
      }
    );
  }
});
