# Netlify Environment Variables Setup

## Problem
Getting 401 errors when calling Supabase Edge Functions from the deployed Netlify site.

## Solution
Set environment variables in Netlify dashboard so they're available during the build process.

## Steps

### 1. Go to Netlify Dashboard
1. Open https://app.netlify.com
2. Select your "Board Game Library" site
3. Go to **Site configuration** → **Environment variables**

### 2. Add These Variables

Click "Add a variable" and add these one by one:

**Variable 1:**
- **Key:** `VITE_SUPABASE_URL`
- **Value:** `https://oorilcytrytxhffindgy.supabase.co`
- **Scopes:** Check "Production" and "Deploy Previews"

**Variable 2:**
- **Key:** `VITE_SUPABASE_ANON_KEY`
- **Value:** `sb_publishable_UxLoSjJzgOzURjiQU9ITrQ_11hSxk7J`
- **Scopes:** Check "Production" and "Deploy Previews"

### 3. Trigger a New Deploy

After setting the variables:
1. Go to **Deploys** tab
2. Click **Trigger deploy** → **Clear cache and deploy site**

This forces a fresh build with the new environment variables.

### 4. Verify It Works

Once deployed:
1. Visit your Netlify site
2. Try the manual game entry (search for "Skull")
3. Should now work without 401 errors ✅

## Why This Is Needed

- Environment variables prefixed with `VITE_` are **build-time** variables
- Vite replaces them with actual values during the build process
- Netlify needs these variables set to inject them during its automated builds
- Your local `.env` file only works for local development

## Security Note

The `VITE_SUPABASE_ANON_KEY` is safe to expose in client-side code because:
- It's protected by Row Level Security (RLS) policies in Supabase
- It only allows operations you've explicitly permitted
- Sensitive operations use the service role key (which stays server-side)

The actual sensitive keys (BGG_API_TOKEN, etc.) are stored as secrets in Supabase Edge Functions, not in Netlify.
