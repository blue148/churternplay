# Netlify Deployment Setup

## Issue: Secret Detection in Built Files

Netlify's security scanner detects `VITE_SUPABASE_ANON_KEY` in the built `dist/` folder and flags it as a potential secret. However, this is a **false positive** because:

- Supabase anon keys are **designed to be public** and safe to expose in client-side code
- They are protected by **Row Level Security (RLS)** policies in Supabase
- They are meant to be embedded in your JavaScript bundle

## Solution

### 1. Configuration File

We've created `netlify.toml` with the following:

- Configures build command and publish directory
- Sets up SPA routing (redirects all routes to `index.html`)
- Adds security headers
- Specifies Node.js version
- **Configures `SECRETS_SCAN_OMIT_KEYS`** to exclude VITE_ prefixed variables from secret scanning

### 2. Netlify Dashboard Configuration

#### Step 1: Set Environment Variables

In your Netlify dashboard:

1. Go to **Site settings** → **Environment variables**
2. Add the following variables:
   ```
   VITE_SUPABASE_URL = <your-supabase-url>
   VITE_SUPABASE_ANON_KEY = <your-anon-key>
   ```

   Get these values from your Supabase project dashboard.

#### Step 2: Disable Sensitive Variable Scanning (if needed)

If the audit-ignore file doesn't work:

1. Go to **Site settings** → **Build & deploy** → **Build settings**
2. Scroll to **Sensitive variable policy**
3. Either:
   - Select **"Don't block builds"** for this project
   - Or contact Netlify support to whitelist your Supabase anon key

### 3. How It Works

The key configuration in `netlify.toml` is:

```toml
[build.environment]
  SECRETS_SCAN_OMIT_KEYS = "VITE_SUPABASE_URL,VITE_SUPABASE_ANON_KEY"
```

This tells Netlify to:
- Skip scanning for `VITE_SUPABASE_URL` in build output
- Skip scanning for `VITE_SUPABASE_ANON_KEY` in build output
- Allow these variables to be embedded in the client bundle

### 4. Alternative Solutions (If Needed)

#### Option A: Disable Secret Scanning Entirely

If you need to disable scanning completely (not recommended):

```toml
[build.environment]
  SECRETS_SCAN_ENABLED = "false"
```

#### Option B: Exclude Specific Paths

To exclude only the `dist/` directory from scanning:

```toml
[build.environment]
  SECRETS_SCAN_OMIT_PATHS = "dist/"
```

### 5. Verify the Fix

After deploying:

1. Check the deploy log for any secret detection warnings
2. Verify the site builds successfully
3. Test that your Supabase connection works in production

## Security Notes

### What's Safe to Expose

✅ **VITE_SUPABASE_URL** - Public Supabase project URL
✅ **VITE_SUPABASE_ANON_KEY** - Public anon key (protected by RLS)

### What Should Stay Secret

❌ **BGG_API_TOKEN** - Should only be used in Supabase Edge Functions
❌ **BARCODELOOKUP_API_KEY** - Should only be used in Supabase Edge Functions
❌ **GAMEUPC_API_KEY** - Should only be used in Supabase Edge Functions
❌ **SUPABASE_SERVICE_ROLE_KEY** - Never expose this (admin access)

### Edge Functions Handle Secrets

All sensitive API keys (BGG, BarcodeLookup, GameUPC) are stored as secrets in Supabase Edge Functions:

- `supabase/functions/bgg-lookup/` - Uses `BGG_API_TOKEN`
- `supabase/functions/barcode-lookup/` - Uses `BARCODELOOKUP_API_KEY` and `GAMEUPC_API_KEY`

These secrets are set in Supabase dashboard under **Edge Functions** → **Secrets**, not in Netlify.

## Troubleshooting

### Build still fails with secret detection

1. Verify `netlify.toml` has `SECRETS_SCAN_OMIT_KEYS` configured
2. Ensure the variable names in `SECRETS_SCAN_OMIT_KEYS` match exactly
3. Check that you're not committing actual secret values in documentation files
4. Try setting the environment variable in Netlify UI instead:
   - Go to **Site settings** → **Build & deploy** → **Environment**
   - Add `SECRETS_SCAN_OMIT_KEYS` = `VITE_SUPABASE_URL,VITE_SUPABASE_ANON_KEY`

### Environment variables not working

1. Ensure variables are set in Netlify dashboard
2. Check that variable names start with `VITE_`
3. Verify variables are available to the build command
4. Try triggering a clear cache and rebuild

### Production site can't connect to Supabase

1. Check browser console for errors
2. Verify Supabase URL and anon key are correct
3. Ensure RLS policies are configured correctly
4. Check Supabase dashboard for API usage logs
