import { createClient } from '@supabase/supabase-js';
import { config } from 'dotenv';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
config({ path: resolve(__dirname, '../.env') });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY in .env');
}

const supabase = createClient(supabaseUrl, supabaseAnonKey);

// ─── Test data ────────────────────────────────────────────────────────────────

const TEST_GAMES = [
  { name: 'Catan',              bgg_id: 13,     publisher: 'KOSMOS',            year: '1995', min_players: 3, max_players: 4, playtime_minutes: 120, barcode: 'TEST-BGG-13'     },
  { name: 'Ticket to Ride',     bgg_id: 9209,   publisher: 'Days of Wonder',    year: '2004', min_players: 2, max_players: 5, playtime_minutes: 75,  barcode: 'TEST-BGG-9209'   },
  { name: 'Pandemic',           bgg_id: 30549,  publisher: 'Z-Man Games',       year: '2008', min_players: 2, max_players: 4, playtime_minutes: 45,  barcode: 'TEST-BGG-30549'  },
  { name: 'Carcassonne',        bgg_id: 822,    publisher: 'Hans im Glück',     year: '2000', min_players: 2, max_players: 5, playtime_minutes: 45,  barcode: 'TEST-BGG-822'    },
  { name: '7 Wonders',          bgg_id: 68448,  publisher: 'Repos Production',  year: '2010', min_players: 2, max_players: 7, playtime_minutes: 30,  barcode: 'TEST-BGG-68448'  },
  { name: 'Dominion',           bgg_id: 36218,  publisher: 'Rio Grande Games',  year: '2008', min_players: 2, max_players: 4, playtime_minutes: 30,  barcode: 'TEST-BGG-36218'  },
  { name: 'Agricola',           bgg_id: 31260,  publisher: 'Lookout Games',     year: '2007', min_players: 1, max_players: 5, playtime_minutes: 150, barcode: 'TEST-BGG-31260'  },
  { name: 'Splendor',           bgg_id: 148228, publisher: 'Space Cowboys',     year: '2014', min_players: 2, max_players: 4, playtime_minutes: 30,  barcode: 'TEST-BGG-148228' },
  { name: 'Puerto Rico',        bgg_id: 3076,   publisher: 'Alea',              year: '2002', min_players: 2, max_players: 5, playtime_minutes: 90,  barcode: 'TEST-BGG-3076'   },
  { name: 'Power Grid',         bgg_id: 2651,   publisher: 'Rio Grande Games',  year: '2004', min_players: 2, max_players: 6, playtime_minutes: 120, barcode: 'TEST-BGG-2651'   },
  { name: 'Wingspan',           bgg_id: 266192, publisher: 'Stonemaier Games',  year: '2019', min_players: 1, max_players: 5, playtime_minutes: 70,  barcode: 'TEST-BGG-266192' },
  { name: 'Azul',               bgg_id: 230802, publisher: 'Plan B Games',      year: '2017', min_players: 2, max_players: 4, playtime_minutes: 45,  barcode: 'TEST-BGG-230802' },
  { name: 'Codenames',          bgg_id: 178900, publisher: 'Czech Games Edition', year: '2015', min_players: 2, max_players: 8, playtime_minutes: 15, barcode: 'TEST-BGG-178900' },
  { name: 'Terraforming Mars',  bgg_id: 167791, publisher: 'FryxGames',         year: '2016', min_players: 1, max_players: 5, playtime_minutes: 120, barcode: 'TEST-BGG-167791' },
  { name: 'Root',               bgg_id: 237182, publisher: 'Leder Games',       year: '2018', min_players: 2, max_players: 4, playtime_minutes: 90,  barcode: 'TEST-BGG-237182' },
  { name: 'Everdell',           bgg_id: 199792, publisher: 'Starling Games',    year: '2018', min_players: 1, max_players: 4, playtime_minutes: 80,  barcode: 'TEST-BGG-199792' },
  { name: 'Brass: Birmingham',  bgg_id: 224517, publisher: 'Roxley',            year: '2018', min_players: 2, max_players: 4, playtime_minutes: 120, barcode: 'TEST-BGG-224517' },
  { name: 'Gloomhaven',         bgg_id: 174430, publisher: 'Cephalofair Games', year: '2017', min_players: 1, max_players: 4, playtime_minutes: 120, barcode: 'TEST-BGG-174430' },
];

const TEST_USERS = [
  { email: 'alice@test.liberludorum.com',   password: 'TestUser123!', username: 'alice_gamer',    fullName: 'Alice Chen'      },
  { email: 'bob@test.liberludorum.com',     password: 'TestUser123!', username: 'bob_plays',      fullName: 'Bob Martinez'    },
  { email: 'charlie@test.liberludorum.com', password: 'TestUser123!', username: 'charlie_boards', fullName: 'Charlie Nguyen'  },
];

// Overlap is intentional — useful for "friends who own this game" testing
const USER_LIBRARIES: Record<string, string[]> = {
  alice_gamer: [
    'Catan', 'Ticket to Ride', 'Pandemic', 'Carcassonne', '7 Wonders',
    'Wingspan', 'Azul', 'Codenames', 'Terraforming Mars', 'Root',
  ],
  bob_plays: [
    'Catan', 'Dominion', 'Agricola', 'Splendor', 'Power Grid',
    'Wingspan', 'Azul', 'Everdell', 'Brass: Birmingham', 'Gloomhaven',
  ],
  charlie_boards: [
    'Ticket to Ride', '7 Wonders', 'Carcassonne', 'Dominion', 'Puerto Rico',
    'Codenames', 'Terraforming Mars', 'Root', 'Everdell', 'Gloomhaven',
  ],
};

// ─── Helpers ──────────────────────────────────────────────────────────────────

function log(msg: string) { console.log(`  ${msg}`); }
function section(msg: string) { console.log(`\n▶ ${msg}`); }

async function signInOrSignUp(email: string, password: string, username: string, fullName: string): Promise<string> {
  const { data: signUpData, error: signUpError } = await supabase.auth.signUp({
    email,
    password,
    options: { data: { username, full_name: fullName } },
  });

  let userId: string;
  if (!signUpError && signUpData.session) {
    log(`Created new account: ${email}`);
    userId = signUpData.user!.id;
  } else {
    // Account already exists — sign in
    const { data: signInData, error: signInError } = await supabase.auth.signInWithPassword({ email, password });
    if (signInError) throw new Error(`Could not sign in as ${email}: ${signInError.message}`);
    log(`Signed in to existing account: ${email}`);
    userId = signInData.user.id;
  }

  // Backfill full_name for pre-existing accounts (handle_new_user only sets it on creation)
  const { error: updateError } = await supabase
    .from('profiles')
    .update({ full_name: fullName })
    .eq('id', userId);
  if (updateError) throw new Error(`Could not set full_name for ${email}: ${updateError.message}`);

  return userId;
}

async function ensureGamesExist(): Promise<Map<string, string>> {
  const gameIdByName = new Map<string, string>();

  for (const game of TEST_GAMES) {
    // Check by BGG ID first
    const { data: existing } = await supabase
      .from('shared_games')
      .select('id, name')
      .eq('bgg_id', game.bgg_id)
      .maybeSingle();

    if (existing) {
      gameIdByName.set(game.name, existing.id);
      log(`Found existing game: ${game.name} (${existing.id})`);
      continue;
    }

    // Try to insert — fall back to barcode conflict lookup
    const { data: inserted, error } = await supabase
      .from('shared_games')
      .insert(game)
      .select('id')
      .single();

    if (!error && inserted) {
      gameIdByName.set(game.name, inserted.id);
      log(`Inserted game: ${game.name} (${inserted.id})`);
      continue;
    }

    // Barcode conflict — fetch the conflicting row
    if (error?.code === '23505') {
      const { data: conflict } = await supabase
        .from('shared_games')
        .select('id')
        .eq('barcode', game.barcode)
        .single();
      if (conflict) {
        gameIdByName.set(game.name, conflict.id);
        log(`Reused existing game (barcode conflict): ${game.name}`);
        continue;
      }
    }

    throw new Error(`Failed to ensure game "${game.name}": ${error?.message}`);
  }

  return gameIdByName;
}

async function addLibrary(userId: string, username: string, gameIdByName: Map<string, string>) {
  const gameNames = USER_LIBRARIES[username] ?? [];
  for (const name of gameNames) {
    const gameId = gameIdByName.get(name);
    if (!gameId) { log(`  ⚠ No game ID for "${name}", skipping`); continue; }

    const { error } = await supabase
      .from('user_library')
      .insert({ user_id: userId, game_id: gameId });

    if (error && error.code !== '23505') throw new Error(`Library insert failed for ${name}: ${error.message}`);
    log(`  + ${name}${error ? ' (already in library)' : ''}`);
  }
}

async function sendFriendRequest(fromId: string, toId: string): Promise<string> {
  const { data, error } = await supabase
    .from('user_friends')
    .insert({ user_id: fromId, friend_id: toId, status: 'pending' })
    .select('id')
    .single();

  if (error?.code === '23505') {
    // Already exists — fetch the row id
    const { data: existing } = await supabase
      .from('user_friends')
      .select('id')
      .eq('user_id', fromId)
      .eq('friend_id', toId)
      .single();
    return existing!.id;
  }
  if (error) throw new Error(`Friend request failed: ${error.message}`);
  return data.id;
}

async function acceptFriendRequest(requestId: string) {
  const { error } = await supabase
    .from('user_friends')
    .update({ status: 'accepted' })
    .eq('id', requestId);
  if (error) throw new Error(`Accept friend request failed: ${error.message}`);
}

async function shareLibrary(ownerId: string, viewerId: string, access: 'view' | 'suggest' = 'view') {
  const { error } = await supabase
    .from('shared_library_access')
    .insert({ owner_id: ownerId, viewer_id: viewerId, access_level: access, granted_at: new Date().toISOString() });
  if (error && error.code !== '23505') throw new Error(`Library share failed: ${error.message}`);
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  console.log('═══════════════════════════════════════════');
  console.log('  Liber Ludorum — Test User Seed Script');
  console.log('═══════════════════════════════════════════');

  section('Creating / signing in test users');
  const userIds: Record<string, string> = {};
  for (const u of TEST_USERS) {
    userIds[u.username] = await signInOrSignUp(u.email, u.password, u.username, u.fullName);
  }

  // Ensure games exist while authenticated (RLS requires auth for inserts)
  section('Ensuring test games exist in shared_games');
  const gameIdByName = await ensureGamesExist();

  section('Populating libraries');
  for (const u of TEST_USERS) {
    log(`${u.username}:`);
    // Sign in as this user so RLS inserts work
    await supabase.auth.signInWithPassword({ email: u.email, password: u.password });
    await addLibrary(userIds[u.username], u.username, gameIdByName);
  }

  section('Setting up friend relationships');
  // Alice → Bob (accepted)
  await supabase.auth.signInWithPassword({ email: TEST_USERS[0].email, password: TEST_USERS[0].password });
  const aliceToBobId = await sendFriendRequest(userIds.alice_gamer, userIds.bob_plays);
  log('Alice sent friend request to Bob');

  // Alice → Charlie (accepted)
  const aliceToCharlieId = await sendFriendRequest(userIds.alice_gamer, userIds.charlie_boards);
  log('Alice sent friend request to Charlie');

  // Bob accepts Alice, then requests Charlie
  await supabase.auth.signInWithPassword({ email: TEST_USERS[1].email, password: TEST_USERS[1].password });
  await acceptFriendRequest(aliceToBobId);
  log('Bob accepted Alice\'s friend request');
  const bobToCharlieId = await sendFriendRequest(userIds.bob_plays, userIds.charlie_boards);
  log('Bob sent friend request to Charlie');

  // Charlie accepts both
  await supabase.auth.signInWithPassword({ email: TEST_USERS[2].email, password: TEST_USERS[2].password });
  await acceptFriendRequest(aliceToCharlieId);
  log('Charlie accepted Alice\'s friend request');
  await acceptFriendRequest(bobToCharlieId);
  log('Charlie accepted Bob\'s friend request');

  section('Setting up library sharing');
  // Alice shares with Bob (view)
  await supabase.auth.signInWithPassword({ email: TEST_USERS[0].email, password: TEST_USERS[0].password });
  await shareLibrary(userIds.alice_gamer, userIds.bob_plays, 'view');
  log('Alice → Bob (view)');
  await shareLibrary(userIds.alice_gamer, userIds.charlie_boards, 'view');
  log('Alice → Charlie (view)');

  // Bob shares with Alice + Charlie
  await supabase.auth.signInWithPassword({ email: TEST_USERS[1].email, password: TEST_USERS[1].password });
  await shareLibrary(userIds.bob_plays, userIds.alice_gamer, 'view');
  log('Bob → Alice (view)');
  await shareLibrary(userIds.bob_plays, userIds.charlie_boards, 'suggest');
  log('Bob → Charlie (suggest)');

  // Charlie shares with Bob
  await supabase.auth.signInWithPassword({ email: TEST_USERS[2].email, password: TEST_USERS[2].password });
  await shareLibrary(userIds.charlie_boards, userIds.bob_plays, 'view');
  log('Charlie → Bob (view)');

  console.log('\n═══════════════════════════════════════════');
  console.log('  Done! Test accounts ready:');
  console.log('═══════════════════════════════════════════');
  for (const u of TEST_USERS) {
    console.log(`  ${u.fullName.padEnd(16)}  @${u.username.padEnd(16)}  ${u.email}  /  ${u.password}`);
  }
  console.log('\n  Library overlap for testing:');
  console.log('  • Catan             → Alice, Bob');
  console.log('  • Ticket to Ride    → Alice, Charlie');
  console.log('  • Carcassonne       → Alice, Charlie');
  console.log('  • 7 Wonders         → Alice, Charlie');
  console.log('  • Dominion          → Bob, Charlie');
  console.log('  • Wingspan          → Alice, Bob');
  console.log('  • Azul              → Alice, Bob');
  console.log('  • Codenames         → Alice, Charlie');
  console.log('  • Terraforming Mars → Alice, Charlie');
  console.log('  • Root              → Alice, Charlie');
  console.log('  • Everdell          → Bob, Charlie');
  console.log('  • Gloomhaven        → Bob, Charlie');
  console.log('\n  NOTE: If users were just created, Supabase may require');
  console.log('  email confirmation before sign-in works in the app.');
  console.log('  Disable "Email confirmations" in your Supabase Auth settings');
  console.log('  or confirm each address in the Supabase dashboard.\n');
}

main().catch((err) => { console.error('\n✗ Seed failed:', err.message); process.exit(1); });
