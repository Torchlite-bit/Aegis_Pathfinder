# TurtleGuide - ClassicAPI Edition

[![Octo WoW](https://img.shields.io/badge/Octo%20WoW-1.18.1-brightgreen.svg)](https://octowow.st/)
[![ClassicAPI](https://img.shields.io/badge/ClassicAPI-Required-purple.svg)](https://github.com/brues-code/ClassicAPI)

A leveling guide addon for Turtle WoW (1.12 client) based on [Joana's classic speedrun guides](https://www.joanasworld.com/), with support for Turtle WoW custom zones.

## Features

- **Optimized leveling routes** from Joana's 1-60 guides
- **RestedXP Speedrun routes** - Full 1-60 RXP speedrun-optimized routes for Alliance and Horde (excluded custom quests for now)
- **Race-based starting zones** - automatically selects your race's starting path
- **Shared optimized path** - all races merge into the same route after level 12
- **Dungeon Select Support (RXP & RXP Hardcore Guides Only)** - Toggle dungeon steps and their prerequisite setups on or off directly from the options panel (supports RFC, WC, DM, SFK, BFD, Stockades, Gnomer, RFK, SM, RFD, Ulda, ZF, Mara, ST, BRD)
- **Play Style & AH Filters (RXP & RXP Hardcore Guides Only)** - Customize your leveling path using the new Filters panel, toggling Solo/Group mode and Auction House steps. Switching to RestedXP automatically defaults to Group/AH enabled, while switching to RXP Hardcore defaults to Solo/AH disabled (configurable at any time).
- **Branch system** - temporarily switch to any zone guide, then return to the optimized path
- **Turtle WoW custom zones** - guides for all custom content available via branching
- **Smart quest tracking** - automatically detects completed objectives and advances
- **Waypoint addon of your choice** - TomTom, pfQuest, Cartographer or MetaMap, pointing at your current objective
- **pfQuest integration** - prerequisite detection and quest chain awareness
- **Manual navigation** - skip forward/backward through objectives with prev/next buttons
- **Improved Filter Parser** - Advanced logic for class/race filters supporting multiple targets (e.g., `Mage/Warlock`) and exclusions (e.g., `!Hunter`)

## Starting Zones

| Alliance | Starting Zone | Levels |
|----------|---------------|--------|
| Human | Elwynn Forest → Westfall | 1-10 → 10-12 |
| Dwarf/Gnome | Dun Morogh | 1-12 |
| Night Elf | Teldrassil | 1-12 |
| High Elf | Thalassian Highlands | 1-10 |

| Horde | Starting Zone | Levels |
|-------|---------------|--------|
| Orc/Troll | Durotar | 1-12 |
| Tauren | Mulgore | 1-12 |
| Undead | Tirisfal Glades | 1-12 |
| Goblin | Blackstone Island | 1-10 |

## Alliance Optimized Path (12-60)

All Alliance races follow this path after their starting zone:

| Levels | Zone |
|--------|------|
| 12-14 | Darkshore |
| 14-17 | Darkshore |
| 17-18 | Loch Modan |
| 18-20 | Redridge Mountains |
| 20-21 | Darkshore |
| 21-22 | Ashenvale |
| 22-23 | Stonetalon Mountains |
| 23-24 | Darkshore |
| 24-25 | Ashenvale |
| 25-27 | Wetlands |
| 27-28 | Redridge Mountains |
| 28-29 | Duskwood |
| 29-30 | Ashenvale |
| 30-30 | Wetlands |
| 30-31 | Hillsbrad Foothills |
| 31-31 | Alterac Mountains |
| 31-32 | Arathi Highlands |
| 32-32 | Stranglethorn Vale |
| 32-33 | Thousand Needles |
| 33-33 | Stonetalon Mountains |
| 33-35 | Desolace |
| 35-36 | Stranglethorn Vale |
| 36-37 | Alterac Mountains |
| 37-38 | Arathi Highlands |
| 38-38 | Dustwallow Marsh |
| 38-40 | Stranglethorn Vale |
| 40-41 | Badlands |
| 41-41 | Swamp of Sorrows |
| 41-42 | Desolace |
| 42-43 | Stranglethorn Vale |
| 43-43 | Tanaris |
| 43-45 | Feralas |
| 45-46 | Uldaman |
| 46-47 | The Hinterlands |
| 47-47 | Feralas |
| 47-48 | Tanaris |
| 48-48 | The Hinterlands |
| 48-49 | Stranglethorn Vale |
| 49-50 | Blasted Lands |
| 50-51 | Searing Gorge |
| 51-52 | Un'Goro Crater |
| 52-53 | Azshara |
| 53-54 | Felwood |
| 54-55 | Winterspring |
| 55-56 | Burning Steppes |
| 56-57 | Silithus |
| 57-58 | Western Plaguelands |
| 58-59 | Eastern Plaguelands |
| 59-60 | Winterspring |

## Horde Optimized Path (12-60)

All Horde races follow this path after their starting zone:

| Levels | Zone |
|--------|------|
| 12-15 | The Barrens |
| 15-16 | Stonetalon Mountains |
| 16-18 | The Barrens |
| 18-20 | The Barrens |
| 20-21 | Stonetalon Mountains |
| 21-21 | Ashenvale |
| 22-23 | Southern Barrens |
| 23-25 | Stonetalon Mountains |
| 25-25 | Southern Barrens |
| 25-26 | Thousand Needles |
| 26-27 | Ashenvale |
| 27-27 | Stonetalon Mountains |
| 27-29 | Thousand Needles |
| 29-30 | Hillsbrad Foothills |
| 30-30 | Alterac Mountains |
| 30-30 | Arathi Highlands |
| 30-31 | Stranglethorn Vale |
| 31-32 | Thousand Needles |
| 32-34 | Desolace |
| 34-36 | Stranglethorn Vale |
| 36-37 | Arathi Highlands |
| 37-37 | Alterac Mountains |
| 37-38 | Thousand Needles |
| 38-38 | Dustwallow Marsh |
| 38-40 | Stranglethorn Vale |
| 40-41 | Badlands |
| 41-42 | Swamp of Sorrows |
| 42-43 | Stranglethorn Vale |
| 43-43 | Desolace |
| 43-44 | Dustwallow Marsh |
| 44-45 | Tanaris |
| 45-46 | Feralas |
| 46-46 | Azshara |
| 46-47 | The Hinterlands |
| 47-47 | Stranglethorn Vale |
| 47-48 | Searing Gorge |
| 48-48 | Swamp of Sorrows |
| 48-49 | Feralas |
| 49-50 | Tanaris |
| 50-50 | Azshara |
| 50-51 | The Hinterlands |
| 51-51 | Blasted Lands |
| 51-52 | Un'Goro Crater |
| 52-53 | Burning Steppes |
| 53-54 | Azshara |
| 54-54 | Felwood |
| 54-55 | Winterspring |
| 55-55 | Felwood |
| 55-55 | Silithus |
| 55-56 | Western Plaguelands |
| 56-57 | Eastern Plaguelands |
| 57-58 | Western Plaguelands |
| 58-60 | Winterspring |

## Branch System

Use the **Branch** feature to temporarily switch to any zone guide:

1. Click the **Branch** button in the objectives panel
2. Select a zone guide from the categorized list
3. Complete the zone (or as much as you want)
4. Click **Return to Main** to go back to the optimized path at your current level

**Categories:**
- **Optimized Path** - Joana's guide zones
- **RestedXP Speedrun** - RXP speedrun routes (Alliance and Horde)
- **TurtleWoW Zones** - Custom Turtle WoW content
- **Zone Guides** - Standard vanilla zone guides

## Turtle WoW Custom Zones

Available via branching:

| Zone | Level | Faction |
|------|-------|---------|
| Thalassian Highlands | 1-10 | Alliance |
| Blackstone Island | 1-10 | Horde |
| Balor | 29-34 | Both |
| Grim Reaches | 33-38 | Both |
| Gilneas | 39-46 | Both |
| Icepoint Rock | 40-50 | Both |
| Lapidis Isle | 48-53 | Alliance |
| Gillijim's Isle | 48-53 | Horde |
| Tel'Abim | 54-60 | Both |

## RestedXP (RXP) Speedrun Routes

In addition to the original optimized leveling paths, this fork integrates full RestedXP (RXP) speedrun routes:

- **RestedXP Route Pack**:
  - **Alliance (1-60)**: Custom starting routes for Northshire (Human), Coldridge Valley (Dwarf/Gnome), and Shadowglen (Night Elf), merging into a fully optimized 13-60 speedrun route.
  - **Horde (1-60)**: Custom starting routes for Durotar (Orc/Troll), Mulgore (Tauren), and Tirisfal Glades (Undead), merging into a fully optimized 12-60 speedrun route.

To switch route packs, click the status bar, select **Config**, click the **Route** button, and choose your preferred route pack (Optimized Path, RestedXP).

## Dungeon Selection System (RXP Guides Only)

This fork introduces dungeon selection support integrated directly with the RestedXP (RXP) routes. You can toggle specific dungeons on or off from the options menu:

1. Open the options panel with `/vg` or by clicking the status bar and selecting **Config**.
2. Click the **Dungeons** button next to the Route selector.
3. Toggle the dungeons you plan to run (e.g., Deadmines, Scarlet Monastery, Wailing Caverns).
4. TurtleGuide will automatically recalculate the active guide to include or exclude the dungeon objectives and their prerequisite setups.

**Key Features:**
- **Dynamic Filtering**: Dungeon steps tagged with `|D|DUNGEONCODE|` are only shown if that dungeon is enabled.
- **Mandatory Override**: Opting into a dungeon automatically forces all associated setup and prerequisite quest steps to be shown as mandatory (ignoring any `#optional` tags in the source guide).
- **Negated Dungeons**: Supports negation tags (e.g., `!DM`) to only show a step if a dungeon is *not* being run.

**Supported Dungeons:**
- RFC (Ragefire Chasm)
- WC (Wailing Caverns)
- DM (Deadmines)
- SFK (Shadowfang Keep)
- BFD (Blackfathom Deeps)
- STOCKADES (The Stockade)
- GNOMER (Gnomeregan)
- RFK (Razorfen Kraul)
- SM (Scarlet Monastery)
- RFD (Razorfen Downs)
- ULDA (Uldaman)
- ZF (Zul'Farrak)
- MARA (Maraudon)
- ST (Sunken Temple)
- BRD (Blackrock Depths)

## ClassicAPI Integration

TurtleGuide is built on [ClassicAPI](https://github.com/brues-code/ClassicAPI),
a client DLL that backports modern WoW API to the 1.12 client. The addon
checks `CLASSIC_API_VERSION` on load and **refuses to run below v1.5.9** —
quest tracking and automation are built directly on these primitives instead
of chat-message parsing and name matching.

### Synthesized events

| Event | Used for |
|-------|----------|
| `QUEST_ACCEPTED(questLogIndex, questID)` | Accept detection by QID instead of parsing the "Quest accepted:" system message |
| `QUEST_TURNED_IN(questID, xpReward, moneyReward)` | Server-confirmed turn-in detection; marks the guide step and records completion by QID |
| `QUEST_REMOVED(questID)` | Advances the guide the moment a turned-in quest leaves the log; a removal with no turn-in confirmation is an abandon, which rewinds to the quest's accept step |
| `HEARTHSTONE_BOUND` | SETHEARTH step completion from the bind-point packet instead of chat parsing |
| `BAG_UPDATE_DELAYED` | One batched bag scan per loot/mail/trade/vendor event for `\|L\|` item-count tracking |

### API namespaces

| API | Used for |
|-----|----------|
| `C_QuestLog.GetQuestIDForLogIndex` | QID-authoritative quest log lookups — same-named chain parts can never satisfy the wrong step |
| `C_QuestLog.IsOnQuest` | Prerequisite checks and turn-in verification |
| `C_QuestLog.GetTitleForQuestID` | Quest names for steps and messages without a log scan |
| `C_QuestLog.IsQuestDataCachedByID` / `RequestLoadQuestByID` | Warming the quest cache for every guide QID at load, so later title lookups are synchronous |
| `C_GossipInfo.GetAvailableQuests` / `GetActiveQuests` / `SelectAvailableQuest` / `SelectActiveQuest` | Quest automation at gossip NPCs — QID-matched auto-accept and auto-turn-in (gated on `isComplete`) |
| `C_Item.GetItemCount` | `\|L\|` collect-step quotas checked against live bag counts |
| `C_Item.GetItemNameByID` / `GetItemIconByID` | Step-name enrichment and the use-item button icon |
| `C_Item.IsItemDataCachedByID` / `RequestLoadItemDataByID` | Warming the item cache for guide `\|L\|`/`\|U\|` items at load |
| `C_Container.GetContainerItemID` | Bag-slot resolution for `\|U\|` use-item steps |
| `C_Timer.After` / `NewTicker` | Arrival-detection ticker, deferred completion checks, abandon grace period |
| `GameTooltip:SetItemByID` | Use-item button tooltip when the item isn't in the bags yet |

## Recommended Addons

| Addon | Description | Link |
|-------|-------------|------|
| **TomTom** | Waypoint arrow navigation | [GitHub](https://github.com/sweetgiorni/TomTom) |
| **pfQuest-turtle** | Quest database with map markers | [GitHub](https://github.com/shagu/pfQuest-turtle) |

## How It Works

### The Status Bar

When you log in, a small status bar appears near your quest tracker showing your current objective:

```
[✓] [<] [icon] [15/120] Kill 8 Grell Earring [?] [>]
 │    │    │       │              │            │   │
 │    │    │       │              │            │   └─ Next: Skip to next objective
 │    │    │       │              │            └─ [?] indicates there's a note (hover for details)
 │    │    │       │              └─ The objective description
 │    │    │       └─ Step number / Total steps in current guide
 │    │    └─ Icon shows objective type (see below)
 │    └─ Prev: Go back to previous objective
 └─ Checkbox: Mark complete when checked
```

**Click the status bar** to open the full objectives panel with more details.

### Reading Objectives

Each objective has an **action type** shown by its icon:

| Icon | Code | Action | Meaning |
|------|------|--------|---------|
| 📜 | A | ACCEPT | Pick up a quest from an NPC |
| ⚔️ | C | COMPLETE | Do the quest objectives (kill, collect, etc.) |
| 📜 | T | TURNIN | Turn in a completed quest |
| 🏃 | R | RUN | Travel to a location |
| 🦅 | F | FLY | Take a flight path |
| 🦅 | f | GETFLIGHTPOINT | Discover a new flight path |
| 🏠 | H | HEARTH | Use your hearthstone |
| 🏠 | h | SETHEARTH | Set your hearthstone location |
| ⛵ | b | BOAT | Take a boat or zeppelin |
| 💀 | K | KILL | Grind mobs (not for a quest) |
| 📝 | N | NOTE | Important information or tip |
| 🛒 | B | BUY | Purchase items from a vendor |
| 📦 | U | USE | Use an item |
| 📖 | t | TRAIN | Visit a class trainer |

**Objective tags** in the panel:
- **(Optional)** - Can be skipped without breaking the guide
- **[?]** - Has additional notes (hover to see)
- Orange text on the right shows quest progress or notes

### Navigating the Guide

**Automatic progression:**
- The addon tracks your quest log and automatically advances when you accept, complete, or turn in quests
- Travel objectives (RUN, FLY, BOAT) auto-complete when you arrive at the destination

**Manual navigation:**
- **< / >** buttons: Move backward/forward one step
- **>>** button: Mark current step complete and advance
- **Checkboxes**: Click to manually mark any step complete/incomplete
- `/vg next` / `/vg prev`: Keyboard shortcuts for navigation
- `/vg goto 50`: Jump directly to step 50

**Smart skip on guide load:**
- When loading a guide, TurtleGuide scans your quest log and automatically skips to where you left off
- If you have quests in progress, it finds the right step

### The Branch System

The **Branch** feature lets you temporarily leave the optimized path to do other content:

1. Click **Branch** in the objectives panel
2. Select any zone guide (TurtleWoW zones, vanilla zones, etc.)
3. Complete as much as you want
4. Click **Return Main** to go back

**When you return:**
- TurtleGuide finds the appropriate step in the optimized path based on your level
- Your progress in the branch is saved if you want to return later
- A green `[Branch]` indicator shows when you're off the main path

**Example workflow:**
```
Level 35, doing Joana's route in Stranglethorn Vale
  ↓
Branch to Gilneas (TurtleWoW zone) for custom content
  ↓
Do some quests, get to level 37
  ↓
Click "Return Main" → Resumes at level 37 section of optimized path
```

### Waypoints & Map Integration

Waypoints for the current objective are handed to whichever waypoint addon you
use. Pick one with the **Waypoints** button in the options panel, or leave it on
**Auto** to take the first one that is loaded:

| Provider | Notes |
|----------|-------|
| **TomTom** | Crazy-arrow waypoint; the only provider that can point at a target in another zone |
| **pfQuest** | Map/minimap pin plus pfQuest's own route arrow, pinned to the guide step; current zone only |
| **Cartographer** | Waypoint note |
| **MetaMap BWP** / **MetaMap** | BWP arrow, or a plain map note |

Regardless of provider:
- Coordinates from the guide are automatically mapped
- Travel objectives auto-complete when you arrive

With **pfQuest** installed (as a database, whichever provider is active):
- Quest giver/turn-in locations are automatically looked up
- Prerequisite chains are detected to warn about missing requirements

## Installation

1. Install [ClassicAPI](https://github.com/brues-code/ClassicAPI) v1.5.9 or
   newer (required)
2. [Download the latest zip](https://github.com/brues-code/VanillaGuide-Plus/releases/latest)
3. Place the `TurtleGuide` folder in `World of Warcraft/Interface/AddOns/`
4. Restart WoW

## Commands

| Command | Description |
|---------|-------------|
| `/vg` | Open options panel |
| `/vg next` | Skip to next objective |
| `/vg prev` | Go back to previous objective |
| `/vg goto <n>` | Jump to step number |
| `/vg reset` | Reset current guide progress |

## Credits

- Leveling routes: [Joana's Vanilla WoW Guides](https://www.joanasworld.com/)
- Original TourGuide addon: Tekkub
- [VanillaGuide](https://github.com/isalcedo/VanillaGuide) addon structure
- Turtle WoW content: Turtle WoW team
- pfQuest: Shagu
