-- Wishlist games can log plays, and a played library game can move to the
-- wishlist: play history now travels with the game in both directions.

ALTER TABLE user_wishlist
  ADD COLUMN IF NOT EXISTS played_dates TEXT[] DEFAULT '{}';

COMMENT ON COLUMN user_wishlist.played_dates IS 'Array of ISO date strings when game was played';

-- Library -> Wishlist: no longer refuses played games; carries played_dates.
CREATE OR REPLACE FUNCTION move_library_to_wishlist(
  p_game_id uuid,
  p_priority text DEFAULT 'medium'
) RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_entry user_library%ROWTYPE;
BEGIN
  SELECT * INTO v_entry FROM user_library
  WHERE user_id = auth.uid() AND game_id = p_game_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'game_not_in_library';
  END IF;

  INSERT INTO user_wishlist
    (user_id, game_id, priority, notes, heart_rating, punch_rating, played_dates)
  VALUES (auth.uid(), p_game_id, p_priority, v_entry.notes,
          v_entry.heart_rating, v_entry.punch_rating,
          COALESCE(v_entry.played_dates, '{}'))
  ON CONFLICT (user_id, game_id) DO NOTHING;

  DELETE FROM user_library WHERE id = v_entry.id;
END;
$$;

-- Wishlist -> Library: carries played_dates too.
CREATE OR REPLACE FUNCTION move_wishlist_to_library(p_game_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_entry user_wishlist%ROWTYPE;
BEGIN
  SELECT * INTO v_entry FROM user_wishlist
  WHERE user_id = auth.uid() AND game_id = p_game_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'game_not_in_wishlist';
  END IF;

  INSERT INTO user_library
    (user_id, game_id, notes, heart_rating, punch_rating, played_dates)
  VALUES (auth.uid(), p_game_id, v_entry.notes,
          v_entry.heart_rating, v_entry.punch_rating,
          COALESCE(v_entry.played_dates, '{}'))
  ON CONFLICT DO NOTHING;

  DELETE FROM user_wishlist WHERE id = v_entry.id;
END;
$$;
