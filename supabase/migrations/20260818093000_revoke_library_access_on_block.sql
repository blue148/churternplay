-- =====================================================
-- Phase 0 follow-up: revoke library access when blocked
-- =====================================================
-- blockUser() sets user_friends.status = 'blocked' via UPDATE, not DELETE —
-- so the revoke_reciprocal_library_access trigger (which only fires on
-- DELETE) never runs for a block. Without this, a blocked user keeps their
-- shared_library_access grant indefinitely. Extends the same UPDATE trigger
-- used for accept-grants to also revoke on a transition to 'blocked'.

CREATE OR REPLACE FUNCTION grant_reciprocal_library_access()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.status = 'accepted' THEN
      INSERT INTO shared_library_access (owner_id, viewer_id, access_level)
      VALUES (NEW.user_id, NEW.friend_id, 'view')
      ON CONFLICT (owner_id, viewer_id) DO NOTHING;

      INSERT INTO shared_library_access (owner_id, viewer_id, access_level)
      VALUES (NEW.friend_id, NEW.user_id, 'view')
      ON CONFLICT (owner_id, viewer_id) DO NOTHING;
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.status = 'accepted' AND OLD.status IS DISTINCT FROM 'accepted' THEN
      INSERT INTO shared_library_access (owner_id, viewer_id, access_level)
      VALUES (NEW.user_id, NEW.friend_id, 'view')
      ON CONFLICT (owner_id, viewer_id) DO NOTHING;

      INSERT INTO shared_library_access (owner_id, viewer_id, access_level)
      VALUES (NEW.friend_id, NEW.user_id, 'view')
      ON CONFLICT (owner_id, viewer_id) DO NOTHING;
    ELSIF NEW.status = 'blocked' AND OLD.status IS DISTINCT FROM 'blocked' THEN
      DELETE FROM shared_library_access
      WHERE (owner_id = NEW.user_id AND viewer_id = NEW.friend_id)
         OR (owner_id = NEW.friend_id AND viewer_id = NEW.user_id);
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION grant_reciprocal_library_access() IS
  'Grants reciprocal view-level shared_library_access on friend-request insert or acceptance; revokes both directions when the relationship transitions to blocked. Implements PRD_FLUTTER_APP.md §13 Open Question #6.';
