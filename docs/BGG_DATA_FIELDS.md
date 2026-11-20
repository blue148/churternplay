# BGG Data Fields Explained

## Overview

The BGG (BoardGameGeek) XML API provides rich metadata about board games. Here's what each field represents and how they're used in your app.

## Data Fields Returned

### Basic Information

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `name` | string | Primary game name | "Gloomhaven" |
| `year` | number | Year published | 2017 |
| `publisher` | string | Primary publisher | "Cephalofair Games" |
| `designers` | string[] | Designers (`boardgamedesigner` links; "(Uncredited)" dropped). Saved to `shared_games.designers` | ["Isaac Childres"] |
| `cover_image` | string | URL to game cover art | "https://cf.geekdo-images.com/..." |
| `bgg_id` | number | BoardGameGeek ID | 174430 |

### Player Information

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `min_players` | number | Minimum players | 1 |
| `max_players` | number | Maximum players | 4 |
| `playtime_minutes` | number | Average playtime | 120 |
| `min_age` | number | Recommended minimum age | 14 |

### Classification Arrays

#### `game_category` (Categories)
**What BGG calls it:** `boardgamecategory`

**What it represents:** The **theme** or **setting** of the game

**Examples:**
- "Fantasy"
- "Science Fiction"
- "Medieval"
- "Adventure"
- "Economic"
- "Fighting"
- "Horror"
- "Party Game"

**Use case:** Filter games by theme (e.g., "Show me all fantasy games")

---

#### `game_mechanism` (Mechanics)
**What BGG calls it:** `boardgamemechanic`

**What it represents:** The **gameplay mechanics** - how the game actually plays

**Examples:**
- "Hand Management"
- "Deck Building"
- "Worker Placement"
- "Dice Rolling"
- "Area Control"
- "Set Collection"
- "Cooperative Play"
- "Grid Movement"

**Use case:** Find games with similar gameplay (e.g., "Show me all deck-building games")

---

#### `game_type` (Families)
**What BGG calls it:** `boardgamefamily`

**What it represents:** Broader **game series** or **classifications**

**Examples:**
- "Thematic Games"
- "Strategy Games"
- "Catan"
- "Ticket to Ride"
- "Zombicide"
- "Crowdfunding: Kickstarter"
- "Components: Miniatures"

**Use case:** Group games by series or broad type (e.g., "All Catan expansions")

---

### Additional Fields

| Field | Type | Description |
|-------|------|-------------|
| `description` | string | Full game description from BGG |

## Quick Reference: The Three Arrays

Think of them this way:

```
🎲 Game: "Pandemic"

game_category (Theme):
  - Medical
  - Science Fiction
  - Racing

game_mechanism (How to Play):
  - Cooperative Play
  - Hand Management
  - Point to Point Movement
  - Set Collection
  - Trading

game_type (Broader Classification):
  - Cooperative Games
  - Medical: Diseases
  - Pandemic
```

## Database Schema

These fields map to your Supabase `shared_games` table:

```sql
CREATE TABLE shared_games (
  ...
  game_type text[],        -- Families/series
  game_category text[],    -- Themes
  game_mechanism text[],   -- Gameplay mechanics
  ...
);
```

## UI Display Suggestions

### Game Card Display
```tsx
{/* Show category as theme tags */}
{game.game_category?.map(cat => (
  <span className="badge badge-theme">{cat}</span>
))}

{/* Show mechanics as gameplay tags */}
{game.game_mechanism?.map(mech => (
  <span className="badge badge-mechanic">{mech}</span>
))}
```

### Filtering
- **Browse by Theme** → Use `game_category`
- **Browse by Mechanic** → Use `game_mechanism`
- **Browse by Series** → Use `game_type`

## Example Response

Here's what a full BGG lookup returns for "Wingspan":

```json
{
  "name": "Wingspan",
  "year": 2019,
  "bgg_id": 266192,
  "publisher": "Stonemaier Games",
  "cover_image": "https://cf.geekdo-images.com/yLZJCVLlIx4c7eJEWUNJ7w__original/img/...",
  "min_players": 1,
  "max_players": 5,
  "playtime_minutes": 70,
  "min_age": 10,

  "game_category": [
    "Animals",
    "Card Game",
    "Educational"
  ],

  "game_mechanism": [
    "Card Drafting",
    "Dice Rolling",
    "End Game Bonuses",
    "Hand Management",
    "Set Collection"
  ],

  "game_type": [
    "Animals: Birds",
    "Tableau Building Games",
    "Components: Cards"
  ],

  "description": "Wingspan is a competitive, medium-weight, card-driven..."
}
```

## Using in Your App

### Barcode Scanning
When a user scans a barcode, all these fields are automatically fetched and stored:

```typescript
const gameData = await lookupBarcodeWithBgg(barcode);
// Returns full data including categories, mechanics, and types
```

### Filtering Example
```typescript
// Filter by mechanic
const deckBuilders = library.filter(entry =>
  entry.game.game_mechanism?.includes('Deck Building')
);

// Filter by category
const fantasyGames = library.filter(entry =>
  entry.game.game_category?.includes('Fantasy')
);
```

## Rate Limiting Considerations

BGG's XML API has rate limits. Our Edge Function helps by:
- Centralizing all requests
- Making it easy to add caching later
- Tracking usage in one place

Consider adding database caching:
1. Check if game exists with BGG ID
2. If yes, return cached data
3. If no, call BGG API and cache result
4. Only re-fetch if data is old (e.g., > 30 days)

## Reference

- **BGG XML API Docs:** https://boardgamegeek.com/wiki/page/BGG_XML_API2
- **Your Edge Function:** `/supabase/functions/bgg-lookup/index.ts`
- **Client Helper:** `/src/lib/bgg.ts`
