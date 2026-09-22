-- =====================================================
-- First-party beta analytics
-- =====================================================
-- Lightweight, self-hosted usage/error logging for the beta. No third-party
-- SDK: events are written directly to this table by the authenticated user
-- who generated them, and are readable only via the service role (dashboard
-- or a future internal tool), never by other app users.

CREATE TABLE IF NOT EXISTS analytics_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  event_name TEXT NOT NULL,
  properties JSONB,
  platform TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_analytics_events_user_id ON analytics_events(user_id);
CREATE INDEX IF NOT EXISTS idx_analytics_events_event_name ON analytics_events(event_name);
CREATE INDEX IF NOT EXISTS idx_analytics_events_created_at ON analytics_events(created_at);

ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;

-- Authenticated users may only insert events attributed to themselves.
CREATE POLICY "Users can log their own analytics events"
  ON analytics_events
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- No SELECT/UPDATE/DELETE policy for regular users — with RLS enabled and no
-- matching policy, only the service role (which bypasses RLS) can read this
-- table, e.g. from the Supabase dashboard.

COMMENT ON TABLE analytics_events IS 'First-party beta usage/error events, written by the app; readable only via the service role.';
