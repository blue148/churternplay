# Ad Placement Recommendation

## Goal

Introduce contextual ads (game companies, events, publishers, etc.) in the
Dashboard, Game Nite (+ its tools menu), My Library, and Wishlist without
degrading the experience. This document is a placement spec, not an
implementation — it's detailed enough to build from directly when ad
infrastructure is added.

## Principles

1. **In-flow, never anchored.** No top- or bottom-anchored/sticky ad bars
   anywhere. Every ad slot is a regular item in the scrollable content —
   it scrolls with the list/grid and disappears when scrolled past, exactly
   like any other row or card.
2. **Native, not a banner.** Ad slots are styled to match the surrounding
   card/row family (same corner radius, padding, typography scale, and
   color tokens as real content) so they read as "one more card," not a
   foreign injected unit.
3. **Sparse by default.** See [Cadence rules](#cadence-rules) below.
   Short, non-scrolling sections get at most one ad slot for the whole
   screen; nothing is ever shown when content is too sparse to support it.
4. **Never adjacent to interactive/destructive controls.** No ad slot sits
   directly next to a tappable tool row, a delete/swipe action, or any
   control where an accidental tap could be mistaken for the ad being part
   of the UI.
5. **Clearly labeled.** Every ad slot carries a small, legible "Sponsored"
   (or "Ad") tag. This isn't optional polish — it's required by Apple App
   Store Review Guideline 3.2.2, Google Play's ads policy, and the
   disclosure terms of every major ad network (AdMob, Meta Audience
   Network, Mintegral, etc.).
6. **Ad-network-agnostic.** Placement and rendering are decoupled from any
   specific SDK via a common data shape (below), so swapping or mediating
   between ad networks later doesn't require touching any screen's layout
   code.

## The adapter seam: `NativeAdContent`

Nearly every native-ad SDK (AdMob `NativeAd`, Meta Audience Network
`NativeAdView`, Mintegral, etc.) exposes the same underlying asset set. A
single data model absorbs that overlap so the rendering widget never needs
to know which network filled it:

```dart
class NativeAdContent {
  final String headline;
  final String? body;
  final String? iconAsset;      // small square icon/logo
  final String? mediaAsset;     // larger media/hero image, optional
  final String ctaLabel;        // e.g. "Learn More", "Install"
  final String? advertiserName;
  final String sponsoredLabel;  // defaults to "Sponsored"
}
```

Whichever SDK is chosen later, its adapter's only job is to populate this
object; the `AdSlot` widget (below) never changes.

## Recommended component shape

- **`AdSlot` widget** (`lib/core/ads/ad_slot.dart`), parameterized by an
  `AdSlotFormat`:
  - `listRow` — mirrors the list-row card family already used by
    `GameCard`'s `_ListCard` and Wishlist's `_WishlistItemRow`: a 72×72
    leading image/icon placeholder, headline + body text, small CTA button.
    Matches their row height and spacing so it doesn't disrupt scroll
    rhythm.
  - `gridRow` — a **full-width** row (spans all grid columns), horizontal
    icon + headline + CTA layout. A single grid *cell* is too narrow for
    native ad copy at the library grid's current `childAspectRatio: 0.55`,
    so ad slots in grid contexts break out to a full row rather than
    occupying one tile.
  - `sectionCard` — mirrors Dashboard's section chrome (`_SectionHeader`
    spacing, card padding) for single-slot placements on non-list screens.
  - All formats show the `sponsoredLabel` in a small tag using the existing
    `AppColors` palette (e.g. `parchment200`/`ink200` neutrals) so it sits
    visually inside the app's own theme rather than looking like an
    imported ad unit.
- **`ad_placement.dart`** — shared cadence helpers so insertion logic isn't
  duplicated per screen:
  - `shouldInsertAdAfterListIndex(int index, {required int itemCount})`
  - `gridAdRowIndices(int itemCount, {required int crossAxisCount})` —
    returns which grid *row numbers* should be ad rows.

## Cadence rules

| Context | Rule |
|---|---|
| List rows (Library list, Wishlist) | 1 ad after every **8 real items**; never before the first 6 items; no ad at all below 6 items total. |
| Grid tiles (Library grid) | 1 full-width ad row after every **3 grid rows** (every 9 tiles at the current 3-column layout); same minimum-item guard. |
| Short/non-scrolling screens (Dashboard, Game Nite menu) | Exactly **one** ad slot for the whole screen. Never inserted between two functional/interactive rows. |

This is intentionally conservative — it favors trust and retention over ad
density. It can be tightened later per real engagement/revenue data without
changing the underlying component.

## Per-screen placement

### 1. Dashboard — `lib/features/dashboard/dashboard_screen.dart`

The screen is a single `ListView` of four short sections: `_QuickActions`
(3-card row), `_MostPlayed` (horizontal scroll), `_CollectionStats` (2×2
grid), `_RecentlyAdded` (flat row list). None is a long scroll, so there's
no interleaving target — one slot for the whole screen.

**Placement:** one `AdSlot(format: sectionCard)` inserted as its own
section between `_CollectionStats` and `_RecentlyAdded`, using the same
`SizedBox(height: 24)` gap the other sections already use. It reads as a
fifth section rather than an interruption, and sits mid-scroll (not at the
very top where it'd be the first thing seen, not at the bottom where a user
might never scroll to it).

### 2. Game Nite — `lib/features/game_nite/game_nite_screen.dart`

The landing menu (`GameNiteScreen`, lines 26-80) is a `ListView` of 5
`_ToolRow` entries (Game Chooser, First Player, Turn Timer, Game Timer,
Dice Roller), each a `ListTile` + `Divider(height: 1, indent: 84)`. Five
tappable rows is too short and too interactive to interleave an ad between
any two of them — risk of accidental taps and a menu that reads as having
6 "tools" instead of 5.

**Placement:** one `AdSlot(format: listRow)` appended **after** the Dice
Roller row, separated by the same divider style, clearly labeled
"Sponsored" so it's unambiguous it isn't a 6th tool.

**Future extension (out of scope for this pass):** individual tool
result/output screens are natural contextual pause points — e.g. after
Game Chooser reveals a pick, or after First Player reveals a winner — and
would pair well with contextual ads (related games, local game-night
events). Worth a follow-up recommendation once those flows are prioritized.

### 3. My Library — `lib/features/library/library_screen.dart` (`_CatalogueTab`)

Both layouts read from the same flat, already-filtered/sorted `items` list
(no section headers to work around).

- **List mode** (`ListView.separated`, lines 332-341): route the
  `itemCount`/`itemBuilder` through `shouldInsertAdAfterListIndex`,
  inserting `AdSlot(format: listRow)` at computed positions in place of a
  `GameCard`. Same `padding: EdgeInsets.fromLTRB(16, 4, 16, 96)` and 6px
  separator rhythm as today.
- **Grid mode** (`GridView.builder`, lines 344-357): the current
  `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, ...,
  childAspectRatio: 0.55)` gives every cell the same size, which can't host
  a full-width ad row directly. Recommend converting this branch to a
  `CustomScrollView` with a `SliverMainAxisGroup` alternating `SliverGrid`
  chunks (same delegate/spacing as today) and
  `SliverToBoxAdapter(child: AdSlot(format: gridRow))` breaks, sized via
  `gridAdRowIndices`. This preserves the existing `RefreshIndicator`
  wrapping and outer padding unchanged.

### 4. Wishlist — `lib/features/library/library_screen.dart` (`_WishlistTab`)

List-only (no grid mode). Same treatment as Library's list mode: the
`ListView.separated` at lines 708-717 (rendering `_WishlistItemRow`, 72×72
thumbnail + text + `PopupMenuButton`) routes through
`shouldInsertAdAfterListIndex`, inserting `AdSlot(format: listRow)` at
computed positions. Because each row carries a `PopupMenuButton` (edit/
delete), the cadence rule matters doubly here — an ad slot should never
land immediately before/after a row a user is mid-interaction with, which
the index-based (not scroll-position-based) insertion naturally avoids.

## Summary table

| Screen | Layout | Ad format | Cadence |
|---|---|---|---|
| Dashboard | Sectioned `ListView` | `sectionCard` | 1 per screen |
| Game Nite menu | 5-row `ListView` | `listRow` | 1 per screen, after last tool |
| My Library — list | `ListView.separated` | `listRow` | every 8 items (min 6 items to show any) |
| My Library — grid | `GridView` (3 cols) | `gridRow` (full width) | every 3 rows (min 6 items to show any) |
| Wishlist | `ListView.separated` | `listRow` | every 8 items (min 6 items to show any) |
