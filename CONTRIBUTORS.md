# Contributors

Aegis: Pathfinder stands on a decade of other people's work. This file records
everyone whose work is in it, and is the list the in-game credits window (the
**Credits** button on the options window's **About** page) mirrors.

If you contribute, add yourself. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Addon lineage

The code descends, oldest first, through:

| Project | Author | What it contributed |
|---|---|---|
| [TourGuide](https://github.com/TekNoLogic/TourGuide) | **Tekkub** | The original powerleveling guide framework: the step/tag DSL that every guide in this repository is still written in |
| [VanillaGuide](https://github.com/isalcedo/VanillaGuide) | **isalcedo** | The 1.12 addon structure, and the conversion of Joana's routes into guide files |
| VanillaGuide-Plus | **NostalgiaGeek** | Continued the fork |
| [VanillaGuide-Plus](https://github.com/brues-code/VanillaGuide-Plus) | **brues-code** (Brues) | The ClassicAPI edition: id-keyed quest tracking, gossip automation, the branch system, RXP route packs, dungeon selection, play-style filters |
| [ClassicAPI](https://github.com/brues-code/ClassicAPI) | **brues-code** | The client DLL that backports modern WoW API to 1.12. Without it none of the automatic step advancement in this addon would be possible |
| Aegis_Pathfinder_Plus | **Torchlite** | The fork this project is built from |
| Aegis: Pathfinder | **Torchlite** | Rebrand, reskin, profession guides |

Commit history from the upstream fork is preserved in this repository rather
than flattened, so `git log` and `git blame` still attribute each line to
whoever wrote it. As of the port, that history carries commits from
**DonutsDelivery**, **Brues** and **NostalgiaGeek**.

## Guide content

| Source | Credit |
|---|---|
| Optimized leveling routes | **Joana** (Mancow) — [Joana's Vanilla WoW Guides](https://www.joanasworld.com/) |
| Optimized quest ordering | **mrmr**, credited in the headers of `Guides/Optimized/` |
| RestedXP speedrun and hardcore route packs | **RestedXP Guides** — Tactics and Zeroji |
| Turtle WoW custom zone content | The **Turtle WoW** team, and the successor-server teams continuing it |
| Moonwhisper Coast (`Guides/*/52_60_Moonwhisper_Coast.lua`) | Written by `Tools/build/build_zone_guide.py` from **ryanmr82**'s [pfQuest-turtle](https://github.com/ryanmr82/pfQuest-turtle) fork (the Hydra guild's, built from the captures its players send in), with a title and objective it lacks from **rivi-s**'s [pfQuest-turtle-HDB](https://github.com/rivi-s/pfQuest-turtle-HDB) |
| Dungeon guides (`Guides/Dungeons/`) | Written by `Tools/build/build_dungeon_guides.py`: which quests belong to each dungeon, its levels and its entrance from **Arthur-Helias**'s [InstanceJournal](https://github.com/Arthur-Helias/InstanceJournal) (public domain); the quests themselves -- givers, takers, objectives, chains -- from pfQuest and **The Kludge Bureau**'s [pfQuest-turtle](https://github.com/The-Kludge-Bureau/pfQuest-turtle), which has patch 1.18.1's |
| Class quest guides (`Guides/Class/`) | Written by `Tools/build/build_class_guides.py`: the class quests' givers, takers and objectives from pfQuest and **The Kludge Bureau**'s [pfQuest-turtle](https://github.com/The-Kludge-Bureau/pfQuest-turtle), which has Turtle WoW's High Elves' and Goblins' own; the chains -- which quest follows which, the races each is for, what one gives that another needs -- from CMaNGOS classic-db |
| Profession routes (`Guides/Professions/`) | Converted from a reference document supplied by the repository owner; Engineering's from [CraftRoute](https://github.com/Kitymeowmeow-turt/CraftRoute) by **Kitymeowmeow** |

## Libraries and data

| Component | Author |
|---|---|
| Ace2 (`AceAddon-2.0`, `AceEvent-2.0`, `AceDB-2.0`, `AceLibrary`, `AceOO-2.0`, `AceConsole-2.0`, `AceDebug-2.0`, `AceHook-2.1`) | The **Ace Development Team** |
| Dewdrop-2.0, Tablet-2.0, FuBarPlugin-2.0 (the minimap icon and its menu, until the addon drew its own) | **ckknight** and the Ace Development Team |
| [pfQuest](https://github.com/shagu/pfQuest) / pfQuest-turtle / pfQuest-octo | **shagu** — also the herb and ore node counts behind the Herbalism and Mining guides, extracted by `Tools/build/build_gathering.py`, and what drops in Turtle WoW's own dungeons and raids for the Gear finder, by `Tools/build/build_gear_data.py` |
| [pfUI](https://github.com/shagu/pfUI) | **shagu** — where every area's explored art sits on each zone's map (`pfMapOverlayData`), for the guide browser's fully explored maps, converted by `Tools/build/build_map_overlays.py`. MIT: its notice is carried in `MapOverlays.lua` |
| [TomTom-TWOW](https://github.com/laytya/TomTom-TWOW) | **Cladhaire**; ported to 1.12 by Aero, Schaka, Logonz, Dyaxler, Alphaest, cralor and **laytya**. Earlier builds of this addon targeted the [sweetgiorni](https://github.com/sweetgiorni/TomTom) port |
| MetaMap, MetaMapBWP, Cartographer | Their respective authors — supported waypoint providers |
| [ClassicAPI](https://github.com/brues-code/ClassicAPI) | **brues-code** — required at runtime |
| [CMaNGOS classic-db](https://github.com/cmangos/classic-db) | The **CMaNGOS** team — which trainers teach each Engineering, Herbalism, Skinning and Fishing rank, from its trainer lists; the ore each vein yields, what quest rewards sell for, what drops in each dungeon and raid, the skinnable beasts, each zone's fishing skill, the Expert fishing book and Nat Pagle's quest, extracted by `Tools/build/build_gathering.py`; and the quest rules -- what must be done before each quest, which lock each other out -- behind the first-time setup's dungeon quest counts, extracted by `Tools/build/build_dungeon_quests.py`; and the class quest chains behind the class quest guides, by `Tools/build/build_class_guides.py` |
| [InstanceJournal](https://github.com/Arthur-Helias/InstanceJournal) | **Arthur-Helias** — each dungeon's quests and entrance for the dungeon guides, and what Windhorn Canyon's and Frostmane Hollow's bosses drop, and how often, for the Gear finder (`Tools/build/build_gear_data.py`). Public domain (the Unlicense) |
| [OctoPawn](https://github.com/iGreed1993/OctoPawn) | **iGreed** — the item score's stat weights for every class and spec, its tooltip stat patterns and soft caps, converted by `Tools/build/import_octopawn.py`. MIT: its notice is carried in `ItemScoreData.lua` |
| [CraftRoute](https://github.com/Kitymeowmeow-turt/CraftRoute) | **Kitymeowmeow** — the recipe data behind the priced crafting routes (skill thresholds, reagents, learn costs, recipe sources, vendor buy and sell prices), converted by `Tools/build/import_recipes.py`. CraftRoute is GPLv3, which is why this addon is too; the route planner itself is written separately |

## Fonts

| Font | Copyright | Licence |
|---|---|---|
| Rajdhani | Copyright (c) 2014 Indian Type Foundry | SIL OFL 1.1 |
| Inter | Copyright 2016 The Inter Project Authors | SIL OFL 1.1 |

## Not affiliated

Aegis: Pathfinder is a fan project. It is not affiliated with, endorsed by, or
connected to Blizzard Entertainment, Zygor Guides LLC, RestedXP, or any of the
server teams named above. World of Warcraft is a trademark of Blizzard
Entertainment.

The interface deliberately follows conventions established by Zygor Guides and
RestedXP. No art, assets or code from either was used; every texture in
`media/` is generated by `Tools/build/make_assets.py`.
