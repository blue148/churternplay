# Product Requirements Document — Flutter Mobile App

> **Status:** As-Built · **Last updated:** 2026-08-18 · **Surface:** Native mobile
> (Flutter, iOS + Android; macOS build also present)
> Companion document: [`PRD_WEB_APP.md`](./PRD_WEB_APP.md). The mobile app shares
> the **same Supabase backend, data model, and visual language** as the web app.
> The web PRD is the source of truth for the shared design tokens; this document
> covers the mobile surface and where it intentionally differs.

---

## 1. Product Overview

The native mobile companion to the board game collection-management product. It
targets the **on-the-go and at-the-table** use cases: scanning a barcode to add a
game, pulling up your (or a friend's) collection, and running the "Game Nite"
tools during play — including mobile-native touches like **shake-to-roll dice**
and **shake-to-pick-first-player**.

- **Package / display identity:** Dart package `churntern_play`; iOS display name
  "Churntern Play"; auth-screen branding "The Catalogue".
- **Backend:** Same Supabase project as web (Auth, Postgres + RLS, Storage, Edge
  Functions). The app authenticates with `supabase_flutter` and reads/writes the
  same tables, so a user's catalogue, wishlist, sessions, and friends are shared
  across web and mobile.
- **Platforms:** iOS is the primary target (App Store submission pending).
  Android is now an active target: a Google Play beta (closed/internal testing
  track) is required alongside the iOS TestFlight beta. A macOS runner also
  exists but is not a release target.

---

## 2. Goals & Non-Goals

### Goals
- Frictionless **add-by-scan** in the real world (camera barcode → BGG enrichment
  → manual fallback with no dead ends).
- Fast access to your collection and Game Nite tools at the table.
- Native, tactile interactions (shake-to-roll, shake-to-pick, haptics) that the
  web can't match.
- Full **session logging** with player tracking, winner recording, and scores.
- Social layer: friend management, browsing friends' shared libraries.

### Non-Goals (current)
- Admin tooling (web-only).
- Marketplace / commerce.
- Offline-first / local-first sync (the app is online, talking to Supabase).
- Tablet-optimized layouts, iOS or Android (iPad must at least not be broken —
  see §9; Android phone form factor only for beta, no tablet layout pass).
- Full dark-mode parity (color scheme defined; incomplete — light mode only for v1).

---

## 3. Information Architecture & Navigation

Built on **go_router** with a `StatefulShellRoute.indexedStack` (persistent tab
state) and an auth redirect guard (unauthenticated → `/auth`).

Bottom navigation (`AppShell` → Material 3 `NavigationBar`):

| Tab | Route | Purpose |
|-----|-------|---------|
| **Dashboard** | `/dashboard` | Stats overview / quick actions |
| **Game Nite** | `/game-nite` | Tool launcher + five tool sub-pages |
| **My Games** | `/library` | Collection, wishlist, friends; add flows |
| **Profile** | `/profile` | Account management |

Sub-routes:
- `/game-nite/{chooser,first-player,turn-timer,game-timer,dice-roller}`
- `/library/scanner` — fullscreen camera dialog
- `/library/manual-add` — fullscreen BGG-search dialog (accepts optional `barcode`
  query param carrying a previously scanned but unrecognized barcode)
- `/library/friend/:friendId` — read-only friend's-library view (§13.1, done)
- `/profile/friends` — friend management: requests, sent, friends list,
  discovery/add (§4.9, done)

> §14 (planned) adds `/game-nite/log-play` and/or `/library/log-play` — a
> BGG-search dialog matching `/library/manual-add`'s pattern, feeding into the
> generalized Log Play sheet (§14.2–§14.3) — and a Play History screen
> reachable from Profile (§14.4).

---

## 4. Feature Requirements

### 4.1 Authentication & Account

**Auth Screen (`auth_screen.dart`)**
- Email/password sign-in and sign-up in a single screen.
- Form validation with real-time error messages.
- Password autofill support (iOS / 1Password).
- Vintage parchment-themed form design.

**Profile Screen (`profile_screen.dart`)**
- Displays avatar (initials fallback), username, bio.
- Shows aggregate stats: total games owned, favorites count.
- **Sign Out** — with confirmation.
- **Delete Account** — confirmation drawer warns about cascading data deletion;
  calls the `delete-account` Edge Function, which removes storage files, profile
  row, library/wishlist/session/friend records (required for App Store
  Guideline 5.1.1(v)).

> §14.4 (planned) adds a "Play History" row to the Profile menu, alongside the
> existing Wishlist/Friends/Shared Libraries/Settings stub rows.

---

### 4.2 Dashboard (`dashboard_screen.dart`)

**Quick Actions panel** — three tappable shortcuts to Game Nite tools:
- Game Picker, First Player, Turn Timer.

**Most Played** — horizontal scrollable row of the top 6 most-played games;
shows cover image + play-count badge; taps navigate to game detail.

**Collection Statistics** — 2×2 grid of four counters:
total games · favorites · played games · unplayed games.

**Recently Added** — up to 8 most recently added games as list items; shows
thumbnail, name, relative time ("2 weeks ago"), and chevron to detail.

**Pull-to-refresh** — reloads all dashboard data.

> §14.4 (planned) adds a "Recent Plays" teaser here, linking into the full
> Play History screen on Profile.

---

### 4.3 My Games — Library Tab

**Three tabs: My Library / Wishlist / Friend's Games** (renamed from
"Friends" — see §4.9).

#### My Library

**Display modes:**
- **List view** — detailed game cards with cover, name, publisher, player count,
  playtime, play-count badge, star icon.
- **Grid view** (3 columns) — cover-image dominant.
- On mobile, a two-part **List / Grid split button** within the My Library tab
  content switches modes persistently. The selected half is visually distinct.
  The layout control must not appear in the top-level My Games app bar.

**Progressive library controls (planned):** The primary behavior on My Library
is scrolling the user's game collection. Search, sort, filter, and quick-filter
controls therefore must not remain expanded above the collection by default.

- A compact, in-content toolbar appears above the results. It contains a
  **Find & refine** action and the List / Grid split button.
- Tapping **Find & refine** reveals the search field, sort action, filter action,
  and quick-filter chips in the tab content; tapping it again collapses them.
- Collapsing the controls preserves the current search query, sort selection,
  and filters. The compact action shows an active-state summary or badge so the
  user can tell that the visible collection is refined while the controls are
  collapsed.
- The control panel starts collapsed, minimizing fixed vertical chrome and
  leaving the collection as the dominant scroll surface. An active query,
  non-default sort, or filter is summarized without forcing the panel open.
- Search, sort, and filter behavior and options remain as specified below.

**Search** — free-text across name, publisher, and barcode; clears with ×.

**Sort options** (bottom sheet):
- Name A–Z / Z–A · Recently Added · Oldest First · Most Played · Least Played.

**Filter sheet** (multi-facet):

| Facet | Control |
|-------|---------|
| Publisher | Multi-select chips |
| Game Type | Multi-select chips |
| Category | Multi-select chips |
| Year | Multi-select chips |
| Personal Ranking | High / Medium / Low toggle |
| Player Count | 1–6+ chips |
| Play Count | Min / max range |
| Favorites Only | Toggle |
| For Sale Only | Toggle |

Active-filter badge on the filter icon shows the count of active facets.

**Quick-filter chips** — "Favorites" and "For Sale" preset chips appear below
search for one-tap filtering.

**Game card actions** (via per-card overflow menu):
- Log Play · Toggle Favorite · Mark / Unmark for Sale · Remove from Library.

**Floating action button** — opens a modal with two options:
- Scan Barcode (→ scanner)
- Search by Title (→ manual entry)

> §14.1 (planned) adds a third option here, "Log a Play (not in my library)" —
> a secondary entry point into the flow described in §14.

---

### 4.4 Scanner & Game Enrichment

**Scanner Screen (`scanner_screen.dart`)**

Full-screen camera feed with viewfinder overlay. On scan:

1. Checks the shared-games database for an existing entry.
2. If not found, calls the `barcode-lookup` Edge Function, which tries three
   services in priority order: GameUPC API → BarcodeLookup API → UPCItemDB API.
3. If a BGG ID is found, enriches with full game data via the `bgg-lookup` Edge
   Function.
4. If no BGG match: branches to **manual entry**, carrying the barcode through so
   it can be attached to the game the user picks.
5. On success: adds to library, shows success snackbar, returns to library.

Status messages shown during the async chain:
"Looking up barcode…" → "Searching game database…" → "Fetching game details…" →
"Adding to library…"

**Submit-barcode-mapping** — when a game is added via a scanned barcode (either
path), the barcode→BGG mapping is crowdsourced back via the
`submit-barcode-mapping` Edge Function.

---

### 4.5 Manual Game Entry (`manual_game_entry_page.dart`)

- Search field focused on load; queries BGG with sorted results: exact matches
  first, prefix matches second, newer years first.
- Result list shows cover, name, year, publisher, player count, playtime, min age.
- User selects a game → confirm or "Search Again" → "Add to Library."
- Carries through any barcode from a prior failed scan and attaches it to the
  final record.

---

### 4.6 Game Detail Screen (`game_detail_screen.dart`)

**Hero section** — large cover image (16:10), title, expansion badge (if
applicable), publisher/year/edition subtitle, player count · playtime · play
count stat pills.

**Victory Stats section** (shown when play history exists):
- Win rate percentage · total wins · best score · last played date.

**Tags section** — game types, categories, mechanics, and family classifications
rendered as chips.

**Notes** — user's personal notes for the game.

**Play History** — up to 10 most recent play dates; "+ N more" if truncated.

**Actions:**
- Star icon: toggle favorite.
- Overflow menu: Mark / Unmark for Sale · Remove from Library.
- "Log Play" bottom button → Log Play sheet.

---

### 4.7 Log Play Sheet (`log_play_sheet.dart`)

Modal bottom sheet for recording a completed game session.

**Session fields:**
- **Date & time** — date/time picker defaulting to now; accepts any date 2000
  through tomorrow.
- **Duration** (optional) — session length in minutes.

**Players panel:**
- Add Player button + recent-player quick-add chips (persisted across sessions).
- Per player: name field · winner toggle (trophy icon) · optional score · optional
  placement · remove button.
- Validates at least one named player; warns (overridable) if no winner is marked.

**Notes** (optional) — multi-line text for session notes.

**On submit:**
- Creates a `game_session` record.
- Creates `session_victory` rows (winner flag, score, placement per player).
- Appends play date to the library entry.
- Saves player names to recents.
- Shows success snackbar; closes sheet.

---

### 4.8 Wishlist Tab

- Search field.
- Priority filter chips: All / High / Medium / Low.
- Sort bottom sheet: Priority (default) · Name A–Z / Z–A · Recently Added ·
  Oldest First.
- Wishlist rows show cover, name, priority badge (HIGH / MED / LOW with color
  coding), notes, player count, playtime, and an overflow menu with:
  - Move to Library · Remove from Wishlist.
- Empty state: icon + "Your wishlist is empty."

> §13.1 **(done)** added mobile's first add-to-wishlist entry point: pulling
> a game from a friend's library. Landing here from that flow scrolls the
> newly added entry into view automatically, clearing the search/priority
> filter first if either would otherwise hide it. §13.2 (planned) adds a
> second entry point — accepting an incoming suggestion from a friend, shown
> as a new "Suggested by Friends" section above this list.

---

### 4.9 Friends Tab (My Games → **Friend's Games**) & Profile → Friends

> **Updated** during §13.1 (Phase 1): what this section originally described
> as one tab is now split across two surfaces. Friend *management*
> (add/accept/remove) and friend *library browsing* don't share a screen
> anymore — mixing them made the read-only browsing tab carry controls that
> don't belong to "browsing."

**My Games → Friend's Games** — read-only:
- Accepted friends list — avatar, username, game count. **Tappable** (§13.1,
  done): opens a read-only view of that friend's library.
- If there are pending incoming requests, a subtle banner ("N friend
  requests waiting") appears above the list, linking to Profile → Friends.
  No management controls live on this tab otherwise.
- Empty state — "No friends yet" with a prompt pointing to Profile →
  Friends.

**Profile → Friends** — all friend management:
1. **Requests** — incoming friend requests with an Accept action.
2. **Sent** — outgoing requests still awaiting the other person's response,
   each with a "Cancel request" action.
3. **Friends** — accepted friends; overflow menu with "Remove friend."
4. **Friend Discovery** — search field (min 2 characters, 400 ms debounce)
   matching username *or* display name; searching returns two grouped
   results: a **Current** section for matches already in the friends list
   (no duplicate "Add"), and an **Add Friends** section for everyone else,
   always shown (including an explicit "no matches" state, not a silent
   empty screen) with an "Add" button per result.

---

### 4.10 Game Nite Tools

Launcher screen (`game_nite_screen.dart`) — tappable rows with section-colored
icon chips leading to five tools.

> §14.1 (planned) adds a sixth tile, "Log a Play" — the primary entry point
> into the flow described in §14, for capturing plays of games not in the
> user's library (e.g. played at a convention, or a friend's copy).

#### 4.10.1 Game Chooser

**Library selection:** My library or a friend's shared library (chip toggle).

**Collapsible filters:**

| Filter | Control |
|--------|---------|
| Player Count | Stepper (1–20, or "Any") |
| Playtime Range | Dropdown: Any / Under 30 min / 30–60 min / Over 1 hour |
| Core Mechanic | Dropdown from 18 curated mechanics |

**Victory Intelligence** (My Library only, toggles):
- Favor winning games — weights selection toward higher win-rate titles.
- Avoid losing streaks — excludes games with <30% win rate.
- Only played games — excludes unplayed titles.

**Selection algorithm** — weighted random pick factoring win rate (optional),
favorite status, and recency discount (recently played games are down-weighted).

**Result display** — cover image, title, source attribution (if friend's library),
"Choose Game" / "Choose Again" button.

Active-filter count badge shows when filters are set; "Reset filters" link appears.

---

#### 4.10.2 First Player Picker

- Player name entry with auto-capitalize; Enter key to add.
- Recent players quick-add button (history icon) — persisted names, "forget"
  option per name, already-added names hidden from suggestions.
- Player grid (1–3 columns, responsive): card per player, delete button (×) while
  idle.
- **Shuffle animation** (3 phases):
  1. Cards flip to show back face.
  2. Cards fly through air with random waypoints and spin.
  3. Winner card enlarges (50%) and centers; others dim.
- "Pick First Player" button starts or re-shuffles; "Reset" clears result.
- **Shake gesture** triggers pick on mobile.

---

#### 4.10.3 Turn Timer

- Preset buttons: 30 s · 1 min · 2 min · 3 min · 5 min.
- Custom duration slider: 10 s – 5 min (10 s increments).
- Large 72 pt monospace display (MM:SS).
- Start / Reset controls.
- Color turns red/clay on expiry; haptic feedback fires at zero.

---

#### 4.10.4 Game Timer

- Full-session stopwatch.
- Large 72 pt monospace display (MM:SS; HH:MM:SS when over 1 hour).
- Start / Pause / Resume / Reset controls.

---

#### 4.10.5 Dice Roller *(mobile-exclusive)*

**Dice pool selector** — rows for d4, d6, d8, d10, d20; + / – buttons per type;
max 10 per type, 20 total.

**Die visuals:**
- d6: rounded square with pip dots (1–6).
- d4: triangle · d8: diamond octagon · d10: pentagon · d20: hexagon with inner
  triangle.

**Roll animation** — rapid face-value cycling on each die, staggered settlement,
wobble motion, haptic feedback at each die's settlement.

**Results** — dice settle to face values; large 56 pt monospace total (shows `—`
until first roll).

**Shake gesture** triggers roll.

Clear button resets pool.

---

## 5. Design System & Visual Guidelines

The mobile app implements the **same vintage/botanical "library" design language**
as web. Tokens are mirrored in `lib/core/theme/`.

### 5.1 Color (`app_colors.dart`)

Seven named ramps with identical hex values as web: parchment · forest · sky ·
clay/terracotta · wheat · plum · ink (+ `cream`/`warmGray` aliases).

Section-color convention on the Game Nite launcher: plum (Chooser) · clay (First
Player) · forest (Turn Timer) · sky (Game Timer) · wheat (Dice Roller).

> ⚠️ **Brand-color divergence from web.** The Material 3 `ColorScheme.primary` on
> mobile is **forest green** (`forest500` light / `forest200` dark), with clay as
> *secondary* and wheat as *tertiary*. The **web** uses **clay/terracotta** as
> primary. Until a deliberate decision is made, keep the palette identical and
> treat primary assignment as the accepted per-surface difference.

### 5.2 Typography

- **Display (headings, app bar titles):** Cormorant Garamond — serif, light
  weights, letter-spacing 0.5.
- **Body/UI:** Jost (clean sans-serif).
- **Numbers/data:** DM Mono — timers, scores, stat counters.

Helpers: `display()`, `body()`, `mono()`, `label()` (11 px, tracking 1.2),
`caption()` (10 px). Material `displayLarge…headlineSmall` also wired to
Cormorant via the text theme.

### 5.3 Shape, Surfaces & Spacing

- **Radius: flat 4 px** everywhere (inputs, buttons, cards).
- **Elevation 0**; surfaces white with thin parchment borders; dividers 1 px
  `parchment200`. Borders over shadows.
- Scaffold background `parchment50`; app bar white, serif title, no elevation
  (`scrolledUnderElevation` only).
- Filled `ElevatedButton` in `ink600`, wide-tracked Jost. Outlined buttons use
  parchment borders.
- Inputs: filled white, parchment border, `ink300` focus border, small tracked
  labels.
- `NavigationBar`: white, `forest100` indicator, forest selected state.

### 5.4 Motion & Native Feel

- Restrained animation; delight-only (chooser spin, first-player card shuffle).
- **Haptics and shake gestures** used in Dice Roller and First Player Picker —
  template for future mobile-exclusive tools.

### 5.5 Dark Theme

A dark `ColorScheme` is defined (inverted ink/parchment surfaces) but the dark
`ThemeData` is minimal/incomplete. **Default to and QA in light mode** until full
dark-mode parity is built.

### 5.6 Accessibility

- WCAG AA contrast on parchment surfaces.
- Tap targets meet platform minimums.
- Every visible control must perform an action (App Store Guideline 2.1).

---

## 6. Data Models

| Model | Key Fields |
|-------|-----------|
| `Game` | id, barcode, name, bggId, publisher, year, edition, coverImageUrl, gameType[], category[], mechanic[], family[], minPlayers, maxPlayers, playtime, isExpansion |
| `LibraryEntry` | id, game (Game), isFavorite, isForSale, personalRanking, playedDates[], notes, victoryStats? |
| `WishlistEntry` | id, game (Game), priority (high/medium/low), notes, createdAt |
| `VictoryStats` | totalSessions, totalWins, winRate, bestScore?, lastPlayedDate |
| `Friend` | UserFriend (status: pending/accepted/blocked), SharedLibraryAccess (level: view/suggest), AppProfile (username, bio, avatar, gameCounts) |
| `GameSuggestion` *(planned, §13.2)* | id, sender (AppProfile), recipient (AppProfile), game (Game), note?, status (pending/accepted/dismissed), createdAt |
| `GameSession` | id, userId, game (Game), sessionDate, durationMinutes?, playerCount, notes?, victories: SessionVictory[] — written by the Log Play sheet (§4.7); references `game_id` directly, independent of `LibraryEntry`/ownership. Read back today only as aggregated `VictoryStats`; §14.4 (planned) is the first surface to list raw sessions. |
| `SessionVictory` | id, sessionId, playerName (free text, no account link), isWinner, score?, placement? |

---

## 7. Backend Edge Functions

| Function | Purpose |
|----------|---------|
| `bgg-lookup` | Proxies BGG XML API; keeps API credentials server-side |
| `barcode-lookup` | Three-tier fallback: GameUPC → BarcodeLookup → UPCItemDB; returns name + BGG ID |
| `submit-barcode-mapping` | Crowdsources barcode→BGG ID mappings to grow the shared database |
| `delete-account` | Permanent account deletion with cascading data removal (App Store compliance) |

---

## 8. State Management

**Riverpod** async notifiers and providers:

| Provider | Purpose |
|----------|---------|
| `libraryProvider` | User's game library; exposes `toggleFavorite`, `toggleForSale`, `recordPlayedDate`, `removeGame`, `refresh` |
| `wishlistProvider` | User's wishlist; exposes `removeEntry`, `moveToLibrary`, `refresh` |
| `librarySearchProvider` | Search query string |
| `libraryFilterProvider` | Filter facets + sort selection |
| `recentPlayersProvider` | Persisted recent player names (SharedPreferences) |
| `profileProvider` | User profile + stats |
| `authStateProvider` | Auth state changes |

---

## 9. Launch Blockers

### 9a. App Store / TestFlight (iOS)

From the pre-submission review (`flutter_app/APP_STORE_REVIEW.md`, 2026-06-12).
These gate first submission and must be resolved before release:

1. **Privacy Manifest** (`ios/Runner/PrivacyInfo.xcprivacy`) — *hard blocker*.
   Declare required-reason APIs (`shared_preferences` UserDefaults `CA92.1`; cache
   libs' file-timestamp/disk-space reasons) and collected data (email, user
   content; tracking = false). Must be added to the Runner target.
2. **App Privacy questionnaire** (App Store Connect) — *hard blocker*. Declare
   Email + User Content, linked to user, app-functionality, **not** tracking;
   keep consistent with the manifest.
3. **Dead / placeholder UI** (Guideline 2.1) — *likely blocker*. Verify no
   tappable controls with no action remain in Profile or elsewhere.
4. **Export-compliance key** — add `ITSAppUsesNonExemptEncryption=false` to
   `Info.plist` (HTTPS-only app).
5. **Product identity** (Guideline 2.3) — align display name, App Store listing,
   in-app branding, bundle ID, and Dart package to one real name.
6. **iPad** — verify layouts on the largest reviewed device or restrict
   `TARGETED_DEVICE_FAMILY` to iPhone for v1.

**Suggested order:** (1)+(2) → (3) → (4)+(5) → (6).

### 9b. Google Play Beta (Android)

Android beta (closed or internal testing track) is required alongside
TestFlight. No pre-submission review has been run yet for Android — this list
is the Play Console equivalent of §9a and should get its own review pass
before first upload:

1. **`applicationId` / package identity** — *hard blocker*. Set a real,
   permanent `applicationId` in `android/app/build.gradle.kts` (cannot change
   after first Play Console upload); align with the iOS bundle ID decision in
   §12 #1.
2. **App signing** — *hard blocker*. Generate an upload keystore and enroll in
   Play App Signing; do not lose the upload key.
3. **Target API level** — *hard blocker*. Confirm `targetSdkVersion` meets
   Play's current minimum target API requirement at time of upload.
4. **Data safety form** (Play Console) — *hard blocker*. Declare the same data
   collection as the iOS App Privacy questionnaire (email, user content;
   shared/linked to user; not sold); keep the two declarations consistent.
5. **Dead / placeholder UI** — *likely blocker*, same underlying issue as §9a
   #3 (Profile stubs); Play's functionality policy also disallows non-working
   controls.
6. **Permissions** — declare and justify camera (barcode scanner) and any
   other runtime permissions in the Play Console app content section.
7. **Content rating questionnaire** and **privacy policy URL** — required to
   publish even to a closed testing track.
8. **Adaptive/launcher icon** — verify `android/app/src/main/res/mipmap-*`
   assets exist and match the current app icon (not yet audited).
9. **Testers** — set up the internal or closed testing track and tester list
   in Play Console before inviting beta users.

**Suggested order:** (1)+(2)+(3) → (4)+(6)+(7) → (5) → (8) → (9).

---

## 10. Mobile ↔ Web Parity Snapshot

**Web has, mobile doesn't (yet):**
- Admin panel (intentionally web-only).
- Full dashboard widget set parity.

**Mobile has, web doesn't:**
- **Dice Roller** with shake-to-roll + haptics.
- **Shake-to-pick** on First Player Picker.
- Remembered **recent players** for player-based tools.
- Barcode scanner (native camera, no web equivalent).

**Implemented on both:** core library management, wishlist, friends/friend
requests, game detail, session logging, Game Nite tools (non-camera).

---

## 11. Guidelines for Future Features

1. **Tokens first.** Use `app_colors` / `app_text_styles` / `app_theme`; never
   hardcode hex values. New colors must be added to both apps' palettes.
2. **Stay flat & papery.** 4 px radius, elevation 0, parchment borders, hairline
   dividers.
3. **Mono for numbers, serif for voice, Jost for UI.**
4. **No dead ends, no dead controls.** Every visible control must act.
5. **Exploit native advantages** — haptics, gestures, camera — where they add
   genuine value. The Dice Roller and First Player Picker are the templates.
6. **Respect the shared data model & RLS**; reuse Edge Functions for third-party
   lookups. Never embed external tokens in the app.
7. **Track parity** (§10): note in the PR whether a change should also land on
   web.
8. **Default to light mode** until dark theme is complete.

---

## 12. Open Questions

1. Final product name + bundle identity (blocks §9a #5 and §9b #1).
2. Primary brand color: align mobile with web (clay) or keep mobile forest?
3. Android beta timeline and target testers (internal vs. closed track,
   who's on the tester list) — see §9b.
4. Android-specific design pass: Material vs. continued Cupertino-leaning
   styling, minimum supported API level/device set.
5. Timeline/scope for completing dark mode.
6. ~~Should friendship acceptance auto-grant `view`-level
   `shared_library_access` in both directions, or stay a separate opt-in
   step?~~ **Resolved:** auto-grant, done via DB trigger — see the §13.1
   Gating note and `docs/IMPLEMENTATION_PLAN_FRIEND_FEATURES.md` Phase 0.
7. Once §13.1 (friend's-library browsing) ships, should §14.2's game-search
   step gain a friend's-library source too, so logging a play of a friend's
   copy doesn't require re-finding it on BGG?
8. §13.2's suggestion "Accept" and §14.5's post-log bridge both need an
   add-to-wishlist affordance — confirm they end up sharing one
   implementation rather than diverging once both are built.

---

## 13. Planned Feature: Two-Way Friend Game Suggestions

> **Status:** Pull (§13.1) is **built and shipped** — friend's-library
> browsing, auto-granted access, and the Add to Wishlist action described
> below all match the running app. Push (§13.2) is **not yet built**.
> Originally specified here to close two gaps noted in
> `PRD_FLUTTER_APP_CODEBASE.md` §7: wishlist entries couldn't be added from
> mobile at all (now fixed by §13.1), and the `suggest` value on
> `SharedLibraryAccess.accessLevel` is defined but unused (still true — see
> §13.2's recommendation to deprecate it once Push ships). §7 of the
> codebase doc still reflects pre-§13.1 code and is due for a sync pass once
> Push closes out this section (tracked as Phase 5 in
> `docs/IMPLEMENTATION_PLAN_FRIEND_FEATURES.md`).

**Goal:** Close the loop between browsing a friend's collection and your own
wishlist, in both directions:

- **Pull** — you see a game in a friend's library and want it for yourself
  eventually → add it straight to your own wishlist.
- **Push** — you own a game and think a specific friend would like it → send
  them a suggestion, which they can accept into their wishlist or dismiss.

Neither direction lets one user modify another user's data directly. A push
is a proposal the recipient must act on, consistent with the existing
wishlist RLS policy (`auth.uid() = user_id` on every write).

### 13.1 Pull: Add a Friend's Game to My Wishlist

> **Status: Done.** Shipped across `docs/IMPLEMENTATION_PLAN_FRIEND_FEATURES.md`
> Phases 0–2, verified against the live "Board Game Library" Supabase
> project. Details below are updated to match what's actually running,
> including a few decisions made during implementation that refine the
> original spec.

**New surface — Friend's Library.** My Games → **Friend's Games** tab
(renamed from "Friends" — see below) shows accepted friends; tapping one
opens `FriendLibraryScreen`, a read-only view of that friend's collection:
same `GameCard`/search/sort as My Library (§4.3), scoped to their
`user_library` via `FriendsService.getSharedLibraryGames`. Filter facets are
out of scope for v1 — sort and search are enough to find one game. The
screen carries explicit "whose library is this" affordances (an app-bar
title plus a "Viewing {friend}'s library (read-only)" banner with its own
Back action) so it's unmistakable this isn't My Library, since both reuse
the same card styling.

**Friend management moved out of My Games.** Not in the original spec, but
decided during Phase 1: mixing browsing with add/accept/remove controls
(as §4.9 originally described) meant the read-only Friend's Games tab
carried UI for actions that don't belong to "browsing," and vice versa.
Adding, accepting, and removing friends now live entirely on a new
**Profile → Friends** screen; My Games → Friend's Games is purely a
read-only friends list plus a subtle "N friend requests waiting" banner that
links to Profile → Friends only when there's something to act on. §4.9 below
is updated to match; treat this as amending that section, not §13.1 itself.

**Gating.** Requires an accepted friendship *and* a `shared_library_access`
row granting the current user at least `view` on that friend's library — the
same table and access check the Game Chooser (§4.10.1) already reads via
`FriendsService.getSharedLibraryGames`. **Done** (see
`docs/IMPLEMENTATION_PLAN_FRIEND_FEATURES.md` Phase 0): reciprocal `view`
access is now auto-granted by a DB trigger on `user_friends` acceptance
(covering both the normal accept-request update and a direct
accepted-status insert), and auto-revoked on unfriend or block — so this
feature and the existing Game Chooser friend-library toggle have data to
show with no manual sharing step. **A second gating layer was found and
fixed during Phase 1 verification:** granting `shared_library_access` alone
wasn't sufficient — `user_library`'s own RLS only ever allowed
`auth.uid() = user_id` (the owner), so a viewer's read returned zero rows
regardless of the grant. Migration
`20260818110000_grant_library_read_access_to_shared_viewers.sql` added the
missing SELECT policy. A dedicated "who can see my library" settings screen
(to let a user restrict this) is still a reasonable stretch goal, not
required for v1.

**Card action.** Each game in a friend's library gets one item in the
overflow menu in place of the My-Library actions that don't apply (Log Play
/ Favorite / For Sale / Remove — this is someone else's library, read-only):
**"Add to Wishlist."** Tapping it opens a bottom sheet (priority chips,
default Medium; notes field pre-filled with "Seen in {friend username}'s
library," editable) rather than inserting immediately — matches the
existing Log Play Sheet's shape (§4.7). Confirming:
- Inserts a `user_wishlist` row for the *current* user via
  `WishlistNotifier.addGame` — the one shared insert path Push's Accept
  (§13.2) should also call, per Open Question #8.
- Shows a success snackbar, then **navigates back to My Games → Wishlist
  Tab with the newly added game scrolled into view** (not in the original
  spec — added because landing back on Friend's Games after adding gave no
  confirmation the wishlist actually changed). If an active wishlist
  search/priority filter would hide the new entry, it's cleared first so
  the game is actually visible, not just scrolled to a filtered-out position.
- If the game is already on the user's wishlist or in their own library, the
  menu item reads "Already on Your Wishlist" / "Already in Your Library" and
  renders **visible-but-disabled** (not hidden) rather than allowing a
  duplicate `user_wishlist` row (the table has a `UNIQUE(user_id, game_id)`
  constraint already) — the state is legible instead of a second insert
  silently erroring.

### 13.2 Push: Suggest a Game to a Friend

**Entry points.** A new "Suggest to a Friend" action alongside existing
actions on:
- Game Detail Screen (§4.6) overflow menu.
- My Library card overflow menu (§4.3).

**Flow.** Tapping it opens a friend picker (reuses the Friends List UI
pattern from §4.9 — avatar, username, game count; accepted friends only) →
optional short note → Send. No priority field; priority is the *recipient's*
call once accepted, not the sender's.

**New surface — Suggestions inbox.** A new section, **"Suggested by
Friends,"** on the Wishlist Tab (§4.8), above the regular wishlist list,
showing pending incoming suggestions: sender's username/avatar, game cover
and name, optional note, and two actions:
- **Accept** — inserts a `user_wishlist` row for the recipient (their own
  insert, satisfies existing RLS) and marks the suggestion `accepted`.
- **Dismiss** — marks the suggestion `dismissed`; no wishlist entry is
  created. Dismissing is silent — the sender is not notified of a decline.

> §14.5 (planned) introduces mobile's other add-to-wishlist entry point (a
> post-log "Add to Wishlist" bridge). Accept here should reuse that same
> add-to-wishlist UI affordance rather than a second, divergent
> implementation — see Open Question #8.

A badge on the Wishlist tab (and/or a dashboard card, consistent with the
existing Pending Requests pattern on the Friends tab) surfaces the pending
count so suggestions aren't missed.

**Data model — new table, not a reuse of `suggest` access level.** Library
*visibility* (`shared_library_access.access_level`) and a one-off *suggest
this specific game* event are different concepts that the original schema
conflated. Recommend a dedicated table instead of wiring up the dormant
`suggest` enum value:

| Field | Notes |
|-------|-------|
| `id` | UUID PK |
| `sender_id` | references `profiles.id` |
| `recipient_id` | references `profiles.id` |
| `game_id` | references `shared_games.id` |
| `note` | optional, sender-authored |
| `status` | enum: `pending` / `accepted` / `dismissed` |
| `created_at` | |

RLS mirrors `user_friends`: sender can insert where `auth.uid() = sender_id`
and `are_users_friends(sender_id, recipient_id)` (helper already exists in
`20260410102654_add_shared_library_tables.sql`); recipient can select/update
rows where `auth.uid() = recipient_id`. On accept, the wishlist insert is a
second, separate write the recipient's own session performs — not a
`SECURITY DEFINER` bypass of wishlist RLS.

**Recommendation for the dormant `suggest` access level:** deprecate it.
Once `game_suggestions` exists, `shared_library_access.access_level` only
needs to answer "can this person see my library at all" — `view` is
sufficient, and a second, never-implemented level that "can recommend games"
is redundant with the new table.

---

## 14. Planned Feature: Play Log for Unowned Games

> **Status:** Not yet built. The backend already supports this: `game_sessions`
> / `session_victories` (`20260330000006_add_victory_tracking_tables.sql`)
> reference `game_id` directly, not `user_library` — there is no foreign key
> to library ownership, and RLS only checks `auth.uid() = user_id`. The only
> ownership coupling that exists today is in the UI: `showLogPlaySheet`
> (§4.7) requires a full `LibraryEntry`, and its submit flow makes a second,
> library-only write (`libraryProvider.recordPlayedDate`) that only makes
> sense when a library row exists. This section specifies the UI needed to
> reach the existing data-layer capability for games the user doesn't own.

**Goal:** Capture plays, players, winner, and notes for a game you played but
don't own and may never add to your collection — e.g. a demo at a
convention, or a one-off play of a friend's copy. The Wishlist is the wrong
home for this: it's a forward-looking "want to acquire" list (`priority`,
`notes`, `added_date`) with zero play-tracking fields — the opposite intent
of "already played." This is a third concept, independent of both Library
(own it) and Wishlist (want it).

### 14.1 Entry Points

- **Primary** — a new "Log a Play" tile in the Game Nite Tools launcher
  (§4.10, `game_nite_screen.dart`), matching the existing `_ToolRow` pattern
  (icon, iconBg, title, subtitle, onTap → route push). Fits the app's
  "at-the-table" framing directly — the convention scenario is inherently an
  at-the-table moment.
- **Secondary** — a third option, "Log a Play (not in my library)," in the
  Library FAB modal (§4.3), alongside the existing "Scan Barcode" / "Search
  by Title" options.
- Both are doors into the same flow (§14.2 → §14.3); no duplicate
  implementation.

### 14.2 Game Selection

Reuse `GamesService` (`games_service.dart`) directly — `searchBgg` →
`lookupBggById` → `getGameByBggId`/`upsertSharedGame` — the same
resolve-to-a-`Game`-row pattern `manual_game_entry_page.dart` (§4.5) already
uses, stopping short of its final `addGameToLibrary` call.

Explicit non-goals for v1:
- No friend-shared-library picker as an alternate source (would tie this to
  not-yet-built §13.1) — BGG search / manual entry only. Revisit as a
  follow-on once §13.1 ships (Open Question #7).
- No branching on "is this game already in my library." If it happens to be,
  the session is logged the same way — this flow simply never touches
  `user_library`. Two ways to log a play for an owned game (the existing
  per-card action, and this new generic flow) is acceptable overlap, not a
  bug to design around.

### 14.3 Logging Sheet (generalized Log Play Sheet)

`showLogPlaySheet`/`LogPlaySheet` (§4.7, `log_play_sheet.dart`) accepts
either a `LibraryEntry` or a lightweight `{gameId, gameName,
coverImageUrl}` reference. The one conditional behavior: the
`libraryProvider.recordPlayedDate(...)` call in `_submit` only runs when a
`LibraryEntry` was supplied; otherwise it's skipped. Everything else is
unchanged — date/duration fields, the free-text players panel with
recent-players quick-add (`recent_players_service.dart`, already
ownership-agnostic), `SessionsService.createSession`/`addMultipleVictories`,
the success snackbar.

### 14.4 Play History

- **Profile entry** — a new row on the Profile menu (§4.1), alongside the
  existing Wishlist/Friends/Shared Libraries/Settings rows, opening a full
  history screen: every session via `SessionsService.getUserSessions`
  (already ownership-agnostic), grouped by game, newest first.
- **Dashboard teaser** — a "Recent Plays" section on the Dashboard (§4.2)
  alongside Most Played / Recently Added, showing a few of the most recent
  sessions with a link into the full Profile history screen.
- First real call site for the currently dead
  `SessionsService.getGameVictoryStats`/`getOverallVictoryStats` RPCs — use
  them to show per-game and overall win-rate stats on the history screen.
- Read-only for v1: no edit/delete/filter (`SessionsService.updateSession`/
  `deleteSession` already exist for a later pass).

### 14.5 Post-Log Bridge

After logging a play for a game not already in the library: a dismissible,
non-modal prompt offering **both** "Add to Library" and "Add to Wishlist,"
using the already-resolved `Game` row from §14.2 (`addGameToLibrary` /
`addGameToWishlist` directly — no extra BGG round-trip). Someone who just
played a convention game they loved is in exactly the right headspace for
this nudge.

This makes §14 the first mobile entry point for adding to the wishlist,
ahead of §13.2. See Open Question #8 — §13.2's "Accept" and this bridge
should share one add-to-wishlist UI affordance rather than diverging.

### 14.6 Out of Scope for v1

- No linking free-text player names to friend accounts.
- No venue/convention/location metadata field on `game_sessions`.
- No edit/delete/filter on Play History.
- No friend-library game picker (deferred to post-§13.1).
- No schema or RLS changes — confirmed unnecessary; the data layer already
  supports this.
