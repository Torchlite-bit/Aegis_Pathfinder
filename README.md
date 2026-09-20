# AEGIS: Pathfinder

A Classic+ leveling guide for the Turtle WoW-lineage 1.12 client family —
OctoWoW, Capybara Paradise and RavenCraft. Part of the AEGIS addon suite.

It keeps your current objective on screen, points a waypoint at it, and
advances itself as you accept, complete and turn in quests — the in-game
experience of Zygor or RestedXP, on a client that predates both.

> **In development.** Not released yet.

## Requirements

- A 1.12 client on a Turtle WoW-lineage server (Interface 11200)
- **[ClassicAPI](https://github.com/brues-code/ClassicAPI) v1.5.9 or newer**,
  which is a hard requirement — the addon refuses to load without it

ClassicAPI backports modern WoW API to the 1.12 client. It is why this addon
can track quests by id and advance itself, instead of scraping chat messages
and matching quest names as strings the way vanilla-era guide addons had to.

Optional, and worth having: [TomTom](https://github.com/sweetgiorni/TomTom) for
an arrow, and a [pfQuest](https://github.com/shagu/pfQuest) database pack
matched to your server for quest-giver lookups and prerequisite warnings.

## Installing

1. Install ClassicAPI v1.5.9+
2. Put the addon in `World of Warcraft/Interface/AddOns/AegisPathfinder/`
3. Restart the client

The folder must be named `AegisPathfinder`, matching `AegisPathfinder.toc`.

Upgrading from TurtleGuide / VanillaGuide+? Your saved progress carries over
automatically the first time you log in. Guides you wrote yourself keep working
too — the old `TurtleGuide` global is still an alias.

## Commands

| Command | |
|---|---|
| `/aegis` | Open the options panel |
| `/aegis next` / `prev` | Step forward or back |
| `/aegis goto <n>` | Jump to a step |
| `/aegis reset` | Reset progress in the current guide |
| `/aegis materials` | Reagents the rest of this guide still needs |
| `/aegis credits` | Everyone whose work is in this addon |
| `/aegis server` | Cycle which server you play on |
| `/aegis serverstatus` | Guide data provenance per server |

`/pathfinder` and `/vg` do the same thing.

## What it does

**Routes.** Pick a route pack: Zone Completion, Optimized (Joana's routes),
RestedXP, or RXP Hardcore. Your race's starting zone is selected for you, and
all races merge into a shared route after level 12.

**Branching.** Jump from the main route to any zone guide, do as much as you
want, and return — you resume at the step matching your level. The objectives
panel shows this as tabs: the guide you left stays open beside the one you
branched to, and closing that tab brings you back. A gold `[BRANCH]` tag shows
on the status bar while you are off the main path.

**Dungeons.** Toggle which of 15 dungeons you intend to run. Opting in promotes
their setup and prerequisite steps to mandatory; opting out hides them. A blue
dot marks the dungeons the guide you are currently on actually has steps for.

**Filters.** Solo or group mode, and whether Auction House steps appear.
Defaults follow the route pack you chose.

**Professions.** Ten 1–300 routes with trainers, craft counts, reagents and
recipe sources, tracked against your actual skill level. See below.

**Materials.** `/aegis materials` totals the reagents the rest of the current
guide still needs — counted from where you actually are, not from step one, so
it is the number you want at the auction house rather than the one you needed
when you started.

**Automatic advancement.** Accepting, completing and turning in quests, binding
a hearthstone, and collecting tagged items all resolve themselves. So do travel
steps, once a waypoint provider is active. The checkbox wears a halo on steps
the addon can finish for you, so you know when not to reach for it.

## Professions

| Authored | |
|---|---|
| Alchemy, Blacksmithing, Cooking, Enchanting, First Aid, Jewelcrafting, Leatherworking, Mining, Survival, Tailoring | Full 1–300 routes |
| Engineering, Herbalism, Skinning, Fishing | Placeholders — see below |

Each authored guide carries the trainer for each tier (yours only — Alliance
players are not shown Horde trainers), what to craft in each skill band, the
reagents, where the recipe comes from, and equally viable alternatives. Steps
complete themselves as your skill climbs.

The four placeholders are listed but unauthored, and carry a grey `TPL` badge
in the guide list: the reference these guides were converted from does not
cover them. They appear in the list so the
Professions tab matches the design, and are labelled so an unauthored guide is
obviously unauthored rather than silently missing. Three of them — Herbalism,
Skinning and Fishing — are gathering professions and need a different kind of
guide anyway: where to gather at each skill band, not what to craft.

Where the reference had no recipe for a skill range, the guide says so rather
than inventing one. Mining's mid-range gaps are real, and it tells you to go
mine nodes.

## Servers and guide data

Turtle WoW itself is offline. The successor servers each reconstructed content
past roughly patch 1.17 independently, so **quest ids and coordinates are not
guaranteed to be identical between them**.

Guide content here was authored against **OctoWoW**. It is likely but not
guaranteed to be correct on Capybara Paradise or RavenCraft (which launched in
August 2026).

Tell the addon which server you are on with `/aegis server`. It does not swap
in a per-server dataset — only one exists — but it will say so on the status
card when the loaded guide's data was authored somewhere else, which is the
most likely reason a waypoint points at nothing.

`/aegis serverstatus` shows what is known per server, including which pfQuest
pack to use: `pfQuest-octo` for OctoWoW, the original `pfQuest-turtle` for
Capybara Paradise, and none confirmed for RavenCraft.

Reports welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

## Development

```sh
sh Tools/run_tests.sh
```

Runs everything that can be checked without a client: Lua syntax, Lua 5.0
compatibility, `.toc` and `Guides.xml` integrity, TGA validity, that no panel
has drifted off the theme, and eight test suites that execute the addon's own
code against a stubbed 1.12 API.

None of it proves the UI looks right. That needs a client.

| | |
|---|---|
| [docs/GUIDE_AUTHORING.md](docs/GUIDE_AUTHORING.md) | Writing guides: steps, tags, worked examples |
| [docs/UI_SPEC.md](docs/UI_SPEC.md) | How the design concept maps onto frames and textures |
| [media/README.md](media/README.md) | Texture assets and how to regenerate them |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Branching, checks, code rules |

## Credits

AEGIS: Pathfinder is built on a decade of other people's work. Almost
everything that makes it function was written by someone else first.

**The addon itself** descends, oldest first, through:

| | |
|---|---|
| **Tekkub** | [TourGuide](https://github.com/TekNoLogic/TourGuide) — the original guide framework, and the step/tag DSL every guide in this repository is still written in |
| **isalcedo** | [VanillaGuide](https://github.com/isalcedo/VanillaGuide) — the 1.12 addon structure, and the conversion of Joana's routes into guide files |
| **NostalgiaGeek** | VanillaGuide-Plus — continued the fork |
| **brues-code** (Brues) | [VanillaGuide-Plus](https://github.com/brues-code/VanillaGuide-Plus) — the ClassicAPI edition: id-keyed quest tracking, gossip automation, the branch system, RXP route packs, dungeon selection, play-style filters |
| **brues-code** | [ClassicAPI](https://github.com/brues-code/ClassicAPI) — the client DLL that backports modern WoW API to 1.12. None of the automatic step advancement in this addon would work without it |
| **DonutsDelivery** | VanillaGuide-Plus |

Upstream commit history is preserved in this repository rather than flattened,
so `git log` and `git blame` still attribute each line to whoever wrote it.

**The guide content** is not ours either:

| | |
|---|---|
| **Joana** (Mancow) | [The optimized leveling routes](https://www.joanasworld.com/) |
| **mrmr** | Optimized quest ordering, credited in the headers of `Guides/Optimized/` |
| **RestedXP Guides** — Tactics and Zeroji | The RXP speedrun and hardcore route packs |
| **The Turtle WoW team**, and the successor-server teams continuing it | The custom zone content |

**Libraries, data and fonts:**

| | |
|---|---|
| **The Ace Development Team** | Ace2 (`AceAddon-2.0`, `AceEvent-2.0`, `AceDB-2.0`, `AceLibrary`, `AceOO-2.0`, `AceConsole-2.0`, `AceDebug-2.0`, `AceHook-2.1`) |
| **ckknight** and the Ace Development Team | Dewdrop-2.0, Tablet-2.0, FuBarPlugin-2.0 |
| **shagu** | [pfQuest](https://github.com/shagu/pfQuest), pfQuest-turtle, pfQuest-octo |
| **Cladhaire**, ported by **sweetgiorni** | [TomTom](https://github.com/sweetgiorni/TomTom) |
| The authors of MetaMap, MetaMapBWP and Cartographer | Supported waypoint providers |
| **Indian Type Foundry** | Rajdhani (SIL OFL 1.1) |
| **The Inter Project Authors** | Inter (SIL OFL 1.1) |

The full list is in [CONTRIBUTORS.md](CONTRIBUTORS.md), and in game under
`/aegis credits` — credit should be visible to people using the addon, not
only to people reading the repository.

A fan project, not affiliated with or endorsed by Blizzard Entertainment,
Zygor Guides LLC, RestedXP, or any server team. The interface deliberately
follows conventions set by Zygor and RestedXP; no art or code from either was
used — every texture in `media/` is generated by `Tools/make_assets.py`.
