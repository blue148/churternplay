-- Phase 3 of docs/IMPLEMENTATION_PLAN_FRIEND_FEATURES.md — Push: Suggest a
-- Game to a Friend (PRD §13.2). Data layer only; no UI reads this yet.
--
-- A dedicated table rather than wiring up the dormant `suggest` value on
-- shared_library_access.access_level — library *visibility* and a one-off
-- *suggest this specific game* event are different concepts the original
-- schema conflated (see PRD §13.2's recommendation to deprecate `suggest`
-- once this ships).

DO $$ BEGIN
    CREATE TYPE suggestion_status AS ENUM ('pending', 'accepted', 'dismissed');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS game_suggestions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  recipient_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  game_id UUID NOT NULL REFERENCES shared_games(id) ON DELETE CASCADE,
  note TEXT,
  status suggestion_status NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  CONSTRAINT game_suggestions_no_self_suggestion CHECK (sender_id != recipient_id)
);

-- Hot query is "my pending inbox" (recipient_id, status = 'pending'); a
-- plain index on recipient_id covers it without a partial-index migration
-- later if other statuses need listing too. sender_id supports a future
-- "sent" view (RLS already allows it, per Open Question — not required for
-- v1 UI).
CREATE INDEX IF NOT EXISTS idx_game_suggestions_recipient_id
  ON game_suggestions(recipient_id);
CREATE INDEX IF NOT EXISTS idx_game_suggestions_sender_id
  ON game_suggestions(sender_id);

ALTER TABLE game_suggestions ENABLE ROW LEVEL SECURITY;

-- Sender can only suggest to an accepted friend — reuses the helper
-- function from 20260410102654_add_shared_library_tables.sql rather than
-- duplicating the friendship check.
DROP POLICY IF EXISTS "Senders can suggest to friends" ON game_suggestions;
CREATE POLICY "Senders can suggest to friends"
  ON game_suggestions FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id
    AND are_users_friends(sender_id, recipient_id)
  );

-- Both parties can see a suggestion they're part of — sender for a future
-- "sent" view, recipient for their inbox.
DROP POLICY IF EXISTS "Participants can view their suggestions" ON game_suggestions;
CREATE POLICY "Participants can view their suggestions"
  ON game_suggestions FOR SELECT
  USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

-- Only the recipient can act on it (accept/dismiss) — the sender's
-- proposal is final once sent, matching PRD §13.2 ("a push is a proposal
-- the recipient must act on").
DROP POLICY IF EXISTS "Recipients can respond to suggestions" ON game_suggestions;
CREATE POLICY "Recipients can respond to suggestions"
  ON game_suggestions FOR UPDATE
  USING (auth.uid() = recipient_id);

COMMENT ON TABLE game_suggestions IS 'One-off "suggest this game to a friend" events (PRD §13.2) — distinct from shared_library_access, which controls ongoing library visibility.';
COMMENT ON COLUMN game_suggestions.sender_id IS 'User who sent the suggestion';
COMMENT ON COLUMN game_suggestions.recipient_id IS 'User the suggestion was sent to';
COMMENT ON COLUMN game_suggestions.status IS 'pending (awaiting recipient action) / accepted (recipient added it to their wishlist) / dismissed (recipient declined, sender not notified)';
