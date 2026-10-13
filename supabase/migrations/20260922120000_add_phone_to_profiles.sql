-- =====================================================
-- Add phone number to profiles
-- =====================================================
-- Secondary contact identifier alongside email. Not used for login —
-- auth remains email+password. Optional; NULL for existing rows.
-- Unique when present so a phone number can be used to look up a single
-- account (e.g. "find my account"), but many rows can stay NULL.

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_phone_unique
  ON profiles(phone)
  WHERE phone IS NOT NULL;

COMMENT ON COLUMN profiles.phone IS 'Optional secondary contact identifier (E.164 format); not used for authentication';

-- Keep handle_new_user in sync so signups can populate phone via
-- auth signup metadata the same way username/full_name already do.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, username, full_name, phone)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'phone'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
