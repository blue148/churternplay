# Product Requirements Document — Web App (DRAFT)

> **Status:** Draft · **Last updated:** 2026-06-15 · **Surface:** Responsive web (React + Vite)
> Companion document: [`PRD_FLUTTER_APP.md`](./PRD_FLUTTER_APP.md) (mobile). The two
> apps share one backend, one data model, and one visual language; this PRD owns the
> web surface and is the **source of truth for the shared design system** unless
> noted otherwise.

---

## 1. Product Overview

A board game collection-management application for hobbyists who own physical
games and play them socially ("game nights"). Users catalogue what they own,
track a wishlist, look games up by barcode, browse friends' collections, and use
a set of "Game Nite" utilities (pick a game, pick a first player, time turns and
sessions) during play. Play sessions and per-player victories are recorded to
power stats.

- **Internal/package name:** `libre-ludorum` ("Libre Ludorum" — *a free and open
  board game collection management application*).
- **In-app branding (current):** "Churtern•Play" (top nav / mobile header).
- **Backend:** Supabase (Postgres + Row-Level Security, Auth, Storage, Edge
  Functions). The frontend talks only to Supabase; third-party lookups (BoardGameGeek,
  barcode databases) are proxied through Edge Functions so API tokens stay server-side.

> ⚠️ **Open branding decision.** Product identity is inconsistent across surfaces
> ("Libre Ludorum" / "Churtern•Play" / "The Catalogue" / "Churntern Play" on
> mobile). A single product name, wordmark, and bundle identity should be decided
> and applied across both apps. Tracked as a launch blocker on mobile
> (see Flutter PRD §8).

---

## 2. Goals & Non-Goals

### Goals
- Make cataloguing a physical collection fast (barcode scan + BGG enrichment, or
  manual entry).
- Give a confident "what should we play / who goes first" answer at the table.
- Turn play history into lightweight, motivating stats.
- Let friends see and suggest from each other's collections.

### Non-Goals (current)
- Marketplace / transactions (a `for_sale` flag exists but there is no commerce flow).
- Real-time multi-device session sync during play.
- Rules reference / how-to-play content.
- Social feed / activity stream beyond friends' library browsing.

---

## 3. Users & Roles

| Role | How it's set | Capabilities |
|------|--------------|--------------|
| Authenticated user | Supabase Auth (email) | Full personal collection, wishlist, sessions, friends, Game Nite tools |
| Admin | `profiles.is_admin = true` | Everything above **plus** the Admin panel (catalog/data management) |
| Friend (viewer) | `shared_library_access` grant | Read (`view`) or read+suggest (`suggest`) on another user's collection |

---

## 4. Information Architecture & Navigation

Top-level tabs (state-driven, single-page; no URL router today):

- **Dashboard** — stats and quick actions; the landing tab.
- **Game Nite Tools** — Game Chooser, First Player, Turn Timer, Game Timer.
- **My Catalogue** (Library) — collection + wishlist, filtering, add/edit, scanner.
- **Admin** — admin-only catalog/data management.
- **Profile** — account, friends, shared libraries, preferences (drawer on desktop,
  full page on mobile).

**Responsive model:**
- **Desktop (`md+`):** sticky top nav with wordmark; the active tab is marked by a
  decorative 3D "wooden disc" indicator. Profile opens as a right-hand drawer.
- **Mobile (`< md`):** slim top header (wordmark + avatar button) and a fixed
  bottom tab bar; Profile becomes a full-page tab. Page content reserves bottom
  padding to clear the fixed nav.

> The web app is genuinely responsive and is the de-facto mobile web experience.
> The Flutter app is a separate native surface, not a wrapper.

---

## 5. Feature Requirements

### 5.1 Authentication & Account
- Email-based sign-in/up via Supabase Auth (`AuthForm`).
- Profile auto-provisioned with `preferences` (theme, notifications, default view,
  saved player names, game-timer state), `total_games`, `favorite_count`, `is_admin`.
- In-app account deletion supported via the `delete-account` Edge Function.

### 5.2 Library / "My Catalogue"
- Collection view of owned games with cover art, metadata, and per-game victory stats.
- **Wishlist** as a parallel list (`priority`: high/medium/low, notes).
- Per-entry attributes: `is_favorite`, `for_sale`, `personal_ranking`
  (high/medium/low), `played_dates`, `notes`.
- **Filtering** (`FilterSection`, `MultiSelectDropdown`) across game metadata
  (type, category, mechanic, player count, playtime, etc.).
- **Grid / list** view preference (persisted in `profiles.preferences.default_view`).
- Add games via **barcode scan**, **shared-catalog search**, or **manual entry**.
- Edit via `EditGameModal` / `EditWishlistModal`.
- **Future (from backlog):** move games between Collection ↔ Wishlist; normalize
  special characters in titles for display/sort/search.

### 5.3 Game Data, Barcode & BGG Enrichment
- Games live in a **shared catalog** (`shared_games`) keyed by barcode; user
  ownership is a join (`user_library`). This means barcode/BGG enrichment benefits
  all users.
- Barcode scanning in-browser via `html5-qrcode` (`BarcodeScanner`), supporting
  UPC-A (12) and EAN-13 (13) with prefix/strip variations on lookup.
- Lookups proxied through Edge Functions: `barcode-lookup`, `bgg-lookup`,
  `submit-barcode-mapping`. BGG enrichment fills name, year, cover, publisher,
  player count, playtime, age, type/category/mechanic/family, description.

### 5.4 Game Nite Tools
1. **Game Chooser** — randomized "spin the wheel" pick from a chosen set of games.
2. **First Player** — animated card-shuffle reveal that picks a starting player
   (rich CSS keyframe animation; honors `prefers-reduced-motion`).
3. **Turn Timer** — per-player turn countdown.
4. **Game Timer** — tracks a full session; timer state persists in profile
   preferences so it survives reloads.

Desktop shows tools as a tab bar; mobile shows a card grid that transitions into a
single-tool view.

### 5.5 Sessions & Victory Tracking
- Record `game_sessions` (date, duration, player count, notes) with per-player
  `session_victories` (winner flag, score, placement) via `VictoryLogModal`.
- Derived **victory stats** per game and per user: total sessions, total wins, win
  rate, best score, last played — surfaced on cards and the dashboard.

### 5.6 Friends & Shared Libraries
- Friend requests/relationships (`user_friends`: pending/accepted/blocked) via
  `FriendsManager`.
- Grant access to your collection (`shared_library_access`: `view` or `suggest`).
- Browse a friend's catalog (`SharedLibraryView`) and search across shared
  collections (`SearchSharedGamesModal`).

### 5.7 Dashboard
Composed of focused cards: `QuickStats`, `StatCard`, `MostPlayedGames`,
`PlayActivityChart`, `RecentlyAddedGames`, `VictoryStatsCard`, `QuickActions`.
Quick actions deep-link into other tabs (e.g. straight into a Game Nite tool).

### 5.8 Admin
`AdminPanel` for catalog/data management (admin-gated). Scope intentionally
loosely defined here — treat as an internal tool, not a user-facing surface.

---

## 6. Design System & Visual Guidelines

The product's aesthetic is a **vintage/botanical "library" feel**: warm parchment
backgrounds, serif display type, subtle paper/linen texture, thin rules, and flat
(borderless-elevation) surfaces. This section is the **canonical token reference
for both apps**.

### 6.1 Color Palette
Seven named ramps plus semantic aliases. Hex values are shared verbatim with the
Flutter app (`app_colors.dart`).

| Ramp | Role | Key values |
|------|------|-----------|
| **parchment** | Backgrounds / surfaces (cream) | `50 #FDF8F0` … `400 #C9AE78` |
| **forest** | Green — success / nature accent | `50 #EDF4ED` … `700 #0B2014` |
| **sky** | Teal — info / cool accent | `50 #EAF4F4` … `600 #0D3E3E` |
| **clay / terracotta** | Warm brand accent / error-adjacent | `50 #FDF2EC` … `600 #5E2509` |
| **wheat / gold** | Favorites / stars / warning | `50 #FEFAEE` … `600 #5C3E03` |
| **plum** | Shared / friends / "magic" accent | `50 #F5EEF8` … `600 #2E0D46` |
| **ink** | Text & dark neutrals | `50 #ECE9E3` … `600 #1A1610` |

**Semantic aliases (web, from `index.css`):**
- Backgrounds: base `parchment-50`, surface `parchment-100`, elevated `#fff`,
  overlay `rgba(26,22,16,0.55)`.
- Text: primary `ink-600`, secondary `ink-400`, muted `ink-200`, inverse `parchment-50`.
- Borders: subtle `parchment-200`, default `parchment-300`, strong `ink-200`.
- Brand: primary **`clay-400 #b85c28`**, hover `clay-500`, light `clay-100`.
- State: success `forest-400`, warning `wheat-400`, error `clay-500`, info `sky-400`.

> ⚠️ **Cross-platform brand divergence.** The **web** uses **clay/terracotta** as
> the primary brand color (nav indicators, mobile bottom nav `#b85c28`, avatar).
> The **Flutter** `ColorScheme.primary` is **forest green**. Same palette, different
> hero color. A deliberate decision is needed: pick one primary and align, or
> document this as an intentional per-surface choice. Until resolved, treat the
> shared *palette* as canonical and the *primary assignment* as platform-specific.

### 6.2 Typography
- **Display / headings:** Cormorant Garamond (serif), light/regular weights,
  `letter-spacing` ~0.5. Used for the wordmark, page titles, card titles.
- **Body / UI:** Jost (sans-serif), weights 300–600.
- **Mono / data:** DM Mono — numbers, timers, stat figures, code-like values.
- Buttons use Jost 500 with wide tracking (uppercase-ish label feel).

### 6.3 Shape, Texture & Elevation
- **Radius:** a flat **4px** everywhere (`sm`→`3xl` all collapse to 4px). Avoid
  pill/rounded shapes; the brand reads as crisp and printed.
- **Elevation:** prefer **borders over shadows**. Cards are white with a thin
  `parchment-200/300` border and little/no shadow.
- **Texture:** subtle SVG fractal-noise overlay on the page body (`opacity ~0.03`)
  and a `.linen-texture` utility for surfaces (`opacity ~0.05`). Texture should
  stay barely-perceptible.
- **Rules:** thin 1px hairlines (`.thin-rule`, `.rule-line`) in border colors to
  divide content, evoking ruled paper / ledger lines.

### 6.4 Motion
- Default to restraint; motion is reserved for moments of delight (First Player
  card shuffle, Game Chooser spin).
- **Always** provide a `prefers-reduced-motion` fallback (existing animations
  degrade to a simple fade). New animated features must do the same.

### 6.5 Iconography & Brand Marks
- Icon set: `lucide-react`, drawn at light stroke weight (~1.5) to match the
  delicate type.
- Custom **Meeple** mark used as the brand/profile glyph.
- The desktop "wooden disc" active-tab indicator is a signature flourish — a
  layered radial-gradient token by section color (dashboard=clay, library=forest,
  game-nite=sky, admin=plum). Reuse this section-color mapping when adding nav.

### 6.6 Accessibility
- Maintain WCAG AA contrast — be careful pairing mid-ramp colors on parchment.
- Respect reduced-motion (above).
- All interactive controls must be reachable and labeled; the noise/linen texture
  must never reduce legibility.

---

## 7. Technical Architecture (for context)

- **Stack:** React 18 + TypeScript, Vite, Tailwind (custom theme = design tokens),
  `lucide-react`, `sonner` (toasts), `html5-qrcode`.
- **State:** React context (`AuthContext`); data access in `src/lib/*`
  (`games`, `sessions`, `players`, `dashboard`, `bgg`, `auth`, `supabase`).
- **Backend:** Supabase. Edge Functions: `bgg-lookup`, `barcode-lookup`,
  `submit-barcode-mapping`, `delete-account`. Data model centers on a **shared
  game catalog** (`shared_games`) with per-user join tables.
- **Hosting:** Netlify (see `netlify.toml`, `NETLIFY_*` docs).
- **Privacy policy page:** `public/privacy/index.html`, deployed at `/privacy/`
  — a separately maintained copy of the same content as the Flutter app's
  in-app Privacy Policy screen. Both the App Store Connect and Google Play
  Console listings (mobile PRD §9) link to this URL, so it must be deployed
  and reachable without login before either store submission. Outstanding
  work before it's submission-ready is tracked in the cross-platform
  [`docs/PRIVACY_RELEASE_CHECKLIST.md`](./PRIVACY_RELEASE_CHECKLIST.md).

---

## 8. Guidelines for Future Features

When proposing or building anything new on the web app:

1. **Reuse tokens, don't invent.** Pull color/type/spacing from §6 (Tailwind
   theme). New colors require a new named ramp added in *both* apps.
2. **Keep it flat & papery.** 4px radius, borders over shadows, hairline rules,
   whisper-light texture. No drop-shadow-heavy "material" cards.
3. **Serif for voice, sans for function, mono for numbers.** Stats/timers/scores
   render in DM Mono.
4. **Earn your motion** and ship a reduced-motion fallback.
5. **Respect the shared data model.** New collection data should extend the
   existing join-table pattern (shared catalog + per-user rows) so enrichment
   benefits everyone and RLS stays simple.
6. **Mind parity.** Note in the PR whether a feature should also land on mobile
   (and vice-versa). Track parity gaps explicitly (see §9).
7. **Proxy third-party calls** through Edge Functions; never embed external API
   tokens in the client.

---

## 9. Web ↔ Mobile Parity Snapshot

Features present on **web** but not yet (or only partially) on **Flutter**:
- Admin panel.
- Friends + shared-library browsing UI (data layer exists on mobile; screens are
  stubbed).
- Full dashboard widget set.
- Session / victory logging UI breadth.

Features the **Flutter** app has that web does not:
- **Dice Roller** Game Nite tool (with shake-to-roll gesture).

These gaps are intentional-for-now but should be tracked so the two surfaces
converge over time. See the Flutter PRD §7 for the mobile-side view.

---

## 10. Open Questions
1. Final product name / wordmark / domain identity (blocks branding cleanup).
2. Primary brand color: align web (clay) and mobile (forest), or keep per-surface?
3. Is `for_sale` a future marketplace seed or just metadata? Define or remove.
4. Should the web app adopt a real URL router for deep-linking/sharing views?
5. Scope and access model for the Admin panel (internal-only vs. power-user).
