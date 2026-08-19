# Review & Test Checklist — Friend Features (Phases 0–4)

Gate before starting Phase 5 (cleanup & doc sync) or any further mobile
phases. Everything below was built in the 2026-08-18 session and, except
where noted, has only been verified at the code/database level (`flutter
analyze`, `flutter test`, and direct SQL against the live Supabase project
with simulated RLS) — **not** by a human tapping through the actual app.
Full context/decisions are in `docs/IMPLEMENTATION_PLAN_FRIEND_FEATURES.md`;
this doc is the "did it actually work" checklist, not a re-explanation.

## Before you start

- **Test accounts** (all seeded, password `TestUser123!` unless noted):
  - `alice@test.liberludorum.com` (username `alice_gamer`)
  - `bob@test.liberludorum.com` (username `bob_plays`)
  - `charlie@test.liberludorum.com` (username `charlie_boards`)
  - `sonderman` (real account, `studio@blue148.com`) — friends with alice only
- **Current accepted friendships:** alice↔bob, alice↔charlie, bob↔charlie,
  sonderman↔alice. Use alice/bob/charlie for the fuller multi-directional
  tests; sonderman↔alice is useful as a sanity check with the real account.
- **Migrations are already applied** to the live "Board Game Library"
  project (`oorilcytrytxhffindgy`) — no migration step needed before
  testing, just sign in and go.
- **Relaunch the app fresh** before testing (`flutter run`), not a hot
  reload, to make sure you're not looking at stale state from before these
  changes.

## ⚠️ First: verify nothing got clobbered

Mid-session, `game_card.dart` and `game_detail_screen.dart` briefly lost
freshly-made edits (the Suggest-to-Friend wiring) — almost certainly a race
with concurrent work happening on this same repo outside this session (a
font-rename pass, a new `quick_actions_speed_dial.dart` / `add_game_sheet.dart`
/ `settings_screen.dart` / `profile_details_screen.dart`, and a
`pendingLibraryTabProvider` all appeared on disk mid-session, none of it
authored here). I caught the loss via grep and reapplied it, then
re-verified — but before testing:

- [ ] Run `git status` / `git diff` and confirm the file list below matches
      what's actually changed — nothing extra missing, nothing unexpectedly
      reverted.
- [ ] Specifically re-check `game_card.dart` and `game_detail_screen.dart`
      contain the Suggest-to-Friend wiring (grep for `onSuggestToFriend` /
      `showSuggestToFriendSheet`).
- [ ] Confirm the concurrent changes (quick actions FAB, font rename,
      settings/profile-details screens) still work — they're out of scope
      for this review but worth a smoke check since they touched adjacent
      files.

## Files changed this session (for code review)

**New:**
- `flutter_app/lib/features/library/widgets/friend_row.dart`
- `flutter_app/lib/features/profile/friends_screen.dart`
- `flutter_app/lib/features/library/widgets/add_to_wishlist_sheet.dart`
- `flutter_app/lib/features/library/widgets/suggest_to_friend_sheet.dart`
- `flutter_app/lib/data/models/game_suggestion.dart`
- `flutter_app/lib/data/services/suggestions_service.dart`
- `flutter_app/lib/providers/suggestions_provider.dart`
- `supabase/migrations/20260818110000_grant_library_read_access_to_shared_viewers.sql`
- `supabase/migrations/20260818120000_create_game_suggestions.sql`

**Modified:**
- `flutter_app/lib/core/router.dart` — `/library/friend/:friendId`, `/profile/friends`
- `flutter_app/lib/features/library/library_screen.dart` — Friend's Games tab simplified to read-only; Wishlist tab gained the suggestions section, scroll-to-highlight, and tab badge
- `flutter_app/lib/features/library/friend_library_screen.dart` — back/identity affordances, wishlist status wiring
- `flutter_app/lib/features/library/widgets/game_card.dart` — `WishlistStatus`, `onAddToWishlist`, `onSuggestToFriend`, dead favorite-button fix
- `flutter_app/lib/features/library/game_detail_screen.dart` — Suggest to a Friend menu item
- `flutter_app/lib/features/profile/profile_screen.dart` — Friends menu item wired
- `flutter_app/lib/data/services/friends_service.dart` — search fixes (case-insensitive wildcard, full_name match), directional bug fixes, `getRelatedUserIds`, `getSentPendingRequests`
- `flutter_app/lib/data/services/games_service.dart` — `addGameToWishlist` notes param
- `flutter_app/lib/providers/wishlist_provider.dart` — `addGame`, `pendingWishlistHighlightProvider`

---

## Test script

### 1. Profile → Friends (management)

- [ ] Requests / Sent / Friends sections all render correctly; Accept on a
      request moves it to Friends; Cancel on a sent request removes it.
- [ ] Search by username (e.g. `bob`) and by display name (e.g. `Chen`),
      both lower- and upper-case — confirm matches either way.
- [ ] Search results split correctly: **Current** section for existing
      friends (no Add button), **Add Friends** section for everyone else
      with a working Add button; a query with zero matches shows an
      explicit "no matches" message, not a blank screen.
- [ ] Send a request, confirm it appears under Sent immediately.
- [ ] Remove a friend from one side, confirm it's gone on both accounts.

### 2. My Games → Friend's Games (read-only browsing)

- [ ] Tab shows accepted friends only — **no** add/search/accept controls
      anywhere on this tab.
- [ ] If there's a pending incoming request, a banner ("N friend requests
      waiting") appears above the list and tapping it opens Profile →
      Friends.
- [ ] Tap a friend → their library opens showing their *actual* games (not
      empty) — this is the RLS fix; if it's empty when it shouldn't be,
      that's a regression.
- [ ] The library screen shows an app-bar back arrow *and* a "Viewing
      {friend}'s library (read-only)" banner with its own Back button; both
      return you to Friend's Games.
- [ ] No Log Play / Favorite / For Sale / Remove controls on a friend's game
      cards — only "Add to Wishlist" in the overflow menu.
- [ ] Search and sort work within the friend's library.
- [ ] An account with zero friends shows "No friends yet" pointing to
      Profile → Friends.

### 3. Add to Wishlist (Pull)

- [ ] From a friend's library, overflow menu → "Add to Wishlist" on a game
      not already owned/wishlisted → opens a sheet with cover/name preview,
      priority chips (Medium default), notes pre-filled `"Seen in
      {friend}'s library"` (editable).
- [ ] Submitting shows a success snackbar, then **automatically navigates
      back to My Games → Wishlist tab with the new entry scrolled into
      view** — test this with a long enough wishlist that the new entry
      wouldn't already be on-screen, to confirm it's actually scrolling and
      not just coincidentally at the top.
- [ ] If an active wishlist search/priority filter would hide the new
      entry, confirm it gets cleared automatically so the entry is visible.
- [ ] Same action on a game already in your library → menu item reads
      "Already in Your Library" and is visibly disabled (greyed, not
      tappable).
- [ ] Same on a game already on your wishlist → "Already on Your Wishlist,"
      disabled.
- [ ] My Library's own cards do **not** show any wishlist-related menu item
      (only Friend's Library cards should).

### 4. Suggest to a Friend (Push)

- [ ] My Library card overflow menu → "Suggest to a Friend" opens a sheet
      listing your accepted friends (avatar, username, game count); tap one
      to select (checkmark appears); Send is disabled until a friend is
      picked.
- [ ] Same action from Game Detail Screen's overflow menu.
- [ ] Add an optional note, Send → success snackbar, sheet closes.
- [ ] Zero-friends account sees "No friends yet" in the sheet instead of a
      blank list.
- [ ] Switch to the **recipient's** account → My Games → Wishlist tab:
  - [ ] Tab label shows a numeric badge matching the pending count.
  - [ ] "SUGGESTED BY FRIENDS (N)" section appears above the regular
        wishlist — even if the wishlist itself is otherwise empty.
  - [ ] Row shows game cover/name, "From {sender}," the note (if any), and
        Accept/Dismiss.
- [ ] **Accept** → row disappears from the inbox, a real entry appears in
      the wishlist proper with the note carried over and Medium priority,
      badge count decrements.
- [ ] **Dismiss** (a second suggestion) → row disappears, no wishlist entry
      created, nothing changes on the sender's side (silent, by design).

### Regression / cross-cutting

- [ ] Tab bar labels ("My Library / Wishlist / Friend's Games") still lay
      out correctly with the new badge on Wishlist, including on a smaller
      screen.
- [ ] Sign-out/sign-in still works (unrelated to this session's changes but
      worth a smoke check given the volume of adjacent-screen edits).
- [ ] No console errors/exceptions referencing `game_suggestions`,
      `shared_library_access`, or RLS during normal use.

---

## Sign-off

Once every box above is checked and any bugs found are logged/fixed, Phase 5
(PRD/codebase-doc sync, Open Questions #6/#8 resolution, widget tests) is
safe to start.
