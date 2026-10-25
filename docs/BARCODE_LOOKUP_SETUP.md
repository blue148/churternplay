# Barcode Lookup API Integration - Secure Setup Guide

## Overview

The barcode lookup system now uses a secure Supabase Edge Function that tries GameUPC first, falls back to BarcodeLookup, and then UPCItemDB if needed. API keys are stored server-side only, preventing exposure in client code.

## Architecture

```
┌─────────────┐         ┌────────────────────┐         ┌─────────────────┐
│   Browser   │────────>│  Edge Function     │────────>│  GameUPC API    │
│ (Your App)  │         │  (with tokens)     │         │  (Primary)      │
└─────────────┘         └────────────────────┘         └─────────────────┘
     Public                   Private                          │
                                │                              │
                                │                              ▼
                                │                        ┌─────────────────┐
                                │                        │  BGG Lookup     │
                                │                        │  (For details)  │
                                │                        └─────────────────┘
                                │
                                ▼
                          ┌─────────────────┐
                          │ BarcodeLookup   │
                          │ (Fallback)      │
                          └─────────────────┘
                                │
                                ▼
                          ┌─────────────────┐
                          │   UPCItemDB     │
                          │ (3rd Fallback)  │
                          └─────────────────┘
```

## Lookup Flow

1. **Browser** - Scans barcode and sends to Edge Function
2. **Edge Function** - Tries GameUPC first (includes BGG IDs)
3. **If GameUPC fails or returns empty title** - Falls back to BarcodeLookup
4. **If BarcodeLookup fails or returns empty title** - Falls back to UPCItemDB
5. **Returns** - Game name and optional BGG ID
6. **Client** - Uses BGG ID (if available) or searches BGG by name for full details

## Quick Start

### 1. Deploy the Edge Function

```bash
# Link to your Supabase project (if not already linked)
supabase link --project-ref your-project-ref

# Set your BarcodeLookup API token as a secret
supabase secrets set BARCODELOOKUP_API_KEY=your-barcodelookup-api-key-here

# (Optional) Set your UPCItemDB key for higher limits
# NOTE: UPCITEMDB secrets are NOT required - the function automatically uses
# the free trial endpoint (https://api.upcitemdb.com/prod/trial/lookup) if not set
# supabase secrets set UPCITEMDB_USER_KEY=your-upcitemdb-key
# supabase secrets set UPCITEMDB_KEY_TYPE=3scale

# Deploy the function
supabase functions deploy barcode-lookup
```

### 2. Use in Your Code

The barcode lookup is already integrated into the `lookupBarcodeWithBgg()` function:

```typescript
import { lookupBarcodeWithBgg } from './lib/bgg';

const gameData = await lookupBarcodeWithBgg('123456789012');
// Returns: {
//   barcode: '123456789012',
//   bgg_id: 174430,  // if available
//   name: 'Gloomhaven',
//   year: 2017,
//   publisher: 'Cephalofair Games',
//   cover_image: 'https://...',
//   min_players: 1,
//   max_players: 4,
//   playtime_minutes: 120,
//   min_age: 14,
//   game_type: [...],
//   description: '...'
// }
```

## API Keys

### GameUPC
- **Secret**: `GAMEUPC_API_KEY` (Supabase edge-function secret, used by `barcode-lookup` and `submit-barcode-mapping`)
- **Set it**: `supabase secrets set GAMEUPC_API_KEY=your-gameupc-api-key`
- **Token**: Request a production key at https://gameupc.com
- If the secret is missing, `barcode-lookup` skips GameUPC (logs a warning) and falls back to BarcodeLookup / UPCItemDB

### BarcodeLookup
- **Token**: Get your API key at https://www.barcodelookup.com
- **API Docs**: https://www.barcodelookup.com/api
- **Rate Limit**: Check your plan limits
- **Upgrade**: Visit https://www.barcodelookup.com/pricing

### UPCItemDB
- **Token**: Optional (trial endpoint works without a key)
- **API Docs**: https://www.upcitemdb.com/api
- **Rate Limit**: Trial is limited; use a key for higher limits

## Security Benefits

✅ **Token Protection** - API tokens never exposed to browsers
✅ **Automatic Fallback** - Tries GameUPC, BarcodeLookup, then UPCItemDB (skips empty titles)
✅ **BGG Integration** - Enriches data with full BGG details
✅ **Usage Control** - Monitor and rate-limit through single endpoint
✅ **Easy Rotation** - Update tokens without changing code

## Testing

### Test the Edge Function Locally

```bash
# Serve locally (create .env file first)
supabase functions serve barcode-lookup --env-file supabase/functions/.env

# In another terminal, test with curl
curl -i --location --request POST 'http://localhost:54321/functions/v1/barcode-lookup' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{"barcode": "029877030842"}'
```

### Test from Your App

```typescript
import { lookupBarcodeWithBgg } from './lib/bgg';

// Test Wingspan barcode
lookupBarcodeWithBgg('644216627775')
  .then(console.log)
  .catch(console.error);
```

## Monitoring

### View Logs
1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select your project
3. Click "Edge Functions" → "barcode-lookup"
4. View real-time logs to see which service was used:
   - `"source": "gameupc"` - GameUPC succeeded
   - `"source": "barcodelookup"` - Fell back to BarcodeLookup
   - `"source": "upcitemdb"` - Fell back to UPCItemDB
   - `"source": "none"` - All services failed

## Troubleshooting

### "No game found for this barcode"
- Barcode may not exist in either database
- Try searching BGG manually by game name
- Consider adding manual entry option

### "BARCODELOOKUP_API_KEY not configured"
- BarcodeLookup will be skipped and the function will fall back to UPCItemDB.
- To enable BarcodeLookup, run: `supabase secrets set BARCODELOOKUP_API_KEY=your-barcodelookup-api-key-here`
- Redeploy: `supabase functions deploy barcode-lookup`

### GameUPC vs BarcodeLookup vs UPCItemDB
**GameUPC Advantages:**
- Includes BGG IDs (direct lookup)
- Game-specific database
- Better match quality

**BarcodeLookup Advantages:**
- Broader product database
- Reliable fallback
- Good for newer releases

**UPCItemDB Advantages:**
- Additional coverage when other providers fail
- Trial endpoint works without a key

## Next Steps

1. **Monitor Usage**:
   - Check which service is used more often
   - Watch GameUPC error logs for an expired or rate-limited key

2. **Add Caching**:
   - Cache barcode → game mappings in Supabase database
   - Reduce API calls and improve performance

3. **Manual Override**:
   - Allow users to manually link barcodes to BGG IDs
   - Build community-contributed barcode database

4. **Analytics**:
   - Track success rates per service
   - Identify patterns in failed lookups

## Reference

- **Edge Function Code**: [/supabase/functions/barcode-lookup/index.ts](../supabase/functions/barcode-lookup/index.ts)
- **Client Helper**: [/src/lib/bgg.ts](../src/lib/bgg.ts)
- **GameUPC API**: https://gameupc.com/api
- **BarcodeLookup API**: https://www.barcodelookup.com/api
- **UPCItemDB API**: https://www.upcitemdb.com/api
- **Supabase Docs**: https://supabase.com/docs/guides/functions
