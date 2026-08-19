-- The Phase 0 friend-library work (20260818090000/091500/093000) auto-grants
-- shared_library_access rows when a friendship is accepted, but user_library
-- itself only ever had one SELECT policy: "Users can view own library"
-- (auth.uid() = user_id). Nothing taught user_library to honor a
-- shared_library_access grant, so FriendLibraryScreen's
-- getSharedLibraryGames() query was silently returning zero rows for every
-- viewer regardless of sharing state or client-side code — RLS just filtered
-- the rows out with no error.
--
-- Additive permissive policy: combines with the existing owner-only policy
-- via OR, so owners keep exactly the same access they already had.
DROP POLICY IF EXISTS "Viewers can see shared library entries" ON user_library;
CREATE POLICY "Viewers can see shared library entries"
  ON user_library FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM shared_library_access
      WHERE shared_library_access.owner_id = user_library.user_id
        AND shared_library_access.viewer_id = auth.uid()
    )
  );
