-- =====================================================
-- Restrict profiles to the owner's own row (step 2 of 2)
-- =====================================================
-- Before: any signed-in user could SELECT every profiles row, including
-- email, phone, and preferences (private player names). Clients could also
-- UPDATE any column of their own row — including is_admin, which gates
-- write access to the shared game catalog — and could DELETE then
-- re-INSERT their row with is_admin = true.
--
-- After:
--   * profiles SELECT is limited to auth.uid() = id. Other users' public
--     fields come from the public_profiles view (previous migration).
--   * Clients may only UPDATE the user-editable columns. Email is synced
--     from auth.users and stats by trigger; both run as SECURITY DEFINER.
--   * Clients can't INSERT profiles at all — handle_new_user() creates them.
--
-- Requires clients that read other users through public_profiles. Deploy
-- the matching web build together with this migration.

DROP POLICY IF EXISTS "Profiles are viewable by authenticated users" ON public.profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;

REVOKE ALL ON public.profiles FROM anon;
REVOKE INSERT, UPDATE ON public.profiles FROM authenticated;

-- New columns are NOT client-writable until added here.
GRANT UPDATE (username, full_name, avatar_url, bio, phone, preferences, updated_at)
  ON public.profiles TO authenticated;
