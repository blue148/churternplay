# Supabase Edge Functions

This project uses Supabase Edge Functions to securely manage API tokens and provide server-side API access.

## Functions Overview

### 1. BGG Lookup Function
Securely proxies requests to the BoardGameGeek (BGG) XML API, keeping your BGG API token server-side only.

### 2. Barcode Lookup Function
Securely handles barcode lookups with automatic fallback:
- **Primary**: GameUPC API (includes BGG IDs)
- **Fallback**: BarcodeLookup API
- **3rd Fallback**: UPCItemDB API
- Keeps API tokens server-side only

### 3. Add Game to Library Function
Adds a game to the calling user's library. `shared_games` writes are
admin-only under RLS, so this function:
- Authenticates the caller via their JWT (the user id never comes from the body)
- Dedupes by `bgg_id`, fetching BGG details server-side when the game is new
  (clients never supply game data), using the service-role key
- Inserts the `user_library` row as the caller, so its RLS still applies
- Returns `{ status: 'added' | 'already_in_library', game }`

### 4. Submit Barcode Mapping Function
Crowdsources a barcode → BGG id mapping back to GameUPC after a successful match.

### 5. Delete Account Function
Permanently deletes the calling user's account. A client cannot delete its own
auth user (that requires the service-role key), so this function:
- Authenticates the caller via their JWT and derives the user id from it (never
  from the request body — a user can only delete themselves)
- Deletes the user's avatar files from the `avatars` storage bucket (not cascaded
  by foreign keys)
- Calls `auth.admin.deleteUser()`, which cascades to remove all relational data
  (`profiles`, `user_library`, `user_wishlist`, `game_sessions`,
  `session_victories`, `user_friends`, `shared_library_access`)

Required for App Store / Play Store compliance (apps that support account
creation must offer in-app account deletion).

### Setup

#### 1. Install Supabase CLI (if not already installed)

```bash
npm install -g supabase
```

#### 2. Link to your Supabase project

```bash
supabase link --project-ref your-project-ref
```

#### 3. Set API tokens as secrets

```bash
# BGG API token
supabase secrets set BGG_API_TOKEN=your-bgg-api-token-here

# GameUPC API key (primary barcode lookup + barcode mapping submissions)
supabase secrets set GAMEUPC_API_KEY=your-gameupc-api-key-here

# BarcodeLookup API token
supabase secrets set BARCODELOOKUP_API_KEY=your-barcodelookup-api-key-here

# (Optional) UPCItemDB API token for higher limits
supabase secrets set UPCITEMDB_USER_KEY=your-upcitemdb-key
supabase secrets set UPCITEMDB_KEY_TYPE=3scale

# Service-role key for the delete-account and add-game-to-library functions (Dashboard > Settings > API).
# This is privileged — keep it server-side only, never in the app.
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

This stores your tokens securely on Supabase's servers. They will NOT be visible in your code or to end users.

> **Note:** `SUPABASE_URL` and `SUPABASE_ANON_KEY` are injected automatically by
> the Supabase runtime and do not need to be set as secrets.

#### 4. Deploy the functions

```bash
# Deploy individual functions
supabase functions deploy bgg-lookup
supabase functions deploy barcode-lookup
supabase functions deploy add-game-to-library
supabase functions deploy submit-barcode-mapping
supabase functions deploy delete-account

# Or deploy all functions at once
supabase functions deploy
```

### Local Development

#### 1. Create a local `.env` file

```bash
cd supabase/functions
cp .env.example .env
```

#### 2. Edit `.env` and add your tokens

```
BGG_API_TOKEN=your-bgg-api-token-here
GAMEUPC_API_KEY=your-gameupc-api-key-here
BARCODELOOKUP_API_KEY=your-barcodelookup-api-key-here
UPCITEMDB_USER_KEY=your-upcitemdb-key
UPCITEMDB_KEY_TYPE=3scale
```

**IMPORTANT:** The `.env` file is gitignored and should NEVER be committed to version control.

#### 3. Start Supabase locally with functions

```bash
# Serve a specific function
supabase functions serve bgg-lookup --env-file supabase/functions/.env
supabase functions serve barcode-lookup --env-file supabase/functions/.env

# Or serve all functions
supabase start
```

### Usage

#### BGG Lookup

```typescript
import { lookupBggGame, searchBggGames } from './lib/bgg';

// Look up game by BGG ID
const game = await lookupBggGame(174430);

// Search for games by name
const results = await searchBggGames('Wingspan');
```

#### Barcode Lookup

```typescript
import { lookupBarcodeWithBgg } from './lib/bgg';

// Look up game by barcode (tries GameUPC, then BarcodeLookup, then UPCItemDB)
const game = await lookupBarcodeWithBgg('644216627775');
// Returns full game data enriched with BGG details
```

See [/src/lib/bgg.ts](../../src/lib/bgg.ts) for convenience wrapper functions.

### Security

✅ **All API tokens stored server-side only**
✅ **Never exposed to client browsers**
✅ **Managed through Supabase secrets (encrypted at rest)**
✅ **Can be rotated without code changes**
✅ **Automatic fallback ensures reliability**

### Rate Limiting

Consider adding rate limiting if you expect high usage:

```typescript
// TODO: Add rate limiting to prevent abuse
// Example: Use Supabase database to track requests per user
```

### Monitoring

View function logs in the Supabase Dashboard:
1. Go to your project dashboard
2. Click "Edge Functions" in the sidebar
3. Select function (bgg-lookup or barcode-lookup)
4. View logs and invocation metrics

**Barcode Lookup Logs:**
- Check `source` field to see which API was used:
  - `"gameupc"` - GameUPC succeeded
  - `"barcodelookup"` - Fell back to BarcodeLookup
  - `"upcitemdb"` - Fell back to UPCItemDB
  - `"none"` - All services failed

### Cost

Supabase Free Tier includes:
- 500,000 Edge Function invocations per month
- 2 million compute seconds per month

This should be more than enough for typical usage.
