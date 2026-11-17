# Product Requirements Document — Flutter Mobile App (Codebase-Derived)

> Derived from direct code analysis. Where intent is inferred rather than
> explicitly stated in code or comments, that is noted.

---

## 1. Overview

This is a native mobile application for managing a personal board game collection.
It is built with Flutter targeting iOS as the primary platform, with a macOS build
also present. The app connects to a shared Supabase backend — the same project used
by a companion web application — so a user's data is consistent across surfaces.

The core problem it solves is the friction of managing a physical board game
collection in a social context: adding games (by camera scan or search), tracking
what you own and what you want, logging plays with results, and running social
tools at the table (randomizers, timers, dice) without reaching for multiple
apps.

The app is branded "The Catalogue" at the auth screen. The Dart package is named
`churtern_play` and the iOS display name is "Churtern Play." These three
identities are inconsistent; the codebase does not resolve this.

---

## 2. Users and Roles

The codebase implements a single authenticated user role. There is no admin role,
moderator role, or read-only guest mode in the mobile app. (An admin panel exists
on the web surface; it is intentionally absent here.)

**Authenticated user — what they can see and do:**
- Full access to their own library, wishlist, and play history.
- Read access to friends' libraries (once a friend relationship is accepted), at
  the `view` access level; the code references a `suggest` level as well, but no
  UI surfaces it.
- Friend discovery: send requests, accept or decline incoming requests, remove
  existing friends.
- All Game Nite tools.
- Account deletion.

**Unauthenticated state:**
- The router redirects any non-`/auth` route to `/auth`. No content is visible
  without a session.

---

## 3. Core Workflows

### 3.1 Sign In / Sign Up

The `AuthScreen` handles both flows in a single screen. The user enters email and
password to sign in, or username, email, and password to sign up. Form validation
runs on submit. On success, `go_router`'s auth redirect guard detects the new
session and navigates to `/dashboard`. On error, an inline message is displayed.

### 3.2 Adding a Game by Barcode

1. From the My Library tab, the user taps the FAB and selects "Scan Barcode."
2. The `ScannerScreen` opens full-screen with a camera feed and viewfinder overlay.
3. On scan, the app queries the shared-games Supabase table first. If the barcode
   is already in the shared database, it skips external lookups.
4. If not found, it calls the `barcode-lookup` Edge Function, which tries three
   external services in sequence (GameUPC → BarcodeLookup → UPCItemDB). Status
   messages update the UI at each step.
5. If a BGG ID is returned, the app calls the `bgg-lookup` Edge Function to
   enrich with full game metadata.
6. On success, the game is added to the user's library and a success snackbar
   confirms it.
7. If no match is found at any step, the scanner routes to the manual entry page,
   carrying the raw barcode value in the query parameters so it can be attached
   to whichever game the user finds manually.
8. When a game is added with a barcode (either path), the barcode→BGG mapping is
   submitted back via `submit-barcode-mapping` to grow the shared database.

### 3.3 Adding a Game by Title Search

1. From the FAB, the user selects "Search by Title," or they arrive here from the
   scanner's not-found path.
2. The `ManualGameEntryPage` opens. The search field receives focus immediately.
3. The app queries the BGG API (proxied by `bgg-lookup`) as the user types or
   submits.
4. Results are sorted: exact name matches first, prefix matches second, then by
   year descending.
5. The user selects a result; a preview card shows metadata. They can confirm
   ("Add to Library") or "Search Again."
6. On confirm, the game is added to the library. If a barcode was carried from
   the scanner, it is attached to the record.

### 3.4 Browsing the Library

The My Library tab loads all `LibraryEntry` records for the current user via
`libraryProvider`. The user can:
- Toggle between list and grid view (persisted).
- Type into the search field to filter in real time across name, publisher, and
  barcode.
- Tap the sort icon to open a bottom sheet with six sort options.
- Tap the filter icon to open a multi-facet filter sheet (publisher, game type,
  category, year, personal ranking, player count, play count range, favorites,
  for sale). An active-filter count badge appears on the icon.
- Use quick-filter chips ("Favorites," "For Sale") for one-tap presets.
- Tap a game to go to its detail screen.
- Use the per-card overflow menu to toggle favorite, toggle for-sale, log a play,
  or remove the game.

### 3.5 Viewing Game Detail

The `GameDetailScreen` receives a `LibraryEntry` and a `Game`. It displays:
- A hero cover image.
- Publisher, year, edition, player count, playtime, and play count.
- Victory stats (win rate, total wins, best score, last played) if any sessions
  have been logged.
- Tags: game types, categories, mechanics, and family classifications.
- The user's personal notes.
- A list of the 10 most recent play dates (with a "+ N more" note if truncated).

From here, the user can toggle favorite, access the overflow menu (mark for
sale, remove from library), or tap "Log Play."

### 3.6 Logging a Play

The `LogPlaySheet` opens as a modal bottom sheet from the game detail screen or
from the per-card overflow menu.

The user fills in:
- Date and time (defaults to now; any date 2000–tomorrow is accepted).
- Duration in minutes (optional).
- One or more players: name, winner toggle, score, placement. The first player
  row is pre-populated; additional rows are added with "Add Player." Recent player
  names appear as quick-add chips and are persisted across sessions.
- Session notes (optional).

On submit, the app creates a `game_session` record and one `session_victory` row
per player, then appends the play date to the library entry. If no winner is
marked, the app warns but allows the user to submit anyway. Player names from
the session are saved to the recents list.

### 3.7 Wishlist

The Wishlist tab displays the user's `WishlistEntry` records. The user can:
- Search by name.
- Filter by priority (High / Medium / Low / All).
- Sort by priority, name, or date added.
- Move a wishlist item to the library (calls `moveToLibrary` on the notifier).
- Remove a wishlist item.

The code does not implement adding to the wishlist from within the mobile app.
The wishlist is populated from the web surface (this is inferred; no in-app add
flow exists in the Flutter code).

### 3.8 Friends

The Friends tab operates in three modes:

**Pending requests** — incoming friend requests are listed. The user taps Accept
to confirm the relationship.

**Friends list** — accepted friends show username and game count. An overflow menu
offers "Remove friend."

**Discovery** — a search field (minimum 2 characters, 400 ms debounce) queries
users by username. Results show a profile summary and an "Add" button to send a
request.

### 3.9 Game Nite — Game Chooser

The user selects a library source (their own or a friend's). A collapsible filter
panel exposes player count (stepper 1–20 or "Any"), playtime range (four options),
and core mechanic (18 options). When the source is the user's own library, three
additional toggles appear: favor winning games (weights by win rate), avoid losing
streaks (excludes games with < 30% win rate), and only played games.

Tapping "Choose Game" runs a weighted random selection. The result shows the cover
image, title, and source. The user can tap "Choose Again" to re-run without
changing filters.

### 3.10 Game Nite — First Player Picker

The user adds player names (text entry or quick-add from recents). Cards render
one per player in a responsive grid. Tapping "Pick First Player" or shaking the
device triggers a three-phase card animation (flip to back, fly through air,
reveal winner with enlargement). "Reset" clears the result for the next round.

### 3.11 Game Nite — Timers

**Turn Timer:** Preset buttons (30 s, 1 min, 2 min, 3 min, 5 min) or a 10 s–5 min
slider set the countdown. "Start" begins the countdown. The display turns red
and haptic feedback fires at zero.

**Game Timer:** A stopwatch for the full session. Start, Pause/Resume, and Reset
controls. Display switches from MM:SS to HH:MM:SS past 59:59.

### 3.12 Game Nite — Dice Roller

The user builds a dice pool by adding d4, d6, d8, d10, or d20 dice (up to 10 per
type, 20 total). Tapping "Roll" or shaking the device triggers a roll animation
in which each die cycles through face values and settles staggered, with haptic
feedback at each settlement. The total updates after every roll.

### 3.13 Dashboard

The Dashboard loads on app launch for authenticated users. It shows quick-action
shortcuts to three Game Nite tools, the top 6 most-played games, a 2×2 grid of
collection counts (total, favorites, played, unplayed), and a list of the 8 most
recently added games. Pull-to-refresh reloads all sections.

### 3.14 Account Deletion

From the Profile screen, the user can initiate account deletion. A confirmation
drawer warns that all data (library, wishlist, sessions, friends) will be
permanently removed. On confirm, the app calls the `delete-account` Edge Function,
which deletes storage files and cascades through all related Supabase tables, then
signs the user out.

---

## 4. Functional Requirements

### Authentication
- Email/password sign-in and sign-up.
- Session persistence via `supabase_flutter`.
- Auth-guarded routing: unauthenticated users see only the auth screen.
- Account deletion via server-side Edge Function with cascading data removal.

### Library Management
- View all library entries in list or grid layout.
- Free-text search across name, publisher, barcode.
- Sort by name (A–Z, Z–A), date added (newest, oldest), play count (most, least).
- Multi-facet filter: publisher, game type, category, year, personal ranking,
  player count range, play count range, favorites toggle, for-sale toggle.
- Quick-filter chips for favorites and for-sale.
- Toggle favorite status per game.
- Toggle for-sale status per game.
- Remove a game from the library.
- Add a game via barcode scan (camera).
- Add a game via BGG title search.
- View full game detail.

### Wishlist
- View wishlist items with priority (high/medium/low).
- Search wishlist by name.
- Filter by priority level.
- Sort by priority, name, or date added.
- Move wishlist item to library.
- Remove wishlist item.
- No in-app add-to-wishlist flow (see §7).

### Session Logging
- Record a game session from the detail screen or card overflow menu.
- Set session date/time (defaults to now).
- Set session duration (optional).
- Add one or more named players.
- Mark winner(s) per player.
- Record score and placement per player (optional).
- Add session notes (optional).
- Persist recent player names for quick re-entry.
- Warning when submitting with no winner marked.

### Friends
- Search for users by username (minimum 2 characters).
- Send a friend request.
- Accept incoming friend requests.
- Remove an existing friend.
- View a friend's game count.
- Browse a friend's shared library in the Game Chooser.

### Dashboard
- Quick-action shortcuts to Game Chooser, First Player, Turn Timer.
- Most-played games (top 6, horizontally scrollable, with play count).
- Collection statistics: total, favorites, played, unplayed.
- Recently added games (8 most recent, with relative time).
- Pull-to-refresh.

### Game Nite — Game Chooser
- Select library source: own or friend's.
- Filter by player count, playtime range, core mechanic.
- Toggle victory-weighted selection, losing-streak avoidance, played-only
  restriction (own library only).
- Weighted random game selection.
- Re-roll without changing filters.

### Game Nite — First Player Picker
- Add players by name (text entry or recents).
- Persist and manage recent player name list.
- Animated card shuffle and winner reveal.
- Shake-to-pick gesture.
- Reset for next round.

### Game Nite — Turn Timer
- Preset duration buttons.
- Custom duration slider (10 s–5 min).
- Countdown display with red state and haptic feedback at zero.

### Game Nite — Game Timer
- Start/pause/resume/reset stopwatch.
- Elapsed display, format-aware past 1 hour.

### Game Nite — Dice Roller
- Build a pool of d4, d6, d8, d10, d20 (up to 20 total dice).
- Roll with animated settlement and staggered haptics.
- Shake-to-roll gesture.
- Running total display.

### Game Detail
- Cover image, metadata, tags display.
- Victory statistics (win rate, wins, best score, last played).
- Play history (10 most recent dates).
- Personal notes.
- Inline favorite and for-sale toggles.
- Navigate to Log Play sheet.

### Barcode Enrichment (server-side)
- Three-tier fallback for barcode lookup: GameUPC → BarcodeLookup → UPCItemDB.
- BGG enrichment via proxied BGG XML API.
- Crowdsource barcode→BGG mappings on every successful add.

---

## 5. Data Model

The following entities are derived from the model files in `lib/data/models/`.

**Game**
Central catalog entity. Fields: `id`, `barcode` (optional), `name`, `bggId`
(optional), `publisher` (optional), `year` (optional), `edition` (optional),
`coverImageUrl` (optional), `gameType[]`, `category[]`, `mechanic[]`, `family[]`,
`minPlayers` (optional), `maxPlayers` (optional), `playtime` (optional),
`isExpansion`. A computed `playerCountLabel` formats the min/max range as a
string. Games live in a shared table; they are not per-user.

**LibraryEntry**
Joins a user to a game with user-specific state. Fields: `id`, `game` (Game),
`isFavorite`, `isForSale`, `personalRanking` (enum: high/medium/low, optional),
`playedDates[]`, `notes` (optional), `victoryStats` (VictoryStats, optional).
Computed: `playCount` (length of `playedDates`), `hasVictoryStats`.

**VictoryStats**
Embedded in `LibraryEntry` when play sessions exist. Fields: `totalSessions`,
`totalWins`, `winRate` (double 0–1), `bestScore` (optional), `lastPlayedDate`
(optional). Computed from `game_session` and `session_victory` records server-side;
not stored redundantly in the library entry at the Dart layer.

**WishlistEntry**
Fields: `id`, `game` (Game), `priority` (enum: high/medium/low), `notes`
(optional), `createdAt`.

**AppProfile**
Public user profile. Fields: `id`, `username`, `bio` (optional), `avatarUrl`
(optional), `totalGames`, `favoriteCount`. Used for friend display and discovery.

**UserFriend**
Represents a friendship edge. Fields: `id`, `userId`, `friendId`, `status` (enum:
pending/accepted/blocked), `createdAt`.

**SharedLibraryAccess**
Controls cross-user library visibility. Fields: `userId`, `friendId`,
`accessLevel` (enum: view/suggest). Used by the Game Chooser to load a friend's
games. The `suggest` level is defined in the model but no UI surfaces it.

The app does not define explicit `GameSession` or `SessionVictory` model classes
at the Dart layer — these are written to Supabase directly from the Log Play sheet
and read back only as aggregated `VictoryStats`.

---

## 6. Design Principles

The following are evident in `lib/core/theme/` and applied consistently across
all screens.

**Vintage library aesthetic.** The palette is named after physical materials:
parchment (cream backgrounds), ink (near-black text), clay/terracotta (primary
action color), forest (navigation and selected states), wheat (tertiary), sky
(informational), plum (creative/game tools). The naming is intentional; the code
comments reference a "vintage/botanical library" design language shared with the
web app.

**Typography as hierarchy signal.** Three typefaces carry distinct roles:
Cormorant Garamond (serif) for display and headings, Jost (sans-serif) for body
and UI labels, DM Mono for numeric data (timers, scores, counts). This is
enforced through helper functions (`display()`, `body()`, `mono()`) rather than
ad-hoc style assignment, which suggests it is a deliberate constraint, not
coincidence.

**Flat surfaces over depth.** Elevation is 0 throughout. Cards and inputs use
thin parchment-colored borders instead of shadows. Corner radius is 4 px
everywhere. This mirrors the web app and is explicitly noted in comments as an
intentional match.

**Native affordances where they add value.** Shake gestures (dice roller, first
player picker) and haptic feedback (dice settlement, timer expiry) appear only
where they replace a physical-world interaction. This is noted in a comment as
the template for future mobile-exclusive tools.

**No dead ends.** The barcode-to-manual-entry fallback, the "Search Again" path
in manual entry, and the explicit handling of not-found states suggest a design
constraint that every flow must have a completion path. This appears to be partly
driven by App Store Guideline 2.1 (noted in comments), but is applied beyond what
the guideline strictly requires.

**Shared tokens, per-surface primary color.** The mobile app assigns forest green
as `ColorScheme.primary`; the web app uses clay/terracotta. The codebase notes
this divergence explicitly and marks it as an open question rather than a
deliberate decision.

---

## 7. Out of Scope or Known Limitations

**No in-app add-to-wishlist.** There is no UI in the Flutter app for adding a
game to the wishlist. The wishlist is read-only from the mobile surface; games
can be removed or moved to the library, but new entries must be added from the
web app. (This is inferred from the absence of any add flow; no comment explains
the omission.)

**Suggest access level unimplemented.** The `SharedLibraryAccess` model defines
a `suggest` access level (presumably for recommending games to a friend), but no
UI references it. Only `view` is used.

**Victory stats are aggregated, not granular.** The app surfaces win rate, total
wins, best score, and last played date. Individual session history beyond play
dates is not browsable in the mobile UI. The `game_session` and `session_victory`
records are written to Supabase but no screen reads them back for display beyond
the aggregate.

**Dark mode is defined but incomplete.** A dark `ColorScheme` exists in the
theme configuration, but the dark `ThemeData` only sets the color scheme and
scaffold color. All other component styles default to light-mode values. The
codebase explicitly notes this and marks dark mode as a future requirement.

**No admin tooling.** The web app has an admin panel. The mobile app has no
admin routes, guards, or UI.

**Android is not a target.** The build configuration and entitlement files are
iOS-only. No Android-specific code or configuration is present.

**No offline capability.** All data operations go directly to Supabase. There is
no local cache, queue, or sync layer. If the network is unavailable, operations
fail.

**Personal ranking not settable in-app.** The `LibraryEntry` model includes a
`personalRanking` field (high/medium/low) and the filter sheet can filter by it,
but no UI in the mobile app sets or edits that value. (This is inferred from the
absence of a setter; the field is populated from the web surface.)

**App identity is inconsistent.** The Dart package name, iOS display name, and
in-app branding string are three different values. The codebase comments mark this
as a known issue and an App Store submission blocker but do not resolve it.

**App Store submission is not complete.** The codebase contains a file
(`flutter_app/APP_STORE_REVIEW.md`) that lists six unresolved items gating first
submission: Privacy Manifest, App Privacy questionnaire, any remaining dead
controls, export compliance key, product identity, and iPad layout verification.
