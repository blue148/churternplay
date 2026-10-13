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

Bottom navigation (`AppShell` → custom `_AppBottomNavBar`, replacing the stock
Material 3 `NavigationBar` so each item can carry both a tap and a long-press
handler; visual style — pill indicator, icon/label colors — is unchanged):

| Tab | Route | Purpose |
|-----|-------|---------|
| **Dashboard** | `/dashboard` | Stats overview / quick actions |
| **Game Nite** | `/game-nite` | Tool launcher + five tool sub-pages |
| **My Games** | `/library` | Collection, wishlist, friends; add flows |
| **Profile** | `/profile` | Account management |

A persistent **global Quick Actions button** (icon-only speed dial; see §4.2)
floats above the nav bar on every tab except Dashboard, which already
surfaces the same four actions as a full labeled row.

**Long-press section menus** — long-pressing the Game Nite, My Games, or
Profile tab opens a bottom sheet that jumps straight to one of that tab's
sections, bypassing the tab's own landing screen. Dashboard has no
sub-sections, so it has no long-press menu.
- **Game Nite** → Game Picker, First Player, Turn Timer, Game Timer, Dice
  Roller — same five tool routes as the launcher screen (§4.10).
- **My Games** → My Library, Wishlist, Friend's Games — navigates to
  `/library` and selects the matching `TabController` index via
  `pendingLibraryTabProvider`, an `int?` Riverpod notifier the library screen
  watches once and then resets to `null`, mirroring the existing
  `pendingWishlistHighlightProvider` pattern (§4.8).
- **Profile** → Friends, Profile Details, Settings (§4.1).

Sub-routes:
- `/game-nite/{chooser,first-player,turn-timer,game-timer,dice-roller}`
- `/library/scanner` — fullscreen camera dialog
- `/library/manual-add` — fullscreen BGG-search dialog (accepts optional `barcode`
  query param carrying a previously scanned but unrecognized barcode)
- `/library/friend/:friendId` — read-only friend's-library view (§13.1, done)
- `/profile/friends` — friend management: requests, sent, friends list,
  discovery/add (§4.9, done)
- `/profile/details` — **Profile Details** (§4.1); placeholder screen for
  editing avatar/username/bio, reachable from the Profile menu and its
  long-press entry
- `/profile/settings` — **Settings** (§4.1); placeholder screen, reachable
  from the Profile menu and its long-press entry

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
- Menu: **Friends** (→ `/profile/friends`, §4.9, done) · **Profile Details**
  (→ `/profile/details`, placeholder for now — will hold avatar/username/bio
  editing) · **Settings** (→ `/profile/settings`, placeholder) · **Privacy
  Policy** (done).
  - Wishlist was removed from this menu — it's covered by My Games →
    Wishlist (§4.3), reachable there or via the My Games long-press menu
    (§3).
  - Shared Libraries was removed for now. A "who can see my library"
    settings screen governing the same `shared_library_access` grants
    (§13.1) is still a possible future home for this, not necessarily
    distinct from the new Settings placeholder.
- **Sign Out** — with confirmation.
- **Delete Account** — confirmation drawer warns about cascading data deletion;
  calls the `delete-account` Edge Function, which removes storage files, profile
  row, library/wishlist/session/friend records (required for App Store
  Guideline 5.1.1(v)).

> §14.4 (planned) adds a "Play History" row to the Profile menu, alongside
> the Friends/Profile Details/Settings rows above.

---

### 4.2 Dashboard (`dashboard_screen.dart`)

**Quick Actions panel** — the app's four most-visited day-to-day actions, laid
out as a single row of four compact, equal-width cards (icon + label):
- Game Picker, First Player, Turn Timer, **Add Game** (opens the same
  Scan Barcode / Search by Title modal as the Library flow — see §4.3).

Labels are sized for legibility at this reduced card width/height rather than
being truncated; cards wrap to two lines instead of clipping if needed.

**Global Quick Actions button (`quick_actions_speed_dial.dart`, all other tabs)**
— once the user navigates off Dashboard, the same four actions remain within
thumb's reach via an expandable, icon-only FAB living in `AppShell`, floating
bottom-right just above the bottom nav bar:
- Collapsed state: a single circular button (bolt icon) — chosen over a `+`
  since Add Game is only one of the four actions, not the button's sole
  purpose.
- Tapping it fans out four small icon-only circular buttons (no labels) above
  it — Game Picker, First Player, Turn Timer, Add Game, in that order — behind
  a dismissible scrim; the bolt icon crossfades to a close (`×`) icon.
- Tapping a mini action, the scrim, or the toggle button again collapses it.
- Hidden on the Dashboard tab itself, since the full labeled row already
  covers this need there.

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
- Log Play · **Suggest to a Friend** (§13.2, done) · Toggle Favorite ·
  Mark / Unmark for Sale · Remove from Library.

**Add Game** — reached via the Dashboard's Quick Actions row or the global
Quick Actions button (§4.2), not a per-screen FAB on this tab. Opens a modal
with two options:
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
- Overflow menu: **Suggest to a Friend** (§13.2, done) · Mark / Unmark for
  Sale · Remove from Library.
- "Log Play" bottom button → Log Play sheet.

> **Planned:** two Game Detail Screen gaps, both not yet built.
>
> 1. **Better tag/pill presentation.** Today's Tags section (`_TagsSection`
>    in `game_detail_screen.dart`) flattens `game.gameType` + `gameCategory`
>    + `gameMechanic` + `gameFamily` into one undifferentiated `Wrap` of
>    identical pill chips, unlabeled and uncapped — a well-tagged BGG game
>    can easily carry 15–20 mechanics/categories combined, so the section
>    sprawls with no way to tell a "type" pill from a "mechanic" pill.
>    Needs: group into labeled sub-rows by facet (Type / Category / Mechanic
>    / Family — the same four facets the Library filter sheet already uses,
>    §4.3), and cap each facet's visible pills with a "+N more" expand,
>    mirroring the truncation pattern Play History already uses above.
> 2. **BGG written summary/description.** The `bgg-lookup` Edge Function
>    already parses a `description` field from BGG's XML `<description>`
>    node (`supabase/functions/bgg-lookup/index.ts`), and the web app's BGG
>    search/manual-entry types already carry it (`src/lib/bgg.ts`,
>    `ManualGameEntry.tsx`) — but it's never persisted (no `description`
>    column on `shared_games`) or displayed on either platform today. Needs:
>    a `description` column on `shared_games`; threading it through
>    `upsertSharedGame` and `Game.fromJson` (`game.dart`, which has no
>    `description` field yet); and a new "About" section on this screen
>    rendering it — below the Hero section, above Tags — truncated to ~4
>    lines with a "Read more" expand (BGG descriptions run long and often
>    carry HTML-entity boilerplate the Edge Function already decodes). Hidden
>    entirely for games added without BGG enrichment (manual entry with no
>    match, or BGG returned no description) rather than showing an empty
>    section.

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

- **Suggested by Friends** (§13.2, done) — a section above the regular
  wishlist list, shown only when there's at least one pending incoming
  suggestion: header "SUGGESTED BY FRIENDS (N)", then a row per suggestion
  (game cover/name, "From {sender}", optional note, **Accept** / **Dismiss**
  actions). Rendered as part of the same scrollable list as the wishlist
  proper, not a separate panel, so it stays visible even when the wishlist
  itself is empty. The Wishlist tab label also carries a numeric badge with
  the pending count.
- Search field.
- Priority filter chips: All / High / Medium / Low.
- Sort bottom sheet: Priority (default) · Name A–Z / Z–A · Recently Added ·
  Oldest First.
- Wishlist rows show cover, name, priority badge (HIGH / MED / LOW with color
  coding), notes, player count, playtime, and an overflow menu with:
  - Move to Library · Remove from Wishlist.
- Empty state: icon + "Your wishlist is empty."

> §13.1 and §13.2 **(both done)** gave mobile its first two add-to-wishlist
> entry points, both routing through the same `WishlistNotifier.addGame`
> insert path: pulling a game from a friend's library (§13.1) and accepting
> an incoming suggestion (§13.2, the section above). Landing on this tab
> after either action scrolls/surfaces the result automatically — the newly
> added entry for Pull (clearing the search/priority filter first if either
> would otherwise hide it), the suggestions section itself for Push.

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

#### 4.10.1 Game Picker

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
| `GameSuggestion` *(§13.2, done)* | id, senderId, recipientId, gameId, sender? (AppProfile), recipient? (AppProfile), game? (Game), note?, status (pending/accepted/dismissed), createdAt |
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
These gate first submission and must be resolved before release. Items 1–2
are also tracked in the cross-platform
[`docs/PRIVACY_RELEASE_CHECKLIST.md`](./PRIVACY_RELEASE_CHECKLIST.md), which
has the actual outstanding actions behind them (the `profiles` RLS
email-leak fix, a monitored privacy/support contact, and deploying the
hosted `/privacy/` page that store listings must link to — a separately
maintained copy of the same content as the in-app Privacy Policy screen,
§4.1) — resolve that checklist's
"Required before store submission" items alongside 1–2 here, not as a
separate later pass.

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
7. **App icon & App Store Connect listing assets** — *hard blocker*, not yet
   produced/audited:
   - 1024×1024 App Store icon (opaque, no alpha channel, no pre-rounded
     corners — Apple applies the mask) plus the full iOS icon-set sizes
     generated from it into `Assets.xcassets` (Flutter: `flutter_launcher_icons`
     or manual Xcode asset catalog entries).
   - App Store Connect screenshots for each required device size (6.9" and
     6.5" iPhone at minimum, per current Apple requirements at submission
     time); iPad screenshots too if §9a #6 keeps iPad enabled.
   - Listing copy: app name, subtitle, promotional text, description,
     keywords, support URL, marketing URL (optional), and the hosted privacy
     policy URL (`docs/PRIVACY_RELEASE_CHECKLIST.md`, above).
   - App preview video is optional, not required for v1.

**Suggested order:** (1)+(2) → (3) → (4)+(5) → (6) → (7).

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
   publish even to a closed testing track. Same hosted `/privacy/` URL as
   §9a #7's App Store Connect listing; see the cross-platform
   [`docs/PRIVACY_RELEASE_CHECKLIST.md`](./PRIVACY_RELEASE_CHECKLIST.md) for
   the outstanding work behind it (RLS email-leak fix, monitored contact,
   deploying the page) before it can be entered here.
8. **App icon & Play Console listing assets** — *hard blocker*, not yet
   produced/audited:
   - Adaptive/launcher icon — verify `android/app/src/main/res/mipmap-*`
     assets exist and match the current app icon.
   - 512×512 Play Store listing icon (32-bit PNG, with alpha).
   - 1024×500 feature graphic.
   - Phone screenshots (minimum 2, per current Play requirements at upload
     time); 7"/10" tablet screenshots only if a tablet layout pass happens.
   - Listing copy: app title, short description, full description, category,
     contact details.
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
   add-to-wishlist affordance. **Partially resolved:** §13.1 (Pull) and
   §13.2 (Push Accept) both route through `WishlistNotifier.addGame` — one
   implementation, confirmed for those two. Stays open until §14.5 is built
   and confirmed to call the same path rather than a third implementation.

---

## 13. Planned Feature: Two-Way Friend Game Suggestions

> **Status:** Both directions are **built and shipped** — Pull (§13.1) and
> Push (§13.2) below both match the running app, across
> `docs/IMPLEMENTATION_PLAN_FRIEND_FEATURES.md` Phases 0–4. **Not yet done:**
> an actual device/simulator tap-through of Push's UI (friend picker, inbox
> rows, badge) — Phase 4's data flow (send/accept/dismiss) was verified
> directly against the live Supabase project, not the UI itself. Originally
> specified here to close two gaps noted in `PRD_FLUTTER_APP_CODEBASE.md`
> §7: wishlist entries couldn't be added from mobile at all (fixed by
> §13.1), and the `suggest` value on `SharedLibraryAccess.accessLevel` was
> defined but unused (now superseded by the `game_suggestions` table — see
> §13.2's recommendation to deprecate it). §7 of the codebase doc still
> reflects pre-§13 code and is due for a sync pass (tracked as Phase 5 in
> `docs/IMPLEMENTATION_PLAN_FRIEND_FEATURES.md`, the only phase left).

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
same table and access check the Game Picker (§4.10.1) already reads via
`FriendsService.getSharedLibraryGames`. **Done** (see
`docs/IMPLEMENTATION_PLAN_FRIEND_FEATURES.md` Phase 0): reciprocal `view`
access is now auto-granted by a DB trigger on `user_friends` acceptance
(covering both the normal accept-request update and a direct
accepted-status insert), and auto-revoked on unfriend or block — so this
feature and the existing Game Picker friend-library toggle have data to
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

> **Status: Done** (`docs/IMPLEMENTATION_PLAN_FRIEND_FEATURES.md` Phases 3–4).
> The send/accept/dismiss data flow — including RLS (a non-friend sender is
> rejected, only the recipient can act on a suggestion) and the Accept
> wishlist-insert — is verified directly against the live "Board Game
> Library" Supabase project. The UI itself hasn't had a device/simulator
> tap-through yet. Details below are updated to match what's actually
> running.

**Entry points.** A new "Suggest to a Friend" action alongside existing
actions on:
- Game Detail Screen (§4.6) overflow menu.
- My Library card overflow menu (§4.3).

**Flow.** Tapping it opens a bottom sheet (`SuggestToFriendSheet`, same
shape as §13.1's Add to Wishlist sheet and the Log Play Sheet, §4.7):
accepted friends listed via the shared `FriendRow` widget (avatar, username,
game count — the same row component the Friends screen and Friend's Games
tab use, not a separate reimplementation) with a tap-to-select checkmark →
optional note field → "Send Suggestion," disabled until a friend is picked.
No priority field; priority is the *recipient's* call once accepted, not the
sender's. An empty-friends state points to Profile → Friends.

**New surface — Suggestions inbox.** A new section, **"Suggested by
Friends,"** on the Wishlist Tab (§4.8), above the regular wishlist list —
rendered as part of the same scrollable list rather than a separate panel,
so the tab's existing empty-state and search/filter logic both account for
suggestions being present even when the wishlist itself is empty. Each row:
sender's username, game cover and name, optional note, and two actions:
- **Accept** — inserts a `user_wishlist` row for the recipient via
  `WishlistNotifier.addGame` (§13.1's exact shared insert path — the
  sender's note carries over into the wishlist entry's notes) and marks the
  suggestion `accepted`.
- **Dismiss** — marks the suggestion `dismissed`; no wishlist entry is
  created. Dismissing is silent — the sender is not notified of a decline.

> §14.5 (planned) introduces mobile's other add-to-wishlist entry point (a
> post-log "Add to Wishlist" bridge). It should call `WishlistNotifier
> .addGame` too, the same path §13.1 and §13.2 both already share — Open
> Question #8 is resolved for the two directions built so far, but stays
> open until §14.5 actually lands and confirms it follows suit.

**Badge.** No existing "pending count on a tab label" pattern was found to
reuse — the Friends tab's Pending Requests is an in-content banner, not a
tab badge, so this uses Flutter's built-in `Badge` widget on the "Wishlist"
tab label instead, shown only when the count is above zero. A dashboard
card was considered but not built (not required for a working v1).

**Data model — new table, not a reuse of `suggest` access level.** Library
*visibility* (`shared_library_access.access_level`) and a one-off *suggest
this specific game* event are different concepts that the original schema
conflated. Built as a dedicated table (`game_suggestions`, migration
`20260818120000_create_game_suggestions.sql`) instead of wiring up the
dormant `suggest` enum value:

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
  existing Friends/Profile Details/Settings rows, opening a full
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

§13.1 (Pull) and §13.2 (Push Accept) shipped first and already established
`WishlistNotifier.addGame` as the one add-to-wishlist insert path (§13's
status banner) — this bridge should call that too, not
`addGameToWishlist`/`addGameToLibrary` directly as originally written above,
so all three entry points share the same code. See Open Question #8.

### 14.6 Out of Scope for v1

- No linking free-text player names to friend accounts.
- No venue/convention/location metadata field on `game_sessions`.
- No edit/delete/filter on Play History.
- No friend-library game picker (deferred to post-§13.1).
- No schema or RLS changes — confirmed unnecessary; the data layer already
  supports this.

---

## 15. Planned Feature: Ad Placement

> **Status:** Not yet built — this is a placement/layout spec, not an
> implementation; no ad SDK is integrated yet. Full detailed spec (exact file
> paths, line numbers, and rationale) lives at
> [`flutter_app/docs/AD_PLACEMENT_RECOMMENDATION.md`](../flutter_app/docs/AD_PLACEMENT_RECOMMENDATION.md)
> — this section summarizes it for PRD tracking; treat the linked doc as
> source of truth if the two ever drift.

**Goal:** Introduce contextual native ads (game companies, events, publishers,
etc.) on Dashboard (§4.2), Game Nite + its tools menu (§4.10), My Library, and
Wishlist (§4.3/§4.8) without degrading the experience or reading as injected/
foreign content. Mobile-only for now — not present in the web PRD.

### 15.1 Principles

- **In-flow, never anchored.** No sticky top/bottom ad bars anywhere — every
  slot is a regular scrollable item that scrolls with its list/grid like any
  other row or card.
- **Native, not a banner.** Ad slots match the surrounding card/row family
  (corner radius, padding, type scale, `AppColors` tokens) so they read as
  "one more card," not a foreign unit.
- **Sparse by default.** See cadence rules (§15.4). Short/non-scrolling
  screens get at most one slot for the whole screen; nothing shown when
  content is too sparse to support it.
- **Never adjacent to interactive/destructive controls.** No slot sits next
  to a tappable tool row, a delete/swipe action, or any control where an
  accidental tap could be mistaken for part of the ad.
- **Clearly labeled.** Every slot carries a small "Sponsored"/"Ad" tag —
  required by App Store Review Guideline 3.2.2, Google Play's ads policy, and
  the disclosure terms of every major ad network.
- **Ad-network-agnostic.** Placement and rendering are decoupled from any
  specific SDK, so swapping/mediating networks later doesn't touch any
  screen's layout code.

### 15.2 The adapter seam: `NativeAdContent`

A single data model absorbs the asset overlap across native-ad SDKs (AdMob
`NativeAd`, Meta Audience Network `NativeAdView`, Mintegral, etc.):
`headline`, `body?`, `iconAsset?` (small square icon/logo), `mediaAsset?`
(larger hero image, optional), `ctaLabel`, `advertiserName?`,
`sponsoredLabel` (defaults to "Sponsored"). Whichever SDK is chosen later,
its adapter's only job is to populate this object — the rendering widget
never needs to know which network filled it.

### 15.3 Component shape

- **`AdSlot` widget** (`lib/core/ads/ad_slot.dart`), parameterized by an
  `AdSlotFormat`:
  - `listRow` — mirrors the list-row card family already used by
    `GameCard`'s `_ListCard` and Wishlist's `_WishlistItemRow`: 72×72
    leading image/icon, headline + body text, small CTA button; matches
    their row height/spacing.
  - `gridRow` — a full-width row spanning all grid columns (a single grid
    *cell* is too narrow for native ad copy at the library grid's current
    `childAspectRatio: 0.55`).
  - `sectionCard` — mirrors Dashboard's `_SectionHeader` spacing/card
    padding for single-slot placements on non-list screens.
  - All formats show the `sponsoredLabel` in a small tag using existing
    `AppColors` neutrals (e.g. `parchment200`/`ink200`) so it sits inside the
    app's own theme rather than looking like an imported ad unit.
- **`ad_placement.dart`** — shared cadence helpers so insertion logic isn't
  duplicated per screen: `shouldInsertAdAfterListIndex(int index, {required
  int itemCount})` and `gridAdRowIndices(int itemCount, {required int
  crossAxisCount})` (returns which grid row numbers should be ad rows).

### 15.4 Cadence rules

| Context | Rule |
|---|---|
| List rows (Library list, Wishlist) | 1 ad after every **8 real items**; never before the first 6 items; none below 6 items total. |
| Grid tiles (Library grid) | 1 full-width ad row after every **3 grid rows** (every 9 tiles at the current 3-column layout); same minimum-item guard. |
| Short/non-scrolling screens (Dashboard, Game Nite menu) | Exactly **one** ad slot for the whole screen; never inserted between two functional/interactive rows. |

Intentionally conservative — favors trust and retention over ad density. Can
tighten later against real engagement/revenue data without changing the
underlying component.

### 15.5 Per-screen placement

| Screen | Layout | Ad format | Placement |
|---|---|---|---|
| Dashboard (§4.2) | Sectioned `ListView` | `sectionCard` | One slot inserted between Collection Statistics and Recently Added, same `SizedBox(height: 24)` section gap — reads as a 5th section, sits mid-scroll rather than first (unmissed) or last (may never be scrolled to). |
| Game Nite menu (§4.10) | 5-row `ListView` (`_ToolRow` + divider) | `listRow` | One slot appended **after** the Dice Roller row, same divider style, clearly labeled "Sponsored" so it's unambiguous it isn't a 6th tool. Five tappable rows is too short/interactive to interleave between any two. |
| My Library — list (§4.3) | `ListView.separated` | `listRow` | Routed through `shouldInsertAdAfterListIndex`, inserted in place of a `GameCard` at computed positions. |
| My Library — grid (§4.3) | `GridView` (3 cols, `childAspectRatio: 0.55`) | `gridRow` | Requires converting to `CustomScrollView`/`SliverMainAxisGroup` alternating `SliverGrid` chunks (same delegate/spacing as today) with `SliverToBoxAdapter(AdSlot)` breaks, sized via `gridAdRowIndices`; preserves existing `RefreshIndicator`/padding. |
| Wishlist (§4.8) | `ListView.separated` (`_WishlistItemRow`) | `listRow` | Same index-based insertion as Library list. Matters doubly here since each row carries a `PopupMenuButton` (edit/delete) — index-based (not scroll-position-based) insertion naturally avoids landing an ad adjacent to a row a user is mid-interaction with. |

**Future extension (out of scope for this pass):** individual Game Nite tool
result/output screens (e.g. after Game Chooser reveals a pick, or First
Player reveals a winner) are natural contextual pause points — would pair
well with contextual ads (related games, local game-night events). Worth a
follow-up placement recommendation once those flows are prioritized.

### 15.6 Out of Scope for v1

- No ad network/SDK selection or integration — this is placement/layout only.
- No mediation logic between networks.
- No frequency-capping or revenue-optimization tuning beyond the cadence
  rules above.
