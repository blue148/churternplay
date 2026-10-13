-- =====================================================
-- Phase 0: Auto-Grant Reciprocal Library Access on Friendship
-- =====================================================
-- Implements docs/PRD_FLUTTER_APP.md §13, Open Question #6.
--
-- Today nothing populates shared_library_access, so the Game Chooser's
-- friend-library toggle (§4.10.1) and the planned Friend's Library screen
-- (§13.1) have no data to show for a real friendship. This trigger grants
-- reciprocal `view` access automatically when a friend request is accepted,
-- and revokes it when the friendship is removed, so both apps (mobile +
-- web) get consistent behavior regardless of which one performed the
-- accept/remove.

CREATE OR REPLACE FUNCTION grant_reciprocal_library_access()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'accepted' AND OLD.status IS DISTINCT FROM 'accepted' THEN
    INSERT INTO shared_library_access (owner_id, viewer_id, access_level)
    VALUES (NEW.user_id, NEW.friend_id, 'view')
    ON CONFLICT (owner_id, viewer_id) DO NOTHING;

    INSERT INTO shared_library_access (owner_id, viewer_id, access_level)
    VALUES (NEW.friend_id, NEW.user_id, 'view')
    ON CONFLICT (owner_id, viewer_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_grant_reciprocal_library_access ON user_friends;
CREATE TRIGGER trg_grant_reciprocal_library_access
  AFTER UPDATE ON user_friends
  FOR EACH ROW
  EXECUTE FUNCTION grant_reciprocal_library_access();

CREATE OR REPLACE FUNCTION revoke_reciprocal_library_access()
RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM shared_library_access
  WHERE (owner_id = OLD.user_id AND viewer_id = OLD.friend_id)
     OR (owner_id = OLD.friend_id AND viewer_id = OLD.user_id);
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_revoke_reciprocal_library_access ON user_friends;
CREATE TRIGGER trg_revoke_reciprocal_library_access
  AFTER DELETE ON user_friends
  FOR EACH ROW
  EXECUTE FUNCTION revoke_reciprocal_library_access();

COMMENT ON FUNCTION grant_reciprocal_library_access() IS
  'Auto-grants reciprocal view-level shared_library_access when a friend request is accepted (user_friends.status -> accepted). Implements PRD_FLUTTER_APP.md §13 Open Question #6.';
COMMENT ON FUNCTION revoke_reciprocal_library_access() IS
  'Revokes both directions of shared_library_access when a user_friends row is deleted (unfriending).';
