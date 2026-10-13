-- =====================================================
-- Phase 0 follow-up: cover direct-accepted inserts
-- =====================================================
-- 20260818090000 only fired on UPDATE (the real app's pending -> accepted
-- flow). Testing that migration surfaced a gap: a row inserted directly with
-- status = 'accepted' (e.g. a seed script, or any future admin/backend path
-- that doesn't go through the pending state) silently skipped the grant.
-- Rewritten to handle both INSERT and UPDATE explicitly per TG_OP, rather
-- than relying on OLD.status short-circuiting (OLD is unassigned on INSERT,
-- and Postgres does not guarantee AND/OR short-circuit order).

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
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_grant_reciprocal_library_access_insert ON user_friends;
CREATE TRIGGER trg_grant_reciprocal_library_access_insert
  AFTER INSERT ON user_friends
  FOR EACH ROW
  EXECUTE FUNCTION grant_reciprocal_library_access();
