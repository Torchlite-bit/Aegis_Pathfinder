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

## [0.12.3]

### Added
- **The Optimized Alliance route runs Uldaman.** Its Uldaman guide was notes
  only; it now takes you from Gadgetzan to Ironforge, Loch Modan and the
  Badlands for the quests, through the dig site and the instance, and back
  to Ironforge to hand them in -- the Platinum Discs up to Seeing What
  Happens, which Tanaris finishes at the Uldum Pedestal. Uldaman adds 21
  quests and is recommended for the Alliance in the setup.

### Fixed
- Steps tracking the wrong quest in the Optimized Alliance guides: Tanaris's
  Seeing What Happens (2946) and Return to Ironforge (2977) were both Portents
  of Uldum's id, Yuka Screwspigot (4324) was Divino-matic Rod's, and the
  Hinterlands' Jammal'an the Prophet (1446) was The God Hakkar's. The Uldum
  steps were also optional, and an optional accept is never offered, so the
  chain never started; with Uldaman ticked it now runs. Yuka Screwspigot
  sends you to Blackrock Depths' quests, so it is tagged for Blackrock Depths,
  not Zul'Farrak. The filter review records follow the corrected ids.
- The Optimized Badlands guide hands in Badlands Reagent Run and Find Agmond
  but never picked them up; it now stops in Loch Modan for them on the way.

## [0.12.2]

### Fixed
- **Steps meant for a race now reach it.** About 500 steps in the RestedXP,
  RXP Hardcore and zone guides had class or race tags that no character
  could match, so they were hidden from everyone they were written for:
  - `|R|NightElf|` (the client says "Night Elf"): some 150 steps every Night
    Elf skipped.
  - Races inside class tags, where the RestedXP converter folded "Orc Rogue
    or Troll Rogue" into `|C|Rogue/Troll/Rogue| |R|Orc|`, and "not a Shaman
    or Warrior, or any Undead" into `|C|!Shaman/!Warrior/Undead|`. An Undead
    Warrior never saw The Forgotten Pools, and with it Wailing Caverns'
    Leaders of the Fang and Nara Wildmane, which now count in the setup.
    Night Elf mages, priests and rogues missed 27 Darkshore steps the same
    way.
  - Comma lists: `|R|Orc, Troll|`, `|R|Scourge, Undead|`, `|C|Warlock, Mage|`.
  Each was rewritten from the filter in RestedXP's own guide. Where it reads
  "class A, or race B", the step is now two steps that never overlap.
- `Tools/verify.py` checks that every class tag names classes and every race
  tag races, as the client gives them.

## [0.12.1]

### Removed
- **Kamisayo Speedrun is hidden until its guides are added.** None of the
  pack's guides were ever in the addon -- the guide is only shared on
  Kamisayo's Discord -- so picking it stopped on its first leg. It is no
  longer offered in the setup, the options window or `/vg RoutePack`, and a
  character that had it moves to **RestedXP** when it logs in. The route is
  kept in `Routes/Routes.lua`, ready for when the guides come.

## [0.12.0] — restart

### Changed
- **The dungeon step of the setup counts quests, and recommends for the guide
  you picked.** Each dungeon says how many quests it adds to your route, and
  a quest counts only if your guide takes you all the way through it on your
  race's route: sends you to pick it up, has you do first whatever the server
  wants done before it, and sends you to hand it in. A quest whose chain runs
  through another dungeon counts once that one is ticked too ("1 quest (+4
  with Deadmines)"). **Recommended** is now per guide pack and race: the
  dungeons that add five quests or more. It was one list per faction, from
  counting the RestedXP guides' steps.
  - RestedXP recommends 6 to 9 dungeons by race, RXP Hardcore 9 to 11; the
    Optimized guides take you through few dungeon quests, so they recommend
    the Sunken Temple for the Alliance and none for the Horde.
- **Your route decides what comes next.** Finishing a guide on your route
  goes on to the route's next leg for your guide pack and race; a guide's own
  next guide is the way on only off the route. RestedXP's paths part at 19 --
  the Eastern Kingdoms races through Redridge and the Deadmines, Night Elves
  through Darkshore -- and a guide can name only one next.

### Fixed
- **The Optimized guides stopped at 30 and again at 40** (and the Alliance's
  at 50): those guides named no next guide. The High Elf and Goblin starting
  zones handed you to the older zone guides instead of the Optimized ones.
- **Routes that named guides that do not exist**: the Horde's Optimized
  Stonetalon Mountains legs, RestedXP's Wetlands and Southern Barrens, and
  from 42 the Alliance's RXP Hardcore route, which named the Horde's guides;
  the Horde's has no 41-42 Badlands or 45-46 Feralas, and now skips them.
  RestedXP's routes follow its guides again, with the Alliance's 29-30
  Ashenvale, 35-37 Desolace, 40-40 Dustwallow Marsh, 40-41 Desolace, 43-44
  Tanaris/Dustwallow, 50-50 Stranglethorn, 51-51 Blasted Lands and 59-59
  Winterspring/Silithus, and the Horde's 41-41 Desolace, that it skipped.
- **Next guides that did not exist**: the RestedXP converter had left its
  folder names in them ("RestedXP Horde 22-30\22-24 Hillsbrad").
- **Dungeon quests the guides never finished**:
  - Gnomeregan's four quests were never handed in (RestedXP and RXP
    Hardcore, Alliance), nor Red Silk Bandanas (RestedXP).
  - Blackfathom Deeps, Horde: Allegiance to the Old Gods' second part was
    picked up before the first was handed in, and never handed in; Baron
    Aquanis had another quest's id, and no pick-up or hand-in.
  - In Search of Thaelrid was never handed in (RXP Hardcore, Alliance).
  - Brother Paxton was handed in before it was picked up, with the
    Deadmines ticked, and Ink Supplies with it (RXP Hardcore).
  - An Unholy Alliance was handed in only with Scarlet Monastery ticked, not
    Razorfen Downs, where it is done.

### Added
- **`Tools/build_dungeon_quests.py`** checks every dungeon quest along every
  route against the server's quest rules (CMaNGOS classic-db's, and
  pfQuest-turtle's for Turtle WoW's own quests), writes `DungeonQuests.lua`,
  and with `--report` says which do not count and why.
- **`Tools/test_routes.lua`**: every route leg and next guide exists.

## [0.11.1]

### Changed
- **Moonwhisper Coast's group quests are for Group mode**: Price of Betrayal,
  Draenethyst Recovery (inside Timbermaw Hold, at 60) and the zone's bosses --
  Mothshroud Falls, Serpents Without Heads, Keeper of the Broken Grove, Shade
  Mother, A Star That Calls Back -- and every quest that follows from them.
  Solo, the Horde's Moonhoof story stops before Shade Mother, and the
  Alliance skips the trip to Darnassus for Word to the High Priestess.

## [0.11.0] — restart

### Added
- **Moonwhisper Coast (52-60)**, the zone patch 1.18.1 added north of
  Azshara, with a guide for each side: Moro'gai Village's draenei for both,
  Sunsworn Camp and Narvalis Point for the Alliance, Moonhoof Village and
  Moonhoof Retreat for the Horde. The Horde's stories go out to Azshara and
  Mulgore and back, and the guide goes with them. Where next? offers it from
  51, and it is under the guide list's **Custom** tab.
  - Written from quest data players have gathered
    ([ryanmr82's pfQuest-turtle](https://github.com/ryanmr82/pfQuest-turtle)),
    not a server's database, so expect gaps: quests nobody is on record as
    giving, and the ones picked up elsewhere, show only once they are in
    your log. Tell us where it sends you wrong.
- **`Tools/build_zone_guide.py`** writes a zone's guides from a
  pfQuest-turtle checkout -- prerequisites, then level, then the nearest
  thing to do -- so the guide can be written again as the data grows.

### Docs
- The authoring notes gave `|C|` and `|R|` lists with commas; the parser
  splits them on `/`, and matches races as the client names them
  (`Night Elf`).

## [0.10.0]

### Fixed
- **Stat names wrapped on the Item Score page**: "Armor Penetration",
  "Casting Regen %" and the like broke onto two cramped lines. The name
  column is wider and the weight's field narrower, so every name stays on
  one line.

### Added
- **[docs/TESTING.md](docs/TESTING.md)**: the in-game test pass, what only a
  real client can check, section by section. Copy it into an issue and tick
  it off before a release.

## [0.9.1]

### Added
- **The Gear finder looks beyond drops**: at 60 much of the best gear is not
  one. Each switched in the options' Gear page, on to start with:
  - **Quest rewards** from quests you have still to do, on your side and for
    your class — *Quest: Strength of Mount Mugamba (Friendly, Zandalar
    Tribe)*.
  - **Reputation gear** a vendor sells at a rank — *Revered with Stormpike
    Guard*.
  - **Crafted gear** — *Blacksmithing 300 · made by a crafter*, or just the
    profession when it is yours. Gear that binds on pickup counts only if you
    have the profession, and under Solo Self-Found all crafted gear does.

  Near your level only (up to ten levels under it): there are thousands.
- **Turning raids on in the Gear finder says it takes a while**: the first
  time, hundreds of raid items load from the server, a minute or two. The
  window says so too while they load.

---

## [0.9.0]

### Fixed
- **Uneven gaps in the options** around labels that only just fit, such as
  "Pick it for me when quests turn in by themselves": they were counted as
  two lines and drawn on one. A label that fits is one line now.
- **Resizing the options window lays each page out again**: a label that
  stops wrapping gives its line back and the rows under it move up, instead
  of leaving a gap.
- **The Gear finder's note at 60** named every dungeon it looked in — all of
  them, at 60 — and ran over the list. It names up to four and counts the
  rest ("from 26 dungeons and 9 raids").

### Changed
- **The README shows Pathfinder in game**, and the options window's Route,
  Dungeons, Behaviour and Gear pages.

---

## [0.8.0]

### Changed
- **The Gear finder knows Turtle WoW's vanilla dungeons and raids as Turtle
  has them**, not as they were in 2006: the bosses Turtle added (Molten Core's
  Incindis and Basalthar, Deadmines and Blackrock additions and more), loot
  moved from one boss to another, new items on old bosses (VanCleef's Spiked
  Defias Spaulders), and drops Turtle took out. From pfQuest-turtle, over the
  CMaNGOS loot it had.
- **The README's screenshots sit with their features**: party sharing under
  *Play together*, the first-time setup under *Guides*, the helper windows
  under *Quest helpers*.

---

## [0.7.0]

### Changed
- **Solo Self-Found is solo.** Turning it on now also leaves out group quests
  and dungeon quests, not only trading and the Auction House. Group mode, the
  Auction House switch and the dungeon chips read off and can't be clicked
  until it is off again — in the options and in the first-time setup, which
  skips its dungeons step. The Gear finder looks in no dungeons. What they
  were set to is kept, and comes back when Self-Found goes off.
- **The README has screenshots**: the guide in the world, a quest target and
  the macros, and sharing a guide with your party.

### Added
- **The options window resizes** from a grip in its bottom-right corner:
  wider or taller, and it keeps the size. `/apg resetpanels` puts it back.

### Fixed
- **Long option labels were cut off** at the window's edge ("Pick it for me
  when quests turn in by themselves", "Quest icons: mark quest NPCs as you
  mouse over them"). A label that does not fit now wraps onto a second line.

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

[0.12.3]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.12.2]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.12.1]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.12.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.11.1]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.11.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.10.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.9.1]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.9.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.8.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.7.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
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
