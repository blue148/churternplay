-- =====================================================
-- Public profile projection + phone sign-in lookup (additive)
-- =====================================================
-- Step 1 of 2 for locking down profiles. Everything here is additive and
-- safe to apply while existing clients still read profiles directly; the
-- restrictive half lives in 20261013130000_restrict_profiles_to_owner.sql.

-- -----------------------------------------------------
-- public_profiles: what other users are allowed to see
-- -----------------------------------------------------
-- Excludes contact and account fields (email, phone, phone_digits,
-- preferences — which holds private player names — and is_admin).
--
-- Deliberately NOT security_invoker: once profiles' SELECT policy is
-- narrowed to the owner's own row, this view (owned by postgres) is how
-- authenticated users read everyone else's public fields. PostgREST infers
-- relationships through it from the underlying profiles FKs, so embeds like
-- user_friends -> public_profiles!friend_id keep working.
CREATE OR REPLACE VIEW public.public_profiles AS
  SELECT
    id,
    username,
    full_name,
    avatar_url,
    bio,
    total_games,
    favorite_count,
    created_at,
    updated_at
  FROM public.profiles;

COMMENT ON VIEW public.public_profiles IS 'Public, non-contact profile fields visible to any signed-in user';

REVOKE ALL ON public.public_profiles FROM PUBLIC, anon;
GRANT SELECT ON public.public_profiles TO authenticated;

-- -----------------------------------------------------
-- Phone sign-in: resolve phone -> email, only with the right password
-- -----------------------------------------------------
-- Clients sign in with email+password through Supabase Auth. To let a user
-- type a phone number instead, the client needs that account's email — but
-- handing out email-by-phone to anonymous callers would let anyone map
-- phone numbers to email addresses. So this only returns the email when
-- the password also matches, i.e. to someone who could already sign in.
--
-- Failed attempts are throttled per phone number and per client IP so the
-- function can't be used as an unthrottled password oracle (Supabase Auth's
-- own rate limits don't apply to RPC calls).

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS private.phone_login_failures (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  phone_digits TEXT NOT NULL,
  client_ip TEXT,
  attempted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_phone_login_failures_phone
  ON private.phone_login_failures (phone_digits, attempted_at);
CREATE INDEX IF NOT EXISTS idx_phone_login_failures_ip
  ON private.phone_login_failures (client_ip, attempted_at);

CREATE OR REPLACE FUNCTION public.resolve_phone_login(p_phone TEXT, p_password TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_digits TEXT := regexp_replace(COALESCE(p_phone, ''), '[^0-9]', '', 'g');
  v_headers JSON := NULLIF(current_setting('request.headers', true), '')::json;
  v_ip TEXT := COALESCE(
    v_headers->>'cf-connecting-ip',
    NULLIF(trim(split_part(v_headers->>'x-forwarded-for', ',', 1)), '')
  );
  v_email TEXT;
  v_hash TEXT;
BEGIN
  IF v_digits = '' OR COALESCE(p_password, '') = '' THEN
    RETURN NULL;
  END IF;

  DELETE FROM private.phone_login_failures
   WHERE attempted_at < NOW() - INTERVAL '1 day';

  IF (SELECT COUNT(*) FROM private.phone_login_failures
       WHERE phone_digits = v_digits
         AND attempted_at > NOW() - INTERVAL '15 minutes') >= 5
     OR (v_ip IS NOT NULL AND (SELECT COUNT(*) FROM private.phone_login_failures
       WHERE client_ip = v_ip
         AND attempted_at > NOW() - INTERVAL '15 minutes') >= 20)
  THEN
    RAISE EXCEPTION 'Too many sign-in attempts. Please try again later.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT u.email, u.encrypted_password
    INTO v_email, v_hash
    FROM public.profiles p
    JOIN auth.users u ON u.id = p.id
   WHERE p.phone_digits = v_digits;

  IF v_hash IS NOT NULL AND v_hash = extensions.crypt(p_password, v_hash) THEN
    DELETE FROM private.phone_login_failures WHERE phone_digits = v_digits;
    RETURN v_email;
  END IF;

  -- Burn an equivalent bcrypt round for unknown numbers so response time
  -- doesn't reveal whether a phone number is registered.
  IF v_hash IS NULL THEN
    PERFORM extensions.crypt(p_password, extensions.gen_salt('bf', 10));
  END IF;

  INSERT INTO private.phone_login_failures (phone_digits, client_ip)
  VALUES (v_digits, v_ip);
  RETURN NULL;
END;
$$;

COMMENT ON FUNCTION public.resolve_phone_login(TEXT, TEXT) IS
  'Returns the account email for a phone number only when the password matches; throttled per phone and per IP';

REVOKE ALL ON FUNCTION public.resolve_phone_login(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_phone_login(TEXT, TEXT) TO anon, authenticated;

-- -----------------------------------------------------
-- Stats trigger: run as owner
-- -----------------------------------------------------
-- update_user_game_stats() fires on user_library writes and updates
-- profiles.total_games / favorite_count. It ran with the caller's rights,
-- which only worked because clients could UPDATE any profiles column. The
-- next migration removes client UPDATE on those columns, so make it
-- SECURITY DEFINER (body unchanged).
CREATE OR REPLACE FUNCTION public.update_user_game_stats()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE profiles
  SET
    total_games = (
      SELECT COUNT(*)
      FROM user_library
      WHERE user_id = COALESCE(NEW.user_id, OLD.user_id)
    ),
    favorite_count = (
      SELECT COUNT(*)
      FROM user_library
      WHERE user_id = COALESCE(NEW.user_id, OLD.user_id)
        AND is_favorite = true
    )
  WHERE id = COALESCE(NEW.user_id, OLD.user_id);

  RETURN COALESCE(NEW, OLD);
END;
$$;
