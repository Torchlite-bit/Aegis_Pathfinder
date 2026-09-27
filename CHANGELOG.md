# Changelog

All notable changes to **Aegis: Pathfinder**.

Format loosely follows [Keep a Changelog](https://keepachangelog.com/).
The version here matches `## Version` in `Aegis_Pathfinder.toc` and the number
in the load message and the options window's About page — quote it in bug
reports.

> ⚠️ Releases marked **restart** add or remove a `.lua` file or a texture. WoW
> 1.12 reads the file list at startup, so `/reload` won't pick them up — you
> need to fully restart the client. Everything else is `/reload`-safe.

> **One push, one MINOR.** A body of work that lands in one merge takes a
> single MINOR bump, and every change inside it — each phase, each fix found
> along the way — is a PATCH under it. The MINOR moves again at the next body
> of work, not at the next feature within this one.

---

## [0.6.3]

### Added
- **Right-click the step arrows to jump to your place.** Clicked round the
  guide to look back or ahead? Right-click the arrow pointing where you were
  and you're there, with every tick the arrows changed on the way put back
  (and any quest you finished meanwhile kept). Without clicking round, a
  right-click goes to where the guide would open — the quest your log shows
  work at, else the first step not done. The arrows' tooltips say so.

---

## [0.6.2]

### Added
- **The Gear finder looks in Turtle WoW's own dungeons and raids**: Dragonmaw
  Retreat, Crescent Grove, Stormwrought Ruins, Gilneas City, Hateforge Quarry,
  Karazhan Crypt, The Black Morass, Stormwind Vault, and the Emerald Sanctum
  and Tower of Karazhan raids — their bosses' drops and how often, from
  pfQuest-turtle, at the levels their creatures are. The game is asked what
  Turtle's own items are the first time, so the list can take a few seconds
  to fill in, once. Walking into one names its upgrades, as for any dungeon.

---

## [0.6.1] — restart

### Changed
- **The minimap button is the Aegis: Pathfinder logo**, in its own colours,
  at the stock minimap buttons' size, with the theme's accent ring round it on
  hover. It replaces the green shield. The logo is a new texture file, so
  restart the client rather than `/reload`.
- **The README matches the rest of the Aegis series**: badges for the servers
  and what the addon needs, the logo, a Discord link, and a section a feature.

---

## [0.6.0]

### Changed
- **The stat weights are a page of the options now, not a window of their
  own**: **Item Score**, listed under **Gear**, laid out as Zygor's is. Your
  spec, *Show all stats*, and every weight down the left with a box each;
  beside them the OctoPawn string with **Import** and **Export**; **Reset**
  under them. `/apg gear` and **Stat weights** on the Gear page turn to it.

---

## [0.5.0]

### Changed
- **The options window has pages**, with the categories down the left as
  Zygor's options have them: Route, Dungeons, Filters, Appearance, Gear,
  Behaviour, Navigation, Maintenance, About. One page at a time, scrolling
  only when it is taller than the window; the **Credits** button is on About.
- **The README is short**: what you get, installing, the main commands. Every
  feature in detail is in [docs/FEATURES.md](docs/FEATURES.md).

### Fixed
- **A new character opened at the end of the guide** — far into the High Elf
  quests, say — with every step before it counted as done. Where a guide
  opens kept the last step not done rather than the first. It now opens at
  the step your quest log shows work at, else the first step not done.
  Progress was always saved per character; this only made a fresh one look
  far along.
- The guide no longer paints a hand-in further down as done because you have
  not picked that quest up yet.
- Hovering **Solo Self-Found** raised an error (`Theme.lua:1270: bad argument
  #1 to 'ipairs'`).
- `/apg trackquests` and `/apg skipfollowups` raised an error while the
  options window was open.
- The **Arrow** list stayed on screen when the options window closed with it
  open.

---

## [0.4.2] — restart

### Added
- **Gear finder**, the third part of Gear (`/apg finder`, or **Gear finder**
  in the options): for each slot, the best few upgrades that drop in the
  dungeons you run, with who drops them, where, and how often. It looks in
  the dungeons starting no more than three levels above you, on your side,
  ticked under **Dungeons** — and in raids if you ask. Walking into a dungeon
  names its upgrades in chat. The loot is the CMaNGOS database's, for every
  vanilla dungeon and raid — bosses a script summons (Ragnaros, Nefarian,
  Darkmaster Gandling, the Edge of Madness) included; Turtle WoW's own
  dungeons are not in it yet.

### Changed
- **Weapon skills are out of the item score** (+Swords, +Daggers and the
  rest): the Gear window lists the stats Zygor's does.

---

## [0.4.1] — restart

### Added
- **Gear Advisor**, the second part of Gear, switched under **Gear** in the
  options:
  - Upgrades you pick up pop up with **Equip** or **Decline**; declined items
    are not offered again until you clear the list. In a fight, Equip waits.
  - **Equip upgrades for me** (off until you turn it on) never equips an item
    that would bind to you; that one still asks.
  - The best quest reward is marked — the biggest upgrade, or the one a vendor
    pays most for — and, with **pick it for me** on and quests turning in by
    themselves, taken. Sell prices come from the CMaNGOS database.
  - Upgrades are bordered in the default bags.
  - Off, or off at level 60, when you want.

### Changed
- **Auction House tags go on the step that sends you there, not on the
  quest.** A quest you can do by fishing, farming a drop or finding a vendor
  now stays with Auction House steps off: *The Family and the Fishing Pole*,
  *Catch of the Day*, *Fish in a Bucket*, *Look To The Stars*. Notes about
  farming (Green Hills pages to keep, the Treasure Map, Morrowgrain, Silk
  Cloth) are no longer hidden either. Quests that need a crafted item —
  *Ineptitude + Chemicals = Fun*, *Chasing A-Me 01*, *The Blazno Touch* and the
  Tel'Abim alchemy, engineering and enchanting quests — still are.

---

## [0.4.0] — restart

### Added
- **Item score**, the first part of Gear. Every item's tooltip says what it
  is worth to your spec and how it compares with what you wear: green `+12%`
  for an upgrade, red for worse, *empty slot*, or *not for you* for what you
  cannot use; an item you are too low for says the level it becomes one at.
  - Stats are read off the tooltip, weighted for your class and spec, with
    soft caps. Rings, trinkets and one-handers are weighed against the slot
    they would replace, two-handers against both hands; enchants are left out.
  - Your spec follows your talents, or the one you pick; the levelling spec
    until you have talents.
  - The weights are OctoPawn's (MIT) for every class and spec. The **Gear**
    window (`/apg gear`, or **Stat weights** in the options) lets you change
    any of them, reset them, and export or import them in OctoPawn's format.
  - A switch in the options takes the line off tooltips.

---

## [0.3.1]

### Added
- **Solo Self-Found mode**, as RestedXP has: for a character that never
  trades and never uses the Auction House, every step that needs either is
  left out, and the Auction House switch is held off while it is on. A switch
  under **Filters**, a choice in the first-time setup, and `/apg ssf`. Guide
  authors can mark a step that needs another player with `|TRADE|`.

### Changed
- **Some filter tags come off again, on a second look:**
  - The paladin *Tome of Divinity* and the druid *Gathering the Cure* chains
    no longer count as Auction House quests. Linen Cloth drops from
    humanoids; Earthroot, Lunar Fungus and Kodo Horns are gathered or drop.
  - Westfall's trip to Stormwind for *Shipment to Stormwind* is no longer a
    group step. Its note mentions Hogger, but the step isn't his.

---

## [0.3.0]

### Added
- **Mining says where to mine.** Each step of the Mining route, for your
  faction: where to mine the ore a smelting step uses (Copper, Tin, Silver,
  Iron, Gold, Truesilver, Thorium), and, for the stretches that level by
  mining alone, the zones with most of the veins that can still raise your
  skill. From pfQuest's ore nodes and the CMaNGOS database's vein loot.

### Changed
- **The Auction House, Group and Dungeon switches now cover the Optimized and
  zone guides**, as they always did the RestedXP ones — the tags the owner
  approved in the filter review. In Solo mode those guides leave out elite
  and group quests, and the quests that follow on from them; with Auction
  House steps off they leave out quests that need an item most players buy;
  a dungeon's quests show while that dungeon is ticked. The defaults (Solo,
  Auction House steps off) mean fewer steps than before on these guides.

---

## [0.2.0]

### Added
- **Herbalism, Skinning and Fishing guides**, 1–300 — the last three
  professions, until now placeholders. Each skill band is one step naming
  where to go, for your faction, with the levels this addon's zone guides
  spend there:
  - Herbalism: the zones with most of the herbs that can still raise your
    skill, and which herbs to look for, counted from pfQuest's node data
    (Turtle WoW's new zones included).
  - Skinning: the levels of beast worth skinning, and the zones with most of
    them.
  - Fishing: the zones where nothing gets away at your skill; the Expert book
    from Old Man Heming; Nat Pagle's Artisan quest with where each fish is
    caught, or Katoom the Angler for the Horde.
- Every rank names your faction's trainers, capital cities first, and points
  the arrow at the nearest.

---

## [0.1.0] — restart

The first numbered build. Everything below was already in the addon; from here
on, each change gets its own entry.

### Added
- **Leveling guides**: the Optimized routes (Joana's), RestedXP and RXP
  Hardcore route packs, zone guides, and the Turtle-lineage custom zones, with
  automatic accepting, completing and turning in of quests.
- **The guide panel**: one step at a time or the whole guide, up to eight
  guides open as tabs, a navigation arrow, server themes (Day, Night, Turtle
  WoW, OctoWoW, RavenCraft, Capybara Paradise, Aegis), and a first-time setup.
- **Where next?**: custom zones offered between guides when they fit your level.
- **Active items, active targets and macros**, as RestedXP has, and **quest
  icons** — raid markers on the NPCs and mobs your quests want.
- **Profession guides** for eleven professions, a **shopping list** that can go
  to Aegis: Exchange, and the **cheapest crafting route** at today's prices,
  with its own auction scan and a "load as guide" button.
- **Sharing a guide with your party** (beta): progress under each step, and a
  finished step waits for everyone.

---

[0.6.3]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.6.2]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.6.1]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.6.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.5.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.4.2]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.4.1]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.4.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.3.1]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.3.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.2.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.1.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
