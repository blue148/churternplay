# Implementation Plan — Two-Way Friend Game Suggestions

> Implements `docs/PRD_FLUTTER_APP.md` §13 ("Planned Feature: Two-Way Friend
> Game Suggestions") — Pull (add a friend's game to your wishlist) and Push
> (suggest a game from your library to a friend). Also resolves Open
> Question #6 (auto-grant library access on friend acceptance), which both
> directions depend on.
>
> Out of scope: the base friend request/accept/discover/remove system is
> already built (§4.9, as-built) and isn't touched here. §14 ("Play Log for
> Unowned Games") is a separate feature with its own plan; this doc only
> tracks the shared add-to-wishlist affordance dependency between the two
> (Open Question #8) where relevant.

## Why phased this way

Two things make this cheaper than it looks:

- **The friend-library read path already exists.** `FriendsService.
  getSharedLibraryGames(ownerId)` and the `shared_library_access` table are
  live — the Game Chooser (§4.10.1) already reads through them. Nothing new
  needed there; the gap is that nothing *populates* `shared_library_access`
  today (Phase 1) and no screen lets a user *browse* a friend's library
  outside the Game Chooser's randomizer (Phase 2).
- **`GamesService.addGameToWishlist(userId, gameId, priority)` already
  exists** (`flutter_app/lib/data/services/games_service.dart:126`) — it's
  dead code today (no UI calls it), same situation as the victory-stats RPCs
  noted in §14. Both Pull and Push end up calling this one method; Phase 2
  builds the UI around it once, and Push (Phase 4) reuses it rather than
  inventing a second wishlist-insert path.

Phases are ordered so each is independently shippable and testable before
the next starts — Pull ships completely before Push begins.

---

## Phase 0 — Foundation: Auto-Grant Library Access on Friendship

> **Status: Done**, applied to the live "Board Game Library" Supabase
> project (`oorilcytrytxhffindgy`) and verified against the seeded
> alice/bob/charlie test accounts. **Resolves PRD Open Question #6.**

**Decision: do this at the database level, not the client.** The web app
shares this backend and can create/accept friendships too; a client-side
"call `shareLibraryWith` after accepting" would silently not apply to
web-originated acceptances. A trigger is correct once, everywhere.

**Migrations shipped** (three, in sequence — the second and third were added
after testing surfaced gaps in the first, not part of the original plan):

1. `20260818090000_auto_grant_reciprocal_library_access.sql` — `AFTER UPDATE
   ON user_friends WHEN (NEW.status = 'accepted' AND OLD.status IS DISTINCT
   FROM 'accepted')` grants reciprocal `shared_library_access` (`view`, both
   directions, `ON CONFLICT DO NOTHING`); `AFTER DELETE` revokes both
   directions (unfriending).
2. `20260818091500_grant_library_access_on_direct_insert.sql` — the first
   migration only covered the `UPDATE` (pending→accepted) path. Testing (by
   restoring seed data through a direct `INSERT ... status='accepted'`)
   showed that path silently skipped the grant. Added a matching `AFTER
   INSERT` trigger on the same function, branching on `TG_OP` rather than
   relying on `OLD.status` (unassigned, and unsafe to reference, on insert).
3. `20260818093000_revoke_library_access_on_block.sql` — blocking
   (`status='blocked'`) is an `UPDATE`, not a `DELETE`, so the original
   revoke trigger never ran for it; a blocked user would have kept their
   library grant indefinitely. Extended the `UPDATE` branch to also revoke
   both directions on a transition to `blocked`.

**Related app-code bugs found and fixed while verifying this** (in
`flutter_app/lib/data/services/friends_service.dart`) — both pre-existing,
unrelated to the trigger design itself, but they determine whether the
triggers ever actually fire from real user actions:

- **`removeFriend`** matched only `.eq('user_id', userId).eq('friend_id',
  friendId)` — but `user_friends` is directional (`user_id` = whoever sent
  the original request, fixed at creation), so "Remove friend" silently did
  nothing for roughly half of friendships: whenever the person tapping
  Remove was the original *recipient*, not sender. Fixed to match either
  direction via `.or(...)`.
- **`blockUser`** had the identical bug (confirmed by grep: zero UI call
  sites today, so not yet user-facing, but it would have hit the same
  silent-no-op failure the moment a Block button is wired up). Fixed the
  same way.

**Verification performed:** directly against the live project (no local
Docker stack available) using the seeded alice/bob/charlie accounts —
cycled a friendship through delete → re-request → accept (confirmed both
grant paths and the delete-revoke path); simulated `removeFriend` and
`blockUser` from the *reversed* direction to confirm the `.or()` fix
actually finds the row; confirmed blocking revokes both
`shared_library_access` rows. All seed data was restored to its original
`accepted` state afterward — as a side effect, this also fixed the seed
data itself, which had inconsistent one-directional/mismatched-level access
predating this migration.

**Files:** three migrations under `supabase/migrations/`;
`flutter_app/lib/data/services/friends_service.dart` (`removeFriend`,
`blockUser`).

---

## Phase 1 — Pull: Friend's Library Screen

> **Status: Done**, verified end-to-end against the live "Board Game
> Library" Supabase project (`oorilcytrytxhffindgy`) using the sonderman ↔
> alice accepted friendship.

**Scope:** §13.1's browsing surface, read-only.

- Friends List rows (§4.9 — wherever that's rendered, currently inert beyond
  the overflow menu) become tappable → push a new route, e.g.
  `/library/friend/:friendId`.
- New screen reusing the My Library list/grid, search, and sort widgets
  (§4.3) — same components, scoped to `FriendsService.
  getSharedLibraryGames(friendId)` instead of the current user's library
  provider. Filters are explicitly out of scope for v1 per the PRD.
- Per-game card: strip the My-Library overflow actions that don't apply
  (Log Play / Favorite / For Sale / Remove) — this is someone else's
  library, read-only.
- Router: add the new route in `flutter_app/lib/core/router.dart` next to
  the existing `/library/*` sub-routes.

**What actually shipped, beyond the original scope:**

- **Friend management was split out of the read-only view entirely.** The
  original as-built Friends tab (on My Games) mixed browsing with
  add/accept/remove controls. That's now two surfaces: My Games → Friend's
  Games is purely read-only browsing (tap a friend → their library); all
  add/accept/remove/search lives in a new `Profile → Friends` screen
  (`friends_screen.dart`, route `/profile/friends`). A subtle banner on the
  read-only tab links to Profile → Friends only when there's a pending
  request to act on, rather than duplicating request-management UI in both
  places.
- **`FriendLibraryScreen` affordances**: an explicit AppBar back button (not
  relying on `Navigator.canPop()` inference) plus a "Viewing {friend}'s
  library (read-only)" banner with its own Back action, so it's unmistakable
  this isn't "My Library" — both use the same `GameCard` styling otherwise.
- **Dead-control fix in `game_card.dart`**: the list-layout favorite ⭐
  button was unconditional (`onPressed: onFavorite`), so on this read-only
  screen it rendered permanently greyed-out but tappable-looking — an App
  Store Guideline 2.1 dead control. Now falls back to a plain informational
  badge (matching the grid card's existing pattern) when `onFavorite` is
  null.

**Critical bug found during verification — the actual blocker, not a client
bug:** `user_library`'s only SELECT policy was `auth.uid() = user_id`
(owner-only). Phase 0's triggers correctly populate `shared_library_access`
on friend-accept, but nothing on `user_library` ever consulted that table —
so `getSharedLibraryGames(friendId)` silently returned zero rows for *any*
viewer, regardless of how correct the client/routing code was. This is why
"tap a friend" looked like "nothing happens": the screen opened, just always
empty. Fixed by migration
`20260818110000_grant_library_read_access_to_shared_viewers.sql`, an
additive permissive SELECT policy granting read access when a matching
`shared_library_access` row exists — combines via `OR` with the existing
owner-only policy, so owner access is unchanged.

**Verification performed:** directly against the live project (same
technique as Phase 0 — no local Docker stack available): simulated RLS as
`sonderman` (`auth.uid()` set via `request.jwt.claims`) both before and after
the migration — confirmed 0 rows before, alice's actual library (Root,
Terraforming Mars, Codenames, Azul, Wingspan, …) after.

**Files:** `friend_library_screen.dart` (new), `router.dart`,
`library_screen.dart` (Friends tab made tappable + simplified to read-only),
`friends_screen.dart` (new, Profile → Friends management),
`friend_row.dart` (new shared widget), `game_card.dart` (favorite-button
fix), `friends_service.dart` (search fixes, unrelated to this phase but
found along the way), one new migration under `supabase/migrations/`.

---

## Phase 2 — Pull: Add to Wishlist Action

> **Status: Code-complete**, `flutter analyze`/`flutter test` clean (16/16).
> Not yet manually verified against a live device/simulator — no RLS gap to
> hunt for this time (`user_wishlist`'s existing `auth.uid() = user_id`
> insert policy already covers it; unlike Phase 1, nothing needed to change
> at the database level), but UI/UX should still get an actual tap-through.

**Scope:** the one action §13.1 actually adds — wire the Friend's Library
card to the dormant wishlist path.

- Extend `GamesService.addGameToWishlist` to accept an optional `notes`
  param (currently `userId, gameId, priority` only) — needed for the
  "Seen in {friend}'s library" pre-fill the PRD specifies.
- Add the "Add to My Wishlist" card action from Phase 1's screen: default
  priority Medium, notes pre-filled/editable, success snackbar.
- Duplicate guard: before enabling the button, check the game against the
  current user's already-loaded `wishlistProvider`/`libraryProvider` state
  (no new query needed) — show "Already on your wishlist" / "Already in
  your library" (disabled) instead of allowing a second insert (the
  `UNIQUE(user_id, game_id)` constraint on `user_wishlist` would reject it
  anyway; this is just making the disabled state visible instead of erroring).
- **This is the shared component** Open Question #8 refers to — build it as
  a small reusable widget/method now (e.g. `addToWishlistAction(context, ref,
  game, {prefilledNotes})`) so Phase 4 (Push's Accept action) calls the same
  code rather than re-implementing the wishlist insert + snackbar.

**What actually shipped:**

- `GamesService.addGameToWishlist` takes an optional `notes` param (only
  written when non-empty, so untouched call sites are unaffected).
- `WishlistNotifier.addGame(gameId, {priority, notes})` — the actual shared
  insert path (not just the sheet UI around it): does the insert then a full
  `refresh()` rather than constructing a `WishlistEntry` locally, since the
  server assigns `id`/`addedDate` and the game's own record isn't loaded
  here to embed. This is what Phase 4's Accept action should call directly.
- `GameCard` gained a `WishlistStatus? wishlistStatus` (`addable` /
  `inWishlist` / `inLibrary`) and `onAddToWishlist` param, surfaced as an
  overflow-menu item — `addable` is tappable, the other two render
  **visible-but-disabled** (`PopupMenuItem(enabled: false)`) with the
  matching label, so the duplicate-guard state is legible instead of a
  second insert erroring against the `UNIQUE(user_id, game_id)` constraint.
  My Library's own cards pass neither param, so their menus are unaffected.
- `AddToWishlistSheet` (`lib/features/library/widgets/add_to_wishlist_sheet.dart`)
  — a bottom sheet (same shape as `log_play_sheet.dart`: cover/name preview,
  a field, a footer submit button) with a priority chip row (defaults to
  Medium) and a notes field pre-filled with `"Seen in {friend}'s library"`
  but editable. Calls `wishlistProvider.notifier.addGame` and pops with a
  success snackbar, or shows an inline error and stays open on failure.
- `FriendLibraryScreen` became a `ConsumerStatefulWidget` so it can watch
  `libraryProvider`/`wishlistProvider` (read-only — its own game list still
  comes from `getSharedLibraryGames`, per the file's original design note)
  to compute each card's `WishlistStatus` by cross-referencing `gameId`.
- **Follow-up, added after initial user feedback**: a successful add now
  navigates back to My Games → Wishlist Tab with the new entry scrolled into
  view. `pendingWishlistHighlightProvider` (`wishlist_provider.dart`) carries
  the target `gameId`; `LibraryScreen` watches it via `ref.listen` to switch
  `TabController` to the Wishlist tab (works even while `FriendLibraryScreen`
  is pushed on top, since that widget stays mounted underneath rather than
  disposed); `_WishlistTabState` watches it to `Scrollable.ensureVisible` the
  matching row (keyed per-entry via `GlobalKey`), clearing any active
  search/priority filter first if it would otherwise hide the target.

**Files:** `games_service.dart`, `wishlist_provider.dart`, `game_card.dart`,
`friend_library_screen.dart`, `add_to_wishlist_sheet.dart` (new, under
`lib/features/library/widgets/` — no `lib/features/wishlist/` existed, and
this pairs with the existing `log_play_sheet.dart` in the same directory),
`library_screen.dart` (Wishlist tab scroll-to-highlight, tab-switch listener).

**Verification still needed (manual):** add a friend's game to wishlist,
confirm it appears on the existing Wishlist Tab (§4.8) with correct
notes/priority; confirm a game already on the wishlist/in the library shows
the disabled menu state instead of "Add to Wishlist".

**→ Pull is now fully shippable.** Phases 0–2 can go out as a release before
Push work starts.

---

## Phase 3 — Push: Data Layer

**Scope:** §13.2's new table and service methods. No UI yet.

**Migration** (new file):
```sql
CREATE TYPE suggestion_status AS ENUM ('pending', 'accepted', 'dismissed');

CREATE TABLE game_suggestions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  recipient_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  game_id UUID NOT NULL REFERENCES shared_games(id) ON DELETE CASCADE,
  note TEXT,
  status suggestion_status NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```
- RLS: sender can `INSERT` where `auth.uid() = sender_id AND
  are_users_friends(sender_id, recipient_id)` (helper function already
  exists, `20260410102654_add_shared_library_tables.sql`); recipient can
  `SELECT`/`UPDATE` where `auth.uid() = recipient_id`; sender can `SELECT`
  their own sent suggestions too (for a future "sent" view, not required for
  v1 UI but cheap to include).
- Indexes on `recipient_id` (status = pending is the hot query) and
  `sender_id`.

**New `SuggestionsService`** (`flutter_app/lib/data/services/`), mirroring
`FriendsService`'s static-method style:
- `sendSuggestion(senderId, recipientId, gameId, {note})`
- `getPendingSuggestions(recipientId)` — joins `sender:profiles`,
  `game:shared_games`
- `acceptSuggestion(suggestionId, {userId, gameId})` — calls the Phase 2
  shared wishlist-add helper, then updates status to `accepted`
- `dismissSuggestion(suggestionId)` — updates status to `dismissed`

**Files:** one new migration, one new service file, one new model
(`GameSuggestion`, matching the PRD's §6 Data Models addition).

**Verification:** via `curl`/Supabase client directly (same technique used
to verify the anon key earlier in this project) — confirm a non-friend
sender is rejected by RLS, a friend sender succeeds, and the recipient can
update but the sender cannot.

---

## Phase 4 — Push: UI

> **Status: Done.** `flutter analyze`/`flutter test` clean (16/16); the
> Accept/Dismiss data flow verified directly against the live "Board Game
> Library" Supabase project (sonderman → alice), matching this section's
> manual verification steps. UI itself (friend picker, inbox rows, badge)
> not yet tap-tested on a device/simulator.

**Scope:** §13.2's user-facing flow, completing the feature.

- **Send:** "Suggest to a Friend" action added to the Game Detail Screen
  overflow menu (§4.6) and My Library card overflow menu (§4.3). Opens a
  friend picker (reuse the Friends List row UI — avatar, username, game
  count — filtered to accepted friends) → optional note field → Send →
  `SuggestionsService.sendSuggestion`.
- **Receive:** new "Suggested by Friends" section on the Wishlist Tab
  (§4.8), above the regular wishlist list. Each row: sender avatar/username,
  game cover/name, note, **Accept** / **Dismiss**.
  - Accept calls the Phase 2 shared wishlist-add helper (not a second
    implementation) + `SuggestionsService.acceptSuggestion`.
  - Dismiss calls `SuggestionsService.dismissSuggestion`, silent (no
    notification back to sender, per PRD).
- **Visibility:** a pending-count badge on the Wishlist tab, following
  whatever badge pattern the Friends tab's Pending Requests already uses
  (check `friends_screen.dart`/nav shell for the existing pattern before
  building a new one).

**What actually shipped:**

- `SuggestToFriendSheet` (`lib/features/library/widgets/suggest_to_friend_sheet.dart`)
  — same bottom-sheet shape as `add_to_wishlist_sheet.dart`/`log_play_sheet.dart`.
  Loads accepted friends via `FriendsService.getUserFriends`, reuses the
  shared `FriendRow` widget with a tap-to-select checkmark instead of a
  per-row action button (single friend selected at a time), optional note
  field, "Send Suggestion" footer button disabled until a friend is picked.
  Empty-friends state points to Profile → Friends. Wired into both entry
  points via `showSuggestToFriendSheet(context, game: game)`: Game Detail
  Screen's overflow menu and `GameCard`'s overflow menu (new
  `onSuggestToFriend` param, threaded through `_GridCard`/`_ListCard`/
  `_MenuButton` the same way Phase 2's wishlist action was) — My Library's
  own cards pass it, Friend's Library cards don't (not relevant there).
- `suggestionsProvider` (`lib/providers/suggestions_provider.dart`),
  `AsyncNotifierProvider<SuggestionsNotifier, List<GameSuggestion>>` loading
  `SuggestionsService.getPendingSuggestions`. `accept()` calls
  `ref.read(wishlistProvider.notifier).addGame(...)` — the exact Phase 2
  path, carrying the sender's note into the wishlist entry's notes — then
  `SuggestionsService.acceptSuggestion`; `dismiss()` calls
  `SuggestionsService.dismissSuggestion`. Both optimistically remove the
  suggestion from local state first, rolling back on failure (same pattern
  as `WishlistNotifier`/`LibraryNotifier`).
- **"Suggested by Friends" section** added to the Wishlist Tab
  (`library_screen.dart`'s `_WishlistTabState`), above the regular list:
  a `SUGGESTED BY FRIENDS (N)` header (matching the all-caps letter-spaced
  header convention already used for Requests/Sent/Friends sections
  elsewhere) followed by `_SuggestionRow`s (cover, game name, "From
  {sender}", note, Accept/Dismiss). The tab's `data:` builder now renders
  suggestions and wishlist entries in one combined `ListView` instead of
  two separate states, so the empty-state check and the highlight-scroll
  logic (Phase 2's follow-up) both account for suggestions being present
  even when the wishlist itself is empty.
- **Badge**: no existing "pending count on a tab" pattern was found in the
  codebase to reuse (the Friends tab's equivalent is an in-content banner,
  not a tab-label badge) — used Flutter's built-in `Badge` widget wrapping
  the "Wishlist" tab label instead, `isLabelVisible` gated on
  `suggestionsProvider`'s count.

**Deviation from the original sketch:** `acceptSuggestion(suggestionId, {userId, gameId})` in Phase 3's draft became two separate calls at the UI layer (`SuggestionsNotifier.accept`) rather than one method — see Phase 3's own deviation note for why.

**Files:** `suggest_to_friend_sheet.dart` (new), `suggestions_provider.dart`
(new), `game_card.dart` (`onSuggestToFriend` param), `game_detail_screen.dart`
(overflow menu item), `library_screen.dart` (My Library card wiring,
Wishlist tab suggestions section, tab badge).

**Verification performed** (data layer, direct-SQL-with-simulated-RLS
against the live project, same technique as Phases 0–3): sender (sonderman)
sends a suggestion to a friend (alice); recipient's pending-inbox query
returns it; Accept as recipient — insert into `user_wishlist` (own row,
satisfies existing RLS) + suggestion marked `accepted` — confirmed a real
wishlist row was created for alice carrying the sender's note, then cleaned
up; Dismiss as recipient — suggestion marked `dismissed`, confirmed zero
wishlist rows created, rolled back. **Still needed:** an actual device/
simulator tap-through of the new UI (friend picker, inbox rows, badge,
overflow menu placement) — not yet done this session.

**→ Push is now fully shippable** (pending the UI tap-through above).

---

## Phase 5 — Cleanup & Doc Sync

- Update `docs/PRD_FLUTTER_APP.md` §13's status banner from "Not yet built"
  to reflect shipped state (or split the banner if Pull ships well before
  Push).
- Remove/resolve Open Questions #6 and #8 in §12 once both are settled in
  practice.
- Update `docs/PRD_FLUTTER_APP_CODEBASE.md` — per that doc's own rule, only
  after the code lands (it's code-derived, not aspirational). This should
  flip the §7 "No in-app add-to-wishlist" and "Suggest access level
  unimplemented" limitations to reflect the new reality.
- Confirm no dead/placeholder controls were introduced (App Store Guideline
  2.1, §9a #3) — every new button (Add to Wishlist, Suggest, Accept,
  Dismiss) must be reachable and functional in the shipped build, not a
  stub.
- Add widget tests for the new screens/flows, following the existing pattern
  in `flutter_app/test/` (currently `dice_roller_test.dart`,
  `first_player_test.dart` — no friend/wishlist tests exist yet, so this
  establishes the pattern for that area).

---

## Sequencing summary

| Phase | Depends on | Shippable alone? |
|-------|-----------|-------------------|
| 0. Auto-grant library access | — | Yes (invisible until Phase 1/2 ship) |
| 1. Friend's Library screen | 0 | Yes, as a read-only browse feature |
| 2. Add to Wishlist action | 1 | Yes — **Pull complete** |
| 3. Suggestions data layer | — (independent of 0–2) | Backend-only, no user-facing change |
| 4. Suggestions UI | 2 (reuses its wishlist helper), 3 | Yes — **Push complete** |
| 5. Cleanup & doc sync | 4 | N/A |

Phase 3 has no dependency on 0–2 and could be built in parallel with them if
two people are working on this; Phase 4 is the only hard join point, since it
needs both the data layer (3) and the shared wishlist-add helper (2).
