# Plan: Ratings, Wishlist Moves, Designer/Publisher Facets, Font Change

Branch: `feature/ratings-wishlist-designer-fonts` (cut from `main` @ `d229c7e`, 2026-11-19)
Status: **Implemented on this branch, uncommitted. Migration NOT applied to the live DB; edge functions NOT deployed; designer backfill NOT run.**

Implementation notes (deviations from the plan above):
- Decisions used the recommended defaults (Atkinson Hyperlegible *Next*, 0 = unrated, boxing-glove fist icon, ratings visible to friends, block Library to Wishlist when plays exist).
- Fonts: `google_fonts` is removed. Literata, Atkinson Hyperlegible Next and DM Mono are bundled in `assets/fonts/` (OFL licenses included) and referenced only through `AppFonts` in `app_text_styles.dart`. The plan said ~25 direct call sites; there were 278, all migrated. The app no longer makes runtime font requests.
- Fixed a latent bug found on the way: `LibraryFilter.toggleString` used `identical()` on facet sets, and all empty facets share one `const {}`, so toggling any empty facet toggled Publisher. Replaced with `toggleFacet(StringFacet, value)`.
- Manual designer/publisher entry fields were not added: the manual flow is a BGG search, so designers come from BGG.
- The grid card is unchanged (too tight for the credit line and ratings); list cards, the detail screen and wishlist rows show them.
- The speed dial gained a fifth action, "Add to Wishlist".

## Goals

1. Add a game to the wishlist from anywhere a game can be added, not only from a friend's library.
2. Move a game from Library to Wishlist (the reverse of the existing Wishlist to Library move).
3. Rate any game, in the Library or on the Wishlist, with **hearts (0-5)** and **punch worthiness (0-5 fists)**.
4. Show **designer** and **publisher** on library and wishlist entries, and let users **search and sort** by both.
5. Change the fonts: serif is **Literata**, sans-serif is **Atkinson Hyperlegible**.
6. Add visible text **labels next to each icon button in the FAB popup** (the quick-actions speed dial).

## What exists today (verified in code)

| Area | Current state |
|---|---|
| Wishlist add | `WishlistNotifier.addGame` and `AddToWishlistSheet` exist. The only callers are the friend library screen and suggestion accept. `add_game_sheet.dart` (scan/search/manual) only adds to the library. |
| Wishlist to Library | `GamesService.moveWishlistToLibrary` does an insert, then a delete, as two client calls. They are not atomic. |
| Library to Wishlist | Does not exist. |
| Rating | `user_library.personal_ranking` ('high'/'medium'/'low') and `is_favorite` (star). `user_wishlist.priority` ('high'/'medium'/'low'). There is no hearts or fists field. |
| Publisher | `shared_games.publisher` (single text, the first BGG publisher). Library has a publisher filter facet (`LibraryFilter.publishers`). Wishlist search matches publisher. There is no publisher sort. |
| Designer | Not stored anywhere. `_shared/bgg.ts` parses publishers but not `boardgamedesigner` links. |
| Sort | `LibrarySort`: name, date added, plays. `WishlistSort`: priority, name, date added. Both use `showSortBottomSheet`. |
| Fonts | `AppTextStyles` and `AppTheme` already use `GoogleFonts.literata` and `GoogleFonts.atkinsonHyperlegibleNext`. About 25 call sites bypass `AppTextStyles` (auth screens, privacy policy, dice roller). Fonts are fetched at runtime by `google_fonts`. |

## Decisions needed before building

These change the schema or UX. The plan below uses the **recommended** answer for each. Say if any should differ.

1. **Which Atkinson?** The app already uses *Atkinson Hyperlegible **Next***. Google Fonts also ships the original *Atkinson Hyperlegible* (and a Mono). Recommended: **Hyperlegible Next**. It is the same family with more weights and better numerals, and it may already be what you meant. If you want the original, it is a one-line swap in `app_text_styles.dart` and `app_theme.dart` (`atkinsonHyperlegible`). Either way the real work is the clean-up in Phase 5.
2. **Rating scale.** Recommended: `smallint NOT NULL DEFAULT 0 CHECK (0..5)`, where 0 means "not rated." The alternative is nullable, with null = unrated and 0 = a deliberate zero. Nullable is more precise but complicates sorting and UI. The wishlist and library use the same two columns.
3. **Existing `personal_ranking` (high/med/low) and the star.** Hearts overlap with `personal_ranking`. Recommended: leave the column in place, stop showing it in the UI, and backfill hearts once (high=5, medium=3, low=1) when the migration runs. Drop the "ranking" filter in favor of hearts and fists filters. Keep the star (favorite) and the wishlist `priority`, since they mean something different (favorite, and want-to-buy urgency).
4. **Moving Library to Wishlist loses data.** Plays, favorite, for-sale and notes live on `user_library`. Recommended: confirm dialog ("Plays and favorite will be removed"). Carry over **ratings and notes**. Block the move, with a message, if the game has logged sessions (`game_sessions`/victory stats). Alternative: allow it and keep the sessions anyway.
5. **Who sees ratings?** Friends can already read each other's `user_library` through RLS. Recommended: ratings are visible on a friend's library in v1 (it fits the social app). Hide them if you would rather keep ratings private.
6. **Designer storage.** Games often have several designers. Recommended: `shared_games.designers text[]`. Show a joined string, sort by the first designer's last-name-insensitive full string, and offer each designer as a filter option. Keep `publisher` as the existing single text column (no change to it).
7. **Fist icon.** Material has no fist. Recommended for v1: `Icons.sports_mma` (boxing glove), with the label "Punch-worthy." A custom SVG fist would need `flutter_svg` or a `CustomPainter`; defer unless you have artwork.

## Phase 1: Database

New migration (timestamped after `20261013130000`). **Ask before `supabase db push`.**

```sql
ALTER TABLE shared_games ADD COLUMN IF NOT EXISTS designers text[] NOT NULL DEFAULT '{}';

ALTER TABLE user_library
  ADD COLUMN IF NOT EXISTS heart_rating smallint NOT NULL DEFAULT 0 CHECK (heart_rating BETWEEN 0 AND 5),
  ADD COLUMN IF NOT EXISTS punch_rating smallint NOT NULL DEFAULT 0 CHECK (punch_rating BETWEEN 0 AND 5);

ALTER TABLE user_wishlist
  ADD COLUMN IF NOT EXISTS heart_rating smallint NOT NULL DEFAULT 0 CHECK (heart_rating BETWEEN 0 AND 5),
  ADD COLUMN IF NOT EXISTS punch_rating smallint NOT NULL DEFAULT 0 CHECK (punch_rating BETWEEN 0 AND 5);

-- One-time backfill of hearts from personal_ranking (decision 3)
UPDATE user_library SET heart_rating = CASE personal_ranking
  WHEN 'high' THEN 5 WHEN 'medium' THEN 3 WHEN 'low' THEN 1 ELSE 0 END
WHERE heart_rating = 0 AND personal_ranking IS NOT NULL;
```

Atomic move functions (both `SECURITY INVOKER`, so existing RLS applies). They fix the non-atomic move that exists today:

- `move_library_to_wishlist(p_game_id uuid, p_priority text default 'medium')`: insert into `user_wishlist` (carrying `heart_rating`, `punch_rating` and `notes`), then delete from `user_library`, in one transaction. Use `ON CONFLICT DO NOTHING` for the insert.
- `move_wishlist_to_library(p_game_id uuid)`: the reverse. It carries ratings and notes. Replace the two-call client version.

Also:
- Check the `user_library`/`user_wishlist` UPDATE grants and RLS cover the new columns. The profiles lockdown showed that column grants matter (see `BETA_RELEASE_PLAN.md`).
- Check that the friend-library read path (`20260818110000_grant_library_read_access_to_shared_viewers.sql`) exposes or hides the new columns per decision 5.

## Phase 2: Designer data (backend)

- `supabase/functions/_shared/bgg.ts`: parse `type="boardgamedesigner"` links into `designers: string[]`, decoded like publishers. Include "(Uncredited)" handling: drop it.
- `bgg-lookup` and `add-game-to-library`: return and save `designers`.
- **Backfill** existing `shared_games` rows that have a `bgg_id`: a one-off script or edge function that rate-limits BGG calls (see `docs/BGG_API_SETUP.md`). Games without a BGG id keep an empty designer list.
- **Wishlist add path.** `shared_games` writes are admin-only, so adding a never-seen game to the wishlist needs the edge function. Add a `target: 'library' | 'wishlist'` parameter to `add-game-to-library` (default `'library'`) rather than a second function. Return `already_in_wishlist` and `already_in_library` statuses so the client can say which.
- `manual_game_entry_page.dart`: add optional Designer and Publisher fields and pass them through (publisher is already passed).
- Update `docs/BGG_DATA_FIELDS.md`.

## Phase 3: Models, services, providers

- `Game`: add `designers` (`List<String>`), plus a `designerLabel` getter (joined with ", ").
- `LibraryEntry` and `WishlistEntry`: add `heartRating`, `punchRating`; update `fromJson` and `copyWith` (WishlistEntry has no `copyWith` yet).
- `GamesService`: `updateLibraryEntry` already takes a map. Add `updateWishlistEntry`, `moveLibraryToWishlist`, and switch `moveWishlistToLibrary` to the RPC. Add `addGameToWishlistFromBgg` that uses the `target` parameter.
- `libraryProvider`: `setHearts`, `setPunch`, `moveToWishlist`. Optimistic update with rollback, the same as `toggleFavorite` and `removeEntry`.
- `wishlistProvider`: `setHearts`, `setPunch`; `moveToLibrary` should invalidate the library provider the same way it does now.

## Phase 4: UI

**Rating widget** (new `widgets/rating_row.dart`)
- `RatingRow(icon, filledColor, value, onChanged)`: five tappable icons. Tapping the current value sets it back to 0.
- Hearts: `Icons.favorite` in clay. Fists: boxing-glove icon in ink or plum. Don't rely on color alone (outline vs filled).
- Accessibility: a `Semantics` label such as "Hearts, 3 of 5" with increase/decrease actions; 44pt minimum tap targets; a visible text label ("Likes", "Punch-worthy").
- Read-only variant for `GameCard` and friend library.

**Where it appears**
- `game_detail_screen.dart`: editable ratings section, designer and publisher lines, a "Move to Wishlist" action (library entries) and a "Move to Library" action (wishlist entries). Wishlist items currently have no detail screen, so check whether one is needed or whether a bottom sheet is enough.
- `game_card.dart` (library) and `_WishlistItemRow` (wishlist): compact read-only ratings and a designer / publisher subtitle.
- `library_screen.dart` card actions: add "Move to Wishlist" next to the existing actions.
- `add_game_sheet.dart`: add an "Add to wishlist instead" path to scan, search and manual flows (a segmented "Library / Wishlist" toggle at the top of the sheet is the simplest).
- `AddToWishlistSheet`: add optional hearts and fists inputs.

**Search and sort**
- Library search: confirm it already matches publisher (`librarySearchProvider` usage in `library_screen.dart` should be checked), and add designer. Wishlist search: add designer to the existing name, publisher and notes match.
- `LibrarySort` and `WishlistSort`: add `designerAsc`, `designerDesc`, `publisherAsc`, `publisherDesc`, `heartsDesc`, `punchDesc`. Empty values sort last in both directions.
- Filter sheet: add a **designer** facet next to the existing publisher facet, plus minimum hearts / fists. Wishlist has no filter sheet yet. Prefer extracting the facet logic out of `LibraryFilter` so both tabs can share it, instead of copying it.
- The sort sheet will have more than 8 options. Group them under headings (Name, Date, Plays, Creator, Rating) so it stays scannable.

### FAB popup labels (quick-actions speed dial)

File: `lib/features/shell/widgets/quick_actions_speed_dial.dart`. Today the four mini buttons (Game Picker, First Player, Turn Timer, Add Game) are bare icons. The names exist only as `Tooltip`s, which need a long-press and aren't visible on touch.

- Change `_MiniAction` to a `Row`: a label pill on the left, then the existing small FAB on the right. The column stays right-aligned above the main FAB.
- Label style: `AppTextStyles.body` (Atkinson), 13-14pt, w600, ink500 on a parchment50 pill with a light shadow or outline so it reads over the 25% black scrim.
- Tapping the label runs the same action as the button (wrap the whole row in one `InkWell`, 48pt minimum height). Replace the `Tooltip` with `Semantics(label: ..., button: true)` and exclude the duplicate child semantics so screen readers announce each action once.
- Labels animate with the existing open/close fade and slide. Keep them in sync with the button.
- Keep labels short so they don't wrap at large text sizes: "Game Picker", "First Player", "Turn Timer", "Add Game". If this feature adds an "Add to Wishlist" action to the dial (see Phase 4, `add_game_sheet.dart`), give it a label too, and keep the dial to five items or fewer.
- Check the `heroTag` strings: they are derived from the tooltip text, so keep one stable string per action.
- Test: a widget test that opens the dial and finds each label, and that tapping a label triggers its action.

## Phase 5: Fonts

- Confirm decision 1 first.
- Route every direct `GoogleFonts.*` call (auth screens, `privacy_policy_screen.dart`, `dice_roller_page.dart`, `app_theme.dart`) through `AppTextStyles` or the `TextTheme`, so the family is defined in exactly one place. `grep -rn "GoogleFonts\." lib` is the checklist.
- Leave DM Mono as is unless told otherwise. It is the third family and wasn't mentioned.
- **Bundle the font files** (Literata and Atkinson, the weights actually used) under `assets/fonts/` and set `GoogleFonts.config.allowRuntimeFetching = false`. Today the app downloads fonts from Google at runtime, which means a flash of fallback text offline, and a network request to Google that should be reflected in `PRIVACY_RELEASE_CHECKLIST.md` and the privacy policy if it stays. Bundling removes both issues. Include the OFL license files.
- Check type metrics. Atkinson is wider than the fallback, so look for overflow in `GameCard`, the tab bar, buttons with letter-spacing 1.2-2, and the bottom sheets. Check at large Dynamic Type sizes too.

## Phase 6: Tests and verification

- Unit tests (`test/`): `Game.fromJson` with and without `designers`; `LibraryFilter` / sort for designer, publisher, hearts, fists, and empty values sorting last; rating clamp and tap-again-to-clear; wishlist filter/sort.
- Widget tests: `RatingRow` (tap, clear, semantics); sort sheet shows the new options.
- `flutter analyze` and `flutter test` must pass.
- Database: run the migration against a local or staging Supabase first. Verify RLS as alice, bob and charlie (seed users): own rows only, friend visibility per decision 5, and that both move functions are atomic (a forced failure leaves the game in exactly one list).
- UI: Simulator taps can't be automated (see `BETA_RELEASE_PLAN.md` working notes). Verify by screenshots (`xcrun simctl io booted screenshot`), code review, and a manual pass on a device.

## Suggested build order

1. Decisions above, then the migration (Phase 1), reviewed before it is pushed.
2. Models, services, providers (Phase 3) with unit tests. The app compiles and runs with no visible change.
3. Rating widget and detail/card display (Phase 4, ratings).
4. Move flows and add-to-wishlist entry points (Phases 2 and 4).
5. Designer parsing, backfill, search, sort and filter.
6. Fonts (Phase 5). It is independent and can be shipped first as its own PR if it's wanted sooner.

## Risks

- **BGG rate limits and data quality** during the designer backfill. Run it in batches, and expect some games with no or wrong designer data.
- **Edge function redeploys** pull a newer auth-js. Keep using `getUser(jwt)` as noted in memory.
- **Data loss on Library to Wishlist** (decision 4). The confirm dialog and the block-if-played rule guard it.
- **Beta users are on TestFlight 1.0.0+1.** New columns have defaults, so old builds keep working. Don't remove or rename `personal_ranking`.
- **Scope.** This is about six features. Fonts and ratings can ship separately from the wishlist and designer work if the beta timeline needs it.
