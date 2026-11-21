-- Ratings (hearts + punch worthiness), designers, and atomic move RPCs.
-- NOT yet applied to the live DB — ask before `supabase db push`.

ALTER TABLE shared_games
  ADD COLUMN IF NOT EXISTS designers text[] NOT NULL DEFAULT '{}';

ALTER TABLE user_library
  ADD COLUMN IF NOT EXISTS heart_rating smallint NOT NULL DEFAULT 0
    CHECK (heart_rating BETWEEN 0 AND 5),
  ADD COLUMN IF NOT EXISTS punch_rating smallint NOT NULL DEFAULT 0
    CHECK (punch_rating BETWEEN 0 AND 5);

ALTER TABLE user_wishlist
  ADD COLUMN IF NOT EXISTS heart_rating smallint NOT NULL DEFAULT 0
    CHECK (heart_rating BETWEEN 0 AND 5),
  ADD COLUMN IF NOT EXISTS punch_rating smallint NOT NULL DEFAULT 0
    CHECK (punch_rating BETWEEN 0 AND 5);

COMMENT ON COLUMN user_library.heart_rating IS 'Likes, 0-5 hearts (0 = not rated)';
COMMENT ON COLUMN user_library.punch_rating IS 'Punch worthiness, 0-5 fists (0 = not rated)';
COMMENT ON COLUMN user_wishlist.heart_rating IS 'Likes, 0-5 hearts (0 = not rated)';
COMMENT ON COLUMN user_wishlist.punch_rating IS 'Punch worthiness, 0-5 fists (0 = not rated)';
COMMENT ON COLUMN shared_games.designers IS 'Game designers (BGG boardgamedesigner links)';

-- One-time backfill of hearts from the old high/medium/low personal_ranking.
UPDATE user_library
SET heart_rating = CASE personal_ranking
  WHEN 'high' THEN 5 WHEN 'medium' THEN 3 WHEN 'low' THEN 1 ELSE 0 END
WHERE heart_rating = 0 AND personal_ranking IN ('high', 'medium', 'low');

-- Atomic Library -> Wishlist move. SECURITY INVOKER: existing RLS applies.
-- Carries ratings and notes. Refuses if the game has logged plays.
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
  IF COALESCE(array_length(v_entry.played_dates, 1), 0) > 0 THEN
    RAISE EXCEPTION 'game_has_plays';
  END IF;

  INSERT INTO user_wishlist (user_id, game_id, priority, notes, heart_rating, punch_rating)
  VALUES (auth.uid(), p_game_id, p_priority, v_entry.notes,
          v_entry.heart_rating, v_entry.punch_rating)
  ON CONFLICT (user_id, game_id) DO NOTHING;

  DELETE FROM user_library WHERE id = v_entry.id;
END;
$$;

-- Atomic Wishlist -> Library move. Carries ratings and notes.
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

  INSERT INTO user_library (user_id, game_id, notes, heart_rating, punch_rating)
  VALUES (auth.uid(), p_game_id, v_entry.notes,
          v_entry.heart_rating, v_entry.punch_rating)
  ON CONFLICT DO NOTHING;

  DELETE FROM user_wishlist WHERE id = v_entry.id;
END;
$$;

GRANT EXECUTE ON FUNCTION move_library_to_wishlist(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION move_wishlist_to_library(uuid) TO authenticated;
