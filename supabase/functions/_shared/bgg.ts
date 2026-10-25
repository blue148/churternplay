// Shared BoardGameGeek XML API client used by the `bgg-lookup` and
// `add-game-to-library` edge functions. Keeps the BGG token server-side only.

import { normalizeGameTypes } from './game-type-mapping.ts';

const BGG_API_TOKEN = Deno.env.get('BGG_API_TOKEN');
const BGG_API_BASE_URL = 'https://boardgamegeek.com/xmlapi2';

export interface BggGameDetails {
  name: string;
  year: number | null;
  cover_image: string | null;
  publisher: string | null;
  min_players: number | null;
  max_players: number | null;
  playtime_minutes: number | null;
  min_age: number | null;
  game_category: string[] | null;
  game_mechanic: string[] | null;
  game_type: string[];
  game_family: string[] | null;
  description: string | null;
}

export interface BggSearchResult {
  bgg_id: number;
  name: string;
  year: number | null;
}

export class BggApiError extends Error {
  constructor(public status: number) {
    super(`BGG API request failed (${status})`);
  }
}

async function fetchBggXml(url: string): Promise<string> {
  const headers: Record<string, string> = {
    'Accept': 'application/xml',
    'User-Agent': 'BoardGameLibrary/1.0',
  };

  // Add Authorization header if token is available
  if (BGG_API_TOKEN) {
    headers['Authorization'] = `Bearer ${BGG_API_TOKEN}`;
  }

  const bggResponse = await fetch(url, { headers });

  if (!bggResponse.ok) {
    const errorText = await bggResponse.text();
    console.error('BGG API error:', bggResponse.status, errorText);
    throw new BggApiError(bggResponse.status);
  }

  return await bggResponse.text();
}

export async function fetchBggDetails(bggId: number): Promise<BggGameDetails> {
  const xmlText = await fetchBggXml(`${BGG_API_BASE_URL}/thing?id=${bggId}&stats=1`);
  return parseThingResponse(xmlText);
}

export async function searchBgg(searchName: string): Promise<BggSearchResult[]> {
  const xmlText = await fetchBggXml(
    `${BGG_API_BASE_URL}/search?query=${encodeURIComponent(searchName)}&type=boardgame`
  );
  return parseSearchResponse(xmlText);
}

// Simple regex-based XML parsing for BGG responses.
// For production, consider using a proper XML parser library.

function parseThingResponse(xmlText: string): BggGameDetails {
  const nameMatch = xmlText.match(/<name[^>]*type="primary"[^>]*value="([^"]+)"/);
  const yearMatch = xmlText.match(/<yearpublished[^>]*value="([^"]+)"/);
  const imageMatch = xmlText.match(/<image>([^<]+)<\/image>/);
  const thumbnailMatch = xmlText.match(/<thumbnail>([^<]+)<\/thumbnail>/);
  const minPlayersMatch = xmlText.match(/<minplayers[^>]*value="([^"]+)"/);
  const maxPlayersMatch = xmlText.match(/<maxplayers[^>]*value="([^"]+)"/);
  const playtimeMatch = xmlText.match(/<playingtime[^>]*value="([^"]+)"/);
  const minAgeMatch = xmlText.match(/<minage[^>]*value="([^"]+)"/);
  const descriptionMatch = xmlText.match(/<description>([^<]+)<\/description>/);

  // Extract publishers
  const publisherMatches = [...xmlText.matchAll(/<link[^>]*type="boardgamepublisher"[^>]*value="([^"]+)"/g)];
  const publishers = publisherMatches.map(m => m[1]);

  // Extract categories
  const categoryMatches = [...xmlText.matchAll(/<link[^>]*type="boardgamecategory"[^>]*value="([^"]+)"/g)];
  const categories = categoryMatches.map(m => m[1]);

  // Extract mechanics
  const mechanicMatches = [...xmlText.matchAll(/<link[^>]*type="boardgamemechanic"[^>]*value="([^"]+)"/g)];
  const mechanics = mechanicMatches.map(m => m[1]);

  // Extract families (for game_type - broader classifications)
  const familyMatches = [...xmlText.matchAll(/<link[^>]*type="boardgamefamily"[^>]*value="([^"]+)"/g)];
  const families = familyMatches.map(m => m[1]);

  return {
    name: nameMatch?.[1] ? decodeHtmlEntities(nameMatch[1]) : 'Unknown Game',
    year: yearMatch?.[1] ? parseInt(yearMatch[1]) : null,
    cover_image: imageMatch?.[1] || thumbnailMatch?.[1] || null,
    publisher: publishers[0] ? decodeHtmlEntities(publishers[0]) : null,
    min_players: minPlayersMatch?.[1] ? parseInt(minPlayersMatch[1]) : null,
    max_players: maxPlayersMatch?.[1] ? parseInt(maxPlayersMatch[1]) : null,
    playtime_minutes: playtimeMatch?.[1] ? parseInt(playtimeMatch[1]) : null,
    min_age: minAgeMatch?.[1] ? parseInt(minAgeMatch[1]) : null,
    game_category: categories.length > 0 ? categories : null,
    game_mechanic: mechanics.length > 0 ? mechanics : null,
    // game_type holds the curated parent game types derived from the raw BGG
    // mechanics/categories — this is what the apps' "Game Type" filter shows.
    game_type: normalizeGameTypes(mechanics, categories),
    // game_family keeps the raw BGG family links for reference.
    game_family: families.length > 0 ? families : null,
    description: descriptionMatch?.[1] ? decodeHtmlEntities(descriptionMatch[1]) : null,
  };
}

function parseSearchResponse(xmlText: string): BggSearchResult[] {
  // Parse each <item> on its own so a missing <yearpublished> neither drops the
  // game nor lets the match bleed into the next item.
  const items = [...xmlText.matchAll(/<item\b[^>]*\bid="(\d+)"[^>]*>([\s\S]*?)<\/item>/g)];

  return items.flatMap(([, id, body]) => {
    const nameMatch =
      body.match(/<name[^>]*type="primary"[^>]*value="([^"]+)"/) ??
      body.match(/<name[^>]*value="([^"]+)"/);
    if (!nameMatch) return [];
    const yearMatch = body.match(/<yearpublished[^>]*value="(-?\d+)"/);
    return [{
      bgg_id: parseInt(id),
      name: decodeHtmlEntities(nameMatch[1]),
      year: yearMatch ? parseInt(yearMatch[1]) : null,
    }];
  });
}

function decodeHtmlEntities(text: string): string {
  const entities: Record<string, string> = {
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#039;': "'",
    '&rsquo;': "'",
    '&lsquo;': "'",
    '&rdquo;': '"',
    '&ldquo;': '"',
  };

  return text.replace(/&[a-z]+;|&#\d+;/gi, match => entities[match] || match);
}
