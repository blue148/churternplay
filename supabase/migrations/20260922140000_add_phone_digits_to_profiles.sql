-- =====================================================
-- Normalize phone for lookup (sign-in by phone)
-- =====================================================
-- profiles.phone is free-text (e.g. "+1 555 123 4567"), so matching it
-- exactly against user input at login time is fragile. Add a generated,
-- digits-only column to match against, and move the uniqueness constraint
-- onto it so two profiles can't register the same number differently
-- formatted.

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone_digits TEXT
  GENERATED ALWAYS AS (regexp_replace(phone, '[^0-9]', '', 'g')) STORED;

DROP INDEX IF EXISTS idx_profiles_phone_unique;

CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_phone_digits_unique
  ON profiles(phone_digits)
  WHERE phone_digits IS NOT NULL AND phone_digits <> '';

COMMENT ON COLUMN profiles.phone_digits IS 'Digits-only projection of phone, used to look up an account by phone number regardless of formatting';
