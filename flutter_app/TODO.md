# Flutter App — Future TODOs

Features to add later. Captured for planning; not yet scheduled.

## 1. My Games progressive controls and layout selector

Make browsing and scrolling the game collection the primary behavior on mobile
by reducing the controls that permanently occupy the My Library tab.

### Implementation

- [ ] Remove the list/grid toggle from the top-level My Games `AppBar`.
- [ ] Add a compact toolbar inside the My Library tab, immediately above the
  collection results.
- [ ] Add a two-part List / Grid split button to the in-tab toolbar, with a clear
  selected state, accessible labels/tooltips, and persisted selection.
- [ ] Add a `Find & refine` action that expands and collapses the search field,
  sort action, filter action, and Favorites / For Sale quick-filter chips.
- [ ] Default the refinement panel to collapsed, including when criteria from a
  prior interaction remain active.
- [ ] Preserve the search query, selected sort, and all filters when the panel is
  collapsed; show an active-state summary or count on `Find & refine` while the
  controls are hidden.
- [ ] Keep the collection scroll position stable when controls are expanded or
  collapsed and when switching between My Library, Wishlist, and Friends.
- [ ] Add widget tests covering control disclosure, state preservation, active
  indicators, split-button selection, and the absence of the layout toggle from
  the app bar.

### Acceptance criteria

- [ ] Opening My Library presents the collection as the dominant scroll surface;
  search, sort, filter, and quick-filter controls are not expanded by default.
- [ ] A user can reveal or hide all refinement controls without changing the
  current results.
- [ ] An active search query, non-default sort, or filter state remains
  discoverable while the controls are collapsed.
- [ ] List and Grid are selectable from a split button within the My Library tab
  content, never from the mobile page header.

## 2. Move games between Collection and Wishlist

Provide a means of moving games from the collection to the wishlist, and from
the wishlist to the collection.

- [ ] Move a game from Collection → Wishlist
- [ ] Move a game from Wishlist → Collection
- [ ] Surface the action in the library UI (e.g. swipe action or menu item)

## 3. Game Nite

A feature to create a "Game Nite" event where a user can:

- [ ] Define the people attending (ad-hoc participants)
- [ ] Invite other registered friends to the event in the app
- [ ] Pick the set of games that will be played
- [ ] Capture data and stats from the game nite (results, scores, winners, etc.)

## 4. Normalize game titles for special characters

Game titles can contain special characters (accents, smart quotes, em dashes,
trademark/ampersand symbols, etc.) that cause inconsistent display, sorting, and
search behavior.

- [ ] Normalize special characters in game titles for display and storage
- [ ] Ensure sorting handles accented/special characters correctly
- [ ] Ensure search matches regardless of special-character variations
