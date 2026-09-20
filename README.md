# AEGIS: Pathfinder

A Classic+ leveling guide for the Turtle WoW-lineage 1.12 client family —
OctoWoW, Capybara Paradise and RavenCraft. Part of the AEGIS addon suite.

It keeps your current objective on screen, points a waypoint at it, and
advances itself as you accept, complete and turn in quests — the in-game
experience of Zygor or RestedXP, on a client that predates both.

> **In development, not yet released.** brues-code has given permission to
> build on VanillaGuide+. A few licensing details are still to be settled
> before anything is published — see [LICENSE-STATUS.md](LICENSE-STATUS.md).

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
| `/aegis credits` | Everyone whose work is in this addon |
| `/aegis server` | Cycle which server you play on |
| `/aegis serverstatus` | Guide data provenance per server |

`/pathfinder` and `/vg` do the same thing.

## What it does

**Routes.** Pick a route pack: Zone Completion, Optimized (Joana's routes),
RestedXP, or RXP Hardcore. Your race's starting zone is selected for you, and
all races merge into a shared route after level 12.

**Branching.** Jump from the main route to any zone guide, do as much as you
want, and return — you resume at the step matching your level. A gold
`[BRANCH]` tag shows while you are off the main path.

**Dungeons.** Toggle which of 15 dungeons you intend to run. Opting in promotes
their setup and prerequisite steps to mandatory; opting out hides them.

**Filters.** Solo or group mode, and whether Auction House steps appear.
Defaults follow the route pack you chose.

**Professions.** Ten 1–300 routes with trainers, craft counts, reagents and
recipe sources, tracked against your actual skill level. See below.

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

The four placeholders are listed but unauthored: the reference these guides
were converted from does not cover them. They appear in the list so the
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
has drifted off the theme, and four test suites that execute the addon's own
code against a stubbed 1.12 API.

None of it proves the UI looks right. That needs a client.

| | |
|---|---|
| [docs/GUIDE_AUTHORING.md](docs/GUIDE_AUTHORING.md) | Writing guides: steps, tags, worked examples |
| [docs/UI_SPEC.md](docs/UI_SPEC.md) | How the design concept maps onto frames and textures |
| [media/README.md](media/README.md) | Texture assets and how to regenerate them |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Branching, checks, code rules |

## Credits

Built on a decade of other people's work — Tekkub's TourGuide, isalcedo's
VanillaGuide, brues-code's VanillaGuide-Plus and ClassicAPI, Joana's routes,
RestedXP's, shagu's pfQuest. Full list in
[CONTRIBUTORS.md](CONTRIBUTORS.md), or `/aegis credits` in game.

A fan project, not affiliated with or endorsed by Blizzard Entertainment,
Zygor Guides LLC, RestedXP, or any server team. The interface deliberately
follows conventions set by Zygor and RestedXP; no art or code from either was
used.
