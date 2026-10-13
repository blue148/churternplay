-- =====================================================
-- Add full_name to profiles
-- =====================================================
-- Separate from username (handle) — a display name for the person behind
-- the account. Optional; NULL for existing rows until backfilled.

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS full_name TEXT;

COMMENT ON COLUMN profiles.full_name IS 'Display name of the person, distinct from the @username handle';

-- Keep handle_new_user in sync so future signups can populate full_name via
-- auth signup metadata the same way username already is.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, username, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    NEW.raw_user_meta_data->>'full_name'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
