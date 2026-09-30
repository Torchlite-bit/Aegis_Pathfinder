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

## [0.18.1]

### Fixed
- **Leaving a starting zone waited for your next login.** When you
  outlevel a starting zone's guide (Elwynn Forest, Durotar and the rest,
  from level 12), Pathfinder should move you onto the shared route at
  once. It didn't: two parts of the addon each handled the level-up, and
  the one loaded second replaced the other. The move only happened the
  next time you logged in.
  - One level-up handler now does both jobs. It ticks a step that was
    waiting for your level, then checks whether you've finished the
    starting zone.
  - The check now uses your new level. The game can still report the
    old one at that moment.

## [0.18.0]

### Added
- **A ticked dungeon's guide, offered at the middle of its levels.** When
  you reach the middle of the level range of a dungeon you ticked in the
  setup (The Deadmines (17-24) at 21), a small window offers its dungeon
  guide. You can open it in a tab beside the route, or choose "Not now".
  - Each dungeon is offered once, whatever you answer. Nothing is offered
    once you're past a dungeon's top level, have finished its guide, or
    already have it open.
  - If several are due at once, they're listed together. Opening one keeps
    the others in the window.
  - It checks when you level up, when you log in and when you finish the
    setup.
  - It covers the dungeons the setup asks about. Turtle WoW's own dungeons
    start ticked, so they stay with "dungeons along the way".
  - The Dungeons page in the options has a switch to turn it off, and
    Solo Self-Found holds it off.

## [0.17.0]

### Changed
- **The target macro takes the nearest, then the next one out on each
  press.** AegisTarget used to be a `/target` line per target, and `/target`
  keeps whoever you already have targeted when they have the name. So with
  three Crocolisks around, every press stayed on the same one. Now:
  - The first press takes the nearest of the step's targets, each press
    after it the next one further out, then back round to the nearest. Dead
    ones are skipped.
  - The macro is `/apg target`, the same on every step. `/apg target`, the
    key binding and the Macros window's tile all do the same.
  - Clicking a target's button in Active Targets again moves on to the next
    one by that name.
  - Looking round puts no raid marks on the mobs it passes, only on the one
    it takes.
  - It uses ClassicAPI's `TargetNearest`. Without it, or when none of the
    step's targets turn up that way (a quest giver further off, say), it
    targets by name as before. When it finds nobody, your target is left as
    it was.

## [0.16.2]

### Fixed
- **"Cannot find zone "Redridge", using current zone." on every step.** A
  step with no zone of its own is in the guide's zone, read from the guide's
  title, and some titles shorten it: Optimized Redridge (18-20) is in
  Redridge Mountains, but the map has no "Redridge". So each step's waypoint
  went on the zone you were standing in, and chat said so.
  - Shortened zone names are now read as the map's names, in guide titles and
    in steps' zone tags: Redridge, Stranglethorn, Tirisfal, Un'Goro,
    Stonetalon, Hinterlands, Hillsbrad, Alterac, Arathi, Dustwallow, Barrens
    and Stormwind.
  - The Stranglethorn (39-40) guide's steps had their zone written wrong, and
    a Hunter step in RestedXP's Darkshore/Ashenvale guide had a zone and
    coordinates from another map. Both are fixed.
  - Dungeon guides' "outside too" points now say which zone they're in (the
    one the entrance is in), instead of the dungeon's name.
  - RestedXP's "Travel to Kalimdor" and "Travel to Eastern Kingdoms" steps
    give a point on the continent's map, which no arrow here can point at.
    They now set no waypoint and print nothing, where before they put one at
    the same numbers in the zone you were in.

## [0.16.1]

### Fixed
- **Errors with some forks of pfQuest.** Pathfinder reads pfQuest's quest,
  NPC and object tables to place quest-giver waypoints, and uses pfQuest's
  map to put waypoints and its arrow on the step. It assumed every one of
  those tables and functions was there, and a fork without one gave errors.
  - Each table is now checked before it's read; a missing one just means no
    waypoint from it.
  - pfQuest is only used for waypoints when all the map functions Pathfinder
    needs are there. Otherwise another waypoint addon takes them.

## [0.16.0]

### Added
- **Badges that say what a guide is**, on its tab. `XP` for a leveling guide
  as before, plus:
  - `PF` (blue) for a profession guide or crafting route;
  - `DG` (violet) for a dungeon guide;
  - `HC` (red) for a hardcore guide.

  A placeholder guide still says `TPL`.

### Fixed
- **Ticks moved to other steps when a filter changed.** The addon remembers a
  tick by the step's name and its place in the guide.
  - That place was counted among the steps the filters kept. Switching group
    mode, Auction House steps, a dungeon or Solo Self-Found added or removed
    steps, so every later step's place changed, and the ticks saved against
    the old places landed on other steps.
  - A step's place is now counted among all the guide's steps, so filters
    don't move it.
  - Your ticks move over to the new places once, the first time each guide
    loads. A guide with nothing filtered keeps the places it always had.

## [0.15.5]

### Fixed
- **The AegisTarget macro had a blank icon**, in the Macros window and on
  an action bar.
  - The stock macro functions pick an icon by its place in the game's
    macro-icon list. The game fills that list only when something asks for
    it.
  - The addon read the list once, while it was still empty, and saved the
    macro with an icon from an empty list: nothing.
  - Macros are now written through ClassicAPI's macro functions, which take
    the icon by name. AegisTarget wears Hunter's Mark's icon, and AegisItem
    the quest item's own icon, which the stock list doesn't have.
  - A macro already made blank gets its icon at the next update.
  - Without ClassicAPI's macro functions, the list is read again until the
    game has filled it.

## [0.15.4]

### Fixed
- **Active Targets sent you to crocolisks in other zones.** For Loch Modan's
  Crocolisk Hunting, the targets and the AegisTarget macro were Elder
  Saltwater Crocolisks, Wetlands Crocolisks and the like, never a Loch
  Crocolisk.
  - Crocolisk Meat and Skin drop from every crocolisk in the world, and more
    often from those elsewhere. The targets were simply the likeliest drops
    anywhere.
  - Now the creatures the quest wants killed or looted come from where the
    step is: the step's zone, then the guide's zone, then the zone you're in.
    Only when none of those has any does it fall back to everyone.
  - Quest icons mark by the zone you're in the same way.

## [0.15.3]

### Fixed
- **The guide kept closing in combat.** Escape closed it. In a fight, Escape
  is what clears your target or cancels a spell, so the guide went with it.
  Escape no longer closes the guide; its ✕ does. Escape still closes the
  options, the guide list, the Gear finder and the other windows opened from
  the guide.

## [0.15.2]

### Fixed
- **"QuestTracker.lua:177: attempt to call method 'GetObjectiveInfo'"**, and
  the "ItemScore.lua:72 ... field 'db'" error with it. Both came from Core.lua
  stopping part-way as it loaded.
  - At load, Core.lua reads the game's races from ClassicAPI, and every
    race's side with them.
  - The game's race table also lists creature races with no side, and
    ClassicAPI gives nothing for their side. Reading that nothing stopped
    Core.lua at that line.
  - Everything after that line was never set up: the saved settings, and
    much of the guide. Every error that followed was a symptom.
  - Races with no side are now skipped. Without ClassicAPI at all, the addon
    now says so instead of failing.

## [0.15.1]

### Fixed
- **"ItemScore.lua:72: attempt to index field 'db' (a nil value)"**, around
  login. The item score, the Gear Advisor and the Gear finder listen for
  your gear arriving and for zoning in from the moment their files load,
  which can be before the addon has loaded its saved settings. They went
  looking for the settings and stopped with that error. Those events are now
  ignored until the settings are loaded, and your worn gear is recorded then
  instead.

## [0.15.0] — restart

### Added
- **A switch for each arrow.** The **Arrows** section on the **Navigation**
  page has one each for Pathfinder's, TomTom's and pfQuest's arrow, in place
  of the one-choice dropdown. Turn on any combination: each arrow that is on
  points at the step, even when another addon is the one taking the
  waypoints.
  - pfQuest's switch is pfQuest's own arrow setting, the one `/db arrow`
    changes. Off, pfQuest's arrow is off altogether, so it no longer points at
    the nearest quest objective as a second arrow.
  - TomTom's switch keeps its arrow off the guide's waypoints; waypoints you
    make yourself still use it.
  - An addon that isn't loaded has its switch dimmed, and the note names it.

### Changed
- **Steps the addon ticks for you have a small ⟳ inside their circle**, in
  place of a glow that looked like the circle was out of focus. An empty
  circle is one only you can tick; a filled one is done. The ⟳ is a new
  texture, hence the restart.
- **The step's accent bar runs down past its objectives.** The bar down the
  left edge, and the faint wash, now reach past the objective bars to the
  footer, so the bars read as part of the step.

### Fixed
- **Objective bars were still short in game.** 4 of 5 Crocolisk Meat was
  about half full, and 4 of 6 skins about two fifths. The width the client
  reports for these bars isn't the width it draws them at, so any fill sized
  from it comes out wrong. They're now the client's own status bars, which
  fill to the count themselves. The guide's progress bar under the step
  number gets the same fix.

## [0.14.0]

### Added
- **Dungeons along the way.** Switch on *Offer dungeon guides along the way*
  on the options' **Dungeons** page, and finishing a guide asks **Where next?**
  with the guides of the dungeons you ticked that fit your level, under the
  custom zones: up to four, lowest first. One opens in a tab beside your
  route. It is off to start with, and Solo Self-Found holds it off.
- **Turtle WoW's own dungeons on the Dungeons page**, as chips of their own:
  Frostmane Hollow, Windhorn Canyon, Dragonmaw Retreat, Stormwrought Ruins,
  Crescent Grove, Gilneas City and Hateforge Quarry. No route guide has steps
  for them; ticked, the Gear finder looks in them, and their guides can be
  offered along the way.
- **Red and green switches**, on the **Appearance** page: every switch green
  when on and red when off, whatever the theme.
- **A bar for each objective.** The meter under the step has a line for each
  thing the quest wants, each with its count and its own bar. Crocolisk
  Hunting shows the meat and the skins.

### Changed
- **Switches take the theme's colours again**, as they did before 0.12.7;
  red and green is now the switch above. RavenCraft's on switch is a near
  white, since grey on grey did not say whether a switch was on.
- **The route preview fills the Route page**, down to the bottom, and shows
  more legs as the window is made taller.

### Fixed
- **The Scale slider jumped to 60% at a touch and would not move.** It sits in
  the options window it scales, so each step rescaled the window under the
  cursor and the slider chased itself to the bottom. While you drag, only its
  number moves; the windows take the size when you let go.
- **A guide went back to step 1.** Opened partway, it went to the quest your
  log shows work at, such as Loch Modan's Crocolisk Hunting, 27 steps in. The
  next update then went back to the guide's first note, which the log cannot
  tick: "1 of 58, 0 done". Now the notes, runs, flight paths and hearths
  before a quest you have picked up or finished count as done. One before a
  quest you have not picked up still waits for you.
- **An objective's bar showed less than its count**: 4 of 5 Crocolisk Meat
  was a third full. The bar was sized from its width at the moment it was
  drawn, which can be stale. It now keeps the count and sizes itself again
  when its width changes.

## [0.13.1] — restart

### Added
- **Dungeon guides.** The guide list has a **Dungeons** tab with a guide for
  every dungeon, for your side. Pick one and it:
  - goes round the towns to pick up every quest for the dungeon, doing the
    quests before them on the way;
  - puts the arrow on the entrance;
  - has you do what each quest wants inside;
  - hands everything in after.

  A chain that needs another visit, such as Uldaman's necklace, gets another
  run. A quest whose chain starts somewhere the guide does not go, such as a
  class chain or another dungeon's quests, is optional: it shows once you have
  done the quest before it. Quests given where the guide does not go are named
  in a note at the top. The guides cover Ragefire Chasm to Blackrock Depths,
  and Turtle WoW's own dungeons:
  - Windhorn Canyon, new in patch 1.18.1;
  - Frostmane Hollow, which also has a Horde guide for cross-faction groups;
  - Dragonmaw Retreat, Crescent Grove, Stormwrought Ruins, Gilneas City and
    Hateforge Quarry.
- **Windhorn Canyon's quests**, on both sides:
  - Alliance: In Search of Tauren Relics, from Ironforge.
  - Horde: Relics of the Windhorn Tribe and The Wrath of Malgan, from Sagh's
    Refuge.
  - Horde: Cairne's Destroy the Deathtotem, by way of Grimtotem Spying.
  - Horde, Shaman only: Vortalus' Edict.
- **Windhorn Canyon and Frostmane Hollow in the Gear finder**, with each
  boss's loot and its drop chance. Windhorn Canyon is at 26-30, Frostmane
  Hollow at 13-20.
- The data comes from two new sources:
  - [InstanceJournal](https://github.com/Arthur-Helias/InstanceJournal) by
    Arthur-Helias gives each dungeon's quests, entrance and levels, and the
    two new dungeons' loot.
  - [The Kludge Bureau's pfQuest-turtle](https://github.com/The-Kludge-Bureau/pfQuest-turtle)
    gives patch 1.18.1's quests.

## [0.13.0] — restart

### Added
- **The Optimized Horde route runs Uldaman and the Sunken Temple**, as the
  Alliance route already does, so the first-time setup now recommends both
  for the Horde.
  - *Uldaman (46-46)*, after Feralas, picks up Necklace Recovery in
    Orgrimmar, Reclaimed Treasures in the Undercity, Uldaman Reagent Run in
    Kargath and Solution to Doom from Theldurin, runs the dig site and the
    instance, and hands everything in on the way back, the Platinum Discs to
    Thunder Bluff included. Tanaris (49-50) takes the discs to the Uldum
    Pedestal, and the Burning Steppes' stop in Thunder Bluff finishes the
    chain. That is 13 quests.
  - *Sunken Temple (53-53)*, after the Burning Steppes, hands in Return to
    Fel'Zerul in Stonard, picks up The Temple of Atal'Hakkar and runs the
    temple: Into the Depths, Secret of the Circle, Zapper Fuel, Jammal'an and
    the Essence of Eranikus. Then it hands in the Fetishes in Stonard and
    Jammal'an at Shadra'Alor. Into the Depths is now picked up from Marvon
    after The Stone Circle. Zapper Fuel, which the route picked up and never
    handed in, goes back to Larion in Marshal's Refuge on the way to
    Silithus. That is 9 quests.
  - Without the dungeon ticked, each leg is a single note.

## [0.12.8]

### Added
- **More than one spec, as Pawn does.** The Item Score page has a switch for
  each spec of your class; yours is always on. Every spec that is on gets its
  own line on item tooltips, with its score and upgrade percentage.
- **The best you have worn, per spec.** Each spec that is on remembers the
  best items you have worn in each slot -- the best two rings and trinkets --
  as your gear changes, and an item is weighed against those rather than what
  you have on, so the healing set in your bags does not hide a tank upgrade.
  **Forget best items** starts again from what you wear. With nothing
  remembered yet, the comparison is with what you wear, as before.
- **Drops for your other specs.** When something new in your bags beats your
  best for another spec that is on, the chat names it once, with the gain.
  Your own spec's upgrades still go to the Gear Advisor's window. There is a
  switch for it on the same page.

## [0.12.7]

### Added
- **Window scale.** A **Scale** slider on the options window's Appearance
  page, 60% to 150%, sizes every Pathfinder window at once: the guide, the
  options, the shopping list, the Active Items and Targets windows and the
  rest. It is kept per profile.

### Changed
- **The step title wraps.** In focus mode the guide's step title wraps to the
  window's width instead of ending in "..." -- drag the grip narrower and the
  title takes more lines, and the step grows to hold them. The overview list
  keeps one line a step, so it still scrolls.
- **Switches are green when on and red when off,** whatever the theme. In some
  themes an on switch and an off one were near enough the same grey.

## [0.12.6]

### Fixed
- **Optional quests that follow another are offered once it is done.** A
  step like "A Rescue OOX-22/FE! |PRE|2766| |O|" waits for its prerequisite,
  but the guides give that as a quest id and the addon looked for it among
  the steps' names, so it never found it and the step was never offered.
  Now the id is checked against the server's record of your quests and the
  guide's own turn-ins, and a list of ids needs all of them. Affected: Rescue
  OOX-22/FE!, The Newest Member of the Family and An OOX of Your Own
  (Optimized Alliance), Proof of Deed, At Last! and Further Mysteries (zone
  guides). Prerequisites given by name work as before.

## [0.12.5] — restart

### Added
- **The Optimized Alliance route runs the Sunken Temple.** A new leg after the
  Burning Steppes, *Sunken Temple (56-56)*, picks up Into The Temple of
  Atal'Hakkar in Stormwind, runs the temple -- the Atal'ai tablets, Into the
  Depths, Secret of the Circle, Jammal'an and the Essence of Eranikus -- and
  hands in Jammal'an at Shadra'Alor and the tablets in Stormwind before
  Silithus. Into the Depths is picked up from Marvon after The Stone Circle,
  and the Hinterlands now offers Jammal'an the Prophet, which was optional and
  so never offered. The Sunken Temple adds 13 quests to the route. Without
  the Sunken Temple ticked, the leg is a single note.

### Fixed
- RestedXP Alliance: Jammal'an the Prophet is picked up at the Altar of Zul
  and handed in on the way to the Plaguelands, by way of the Hinterlands.

## [0.12.4]

### Fixed
- **Dungeon quest chains the guides started and never finished.** With the
  dungeon ticked, each now gets its missing pick-up, dungeon step or hand-in
  where the route already passes the quest's NPC:
  - RestedXP Alliance: Into the Depths and Secret of the Circle in the Sunken
    Temple; Mortality Wanes handed in in Darnassus on the Feralas leg; The
    Dragon's Eye handed in to Haleh above Mazthoril after the last guide
    hearths to Everlook (RXP Hardcore too).
  - RXP Hardcore Horde: a stop in Thunder Bluff between the Swamp of Sorrows
    and Tanaris for the Platinum Discs, Portents of Uldum and Seeing What
    Happens, so the Uldum Pedestal chain in Tanaris can start; Deadmire is
    handed in on the same stop. The Badlands detour at 42 no longer offers To
    the Undercity for Yagyin's Digest, which needs Solution to Doom first, and
    Necklace Recovery is handed in after Uldaman instead of straight after it
    is accepted. Shadowshard Fragments is picked up and handed in in
    Orgrimmar around Maraudon.
  - RestedXP Horde: Necklace Recovery (once you have looted the necklace in
    Uldaman) and Shadowshard Fragments in Orgrimmar; The Power to Destroy...
    for Undead, from Varimathras on the way to Ragefire Chasm.
  - Optimized: the Burning Steppes guides take a Blackrock Depths group in
    for A Taste of Flame (Alliance) and Lost Thunderbrew Recipe (Horde) and
    hand them in; the Horde picks up Yuka Screwspigot in Tanaris too.
- Left as they are, because the route cannot finish them: The Prophecy of
  Mosh'aru, Nekrum's Medallion and The God Hakkar (their first step is only
  handed in after the Zul'Farrak run), Tiara of the Deep (a mage quest's
  follow-up), Jammal'an and Zapper Fuel where the route never returns to the
  Hinterlands or never runs the Sunken Temple, Going, Going, Guano! (its
  guano drops only with the quest, which needs level 30, after the Razorfen
  Kraul run), and Badlands Reagent Run on the Hardcore route, which does no
  Badlands questing.

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

[0.18.1]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.18.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.17.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.16.2]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.16.1]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.16.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.15.5]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.15.4]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.15.3]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.15.2]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.15.1]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.15.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.14.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.13.1]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.13.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.12.8]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.12.7]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.12.6]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.12.5]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.12.4]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
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
