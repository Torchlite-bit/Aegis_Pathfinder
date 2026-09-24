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

Optional, and worth having: [TomTom-TWOW](https://github.com/laytya/TomTom-TWOW)
for waypoints and map pins, and a [pfQuest](https://github.com/shagu/pfQuest) database pack
matched to your server for quest-giver lookups and prerequisite warnings.

## Installing

1. Install ClassicAPI v1.5.9+
2. Put the addon in `World of Warcraft/Interface/AddOns/Aegis_Pathfinder/`
3. Restart the client

The folder must be named `Aegis_Pathfinder`, matching `Aegis_Pathfinder.toc` —
the addon's texture paths are absolute and will not resolve otherwise.

Upgrading from TurtleGuide / VanillaGuide+? Your saved progress carries over
automatically the first time you log in. Guides you wrote yourself keep working
too — the old `TurtleGuide` global is still an alias.

## Commands

| Command | |
|---|---|
| `/apg` | Open the objectives panel |
| `/apg next` / `prev` | Step forward or back |
| `/apg goto <n>` | Jump to a step |
| `/apg reset` | Reset progress in the current guide |
| `/apg resetpanels` | Put every window back where it opens by default |
| `/apg materials` | The shopping list: reagents for this craft, or the rest of the guide |
| `/apg exchange` | Send the guide's remaining crafts to Aegis: Exchange, or take them back out |
| `/apg target` | Target and mark the step's next active target (put it in a macro) |
| `/apg useitem` | Use the first active item |
| `/apg server` | Cycle which server you play on |
| `/apg serverstatus` | Guide data provenance per server |

`/pathfinder` and `/vg` do the same thing. There is deliberately no `/aegis` —
that belongs to another addon in the AEGIS suite.

The objectives panel is the addon's main window, so a bare `/apg` opens it, and
it opens with the client. The AEGIS shield on the edge of the minimap does the
same on a click; right-click it for the options panel, and drag it to move it
round the minimap. The options panel can hide it, as can `/apg minimapbutton`.
FuBar is no longer supported: the button is the addon's own now.

## What it does

**Routes.** Pick a route pack in the options panel: Optimized (Joana's
routes), RestedXP, or RXP Hardcore — plus Kamisayo Speedrun for Horde warriors.
A preview underneath shows the route your race takes under it. Your race's
starting zone is selected for you, and all races merge into a shared route
after level 12.

**Tabs.** Up to eight guides open at once, one per tab. The bar shows up to
four at a time — fewer on a narrow panel — and arrows either side (or the
mouse wheel over the bar) scroll through the rest; the tab you are on is
always brought into view. The first is your main route — what the addon
advances along on its own. Left-click a guide in the list to open it beside
what you are reading, or right-click to load it into the tab you are on; each
tab remembers its own place. Every tab can be closed; close them all and the
panel waits, empty, for you to pick one.

**Dungeons.** Toggle which of 15 dungeons you intend to run. Opting in promotes
their setup and prerequisite steps to mandatory; opting out hides them. A blue
dot marks the dungeons the guide you are currently on actually has steps for.

**Filters.** Solo or group mode, and whether Auction House steps appear.
Defaults follow the route pack you chose.

**Professions.** Ten 1–300 routes with trainers, craft counts, reagents and
recipe sources, tracked against your actual skill level. See below.

**Shopping list.** On a guide with reagents the panel's footer carries a
**Shopping list** button (or `/apg materials`). It pops out beside the guide
with what you need and what your bags already hold — `12/40 Peacebloom` —
short lines in gold, covered ones dimmed, updating as your bags change. The tab
at the top switches between **This step** (the craft you are on or coming up
to) and **Whole route** (everything still ahead, counted from where you
actually are rather than from step one, so it is the number you want at the
auction house).

With [Aegis: Exchange](https://github.com/Torchlite-bit/Aegis_Exchange)
loaded, **Send to Exchange** at the bottom of the list (or `/apg exchange`)
puts each craft still ahead on Exchange's Crafting tab, where its shopping
list prices every line at the auction house. It stays in step: finish a craft
and it leaves Exchange too; finish the route and the list is gone. **Remove
from Exchange** takes it all back out. Recipes you captured in Exchange
yourself are never touched — if one shares a name with a craft on the route,
it is set aside while the route's stands in for it and put back afterwards.
Exchange's demo mode has to be off.

**Active items and targets.** Two small windows, as RestedXP has, hang under
the guide. **Active Items** has a button for every item the guide wants you to
use — the current step's, and those for any quest in your log that is not done
yet. **Active Targets** has a button for whoever the step wants you to find: the
quest's giver or hand-in, what it wants killed, what drops what it wants
collected, the trainer a profession step sends you to. Click one to target it
and mark it — a star on a friendly NPC, a skull (then a cross) on an enemy.
`/apg target` does the same for the next one each time you press it, so a macro
with just that line works like RestedXP's; both also have key bindings under
*AEGIS: Pathfinder* in the key bindings menu. Targets come from pfQuest's
database, so quest steps need pfQuest; profession steps name their trainers
themselves. Either window can be dragged anywhere, or switched off in the
options panel.

**Automatic advancement.** Accepting, completing and turning in quests, binding
a hearthstone, and collecting tagged items all resolve themselves. So do travel
steps, once a waypoint provider is active. The checkbox wears a halo on steps
the addon can finish for you, so you know when not to reach for it.

**One step, or all of them.** The panel opens on the step you are on and
nothing else, with its note in full and a meter underneath counting whatever
the quest wants killed or collected. The expand button in the header swaps
that for the whole guide when you want to look ahead. The panel sizes itself
to what it shows; the grip in its corner sets the width, and how tall it may
grow.

**A navigation arrow.** It points at the current objective and says how far and
how long, floating on the world with no window around it. It needs a waypoint
provider; with none, or with no waypoint for this step, it hides rather than
pointing somewhere arbitrary. The **Arrow** setting picks whose arrow points at
the step: this one, the waypoint addon's (TomTom's, pfQuest's), both, or
neither. By default it is this one alone, and the waypoint addon keeps its map
pins either way.

## Professions

| Authored | |
|---|---|
| Alchemy, Blacksmithing, Cooking, Enchanting, First Aid, Jewelcrafting, Leatherworking, Mining, Survival, Tailoring | Full 1–300 routes |
| Engineering, Herbalism, Skinning, Fishing | Placeholders — see below |

Each authored guide says what to craft in each skill band and roughly how many,
the reagents (the shopping list totals what the rest of the route still
needs, and can send it to Aegis: Exchange), where the recipe comes from, and equally viable alternatives.

Every rank is a step of its own: your faction's trainers, what the rank needs
and what it costs. Primary crafts wait for the character level a rank needs
(Apprentice 5, Journeyman 10, Expert 20, Artisan 35) with a "Reach level N"
step that clears itself once you are there. With pfQuest installed the step
points the arrow at the nearest of its trainers. Cooking and First Aid do not
train Expert or Artisan: the guide sends you to buy the Expert tome, and at
skill 225 — the point the route cannot pass without it — walks you through
the Artisan quest, level 40 and what to bring included.

Steps complete themselves on the numbers the game reports: a craft or
gathering step when your skill reaches its target, a rank when your skill cap
does. Open a guide part-way through and it goes straight to where you are.

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

Tell the addon which server you are on with `/apg server`. It does not swap
in a per-server dataset — only one exists — but it will say so on the status
panel's footer when the loaded guide's data was authored somewhere else, which
is the most likely reason a waypoint points at nothing.

`/apg serverstatus` shows what is known per server, including which pfQuest
pack to use: `pfQuest-octo` for OctoWoW, the original `pfQuest-turtle` for
Capybara Paradise, and none confirmed for RavenCraft.

Reports welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

## Development

```sh
sh Tools/run_tests.sh
```

Runs everything that can be checked without a client: Lua syntax, Lua 5.0
compatibility, `.toc` and `Guides.xml` integrity, TGA validity, that every
texture path resolves to a real file, that no panel has drifted off the theme,
that every window stacks rather than interleaving with the others, and
seventeen test suites that execute the addon's own code against a stubbed 1.12 API.

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
| **shagu** | [pfQuest](https://github.com/shagu/pfQuest), pfQuest-turtle, pfQuest-octo |
| **Cladhaire**; the TWOW port by **laytya** and others | [TomTom-TWOW](https://github.com/laytya/TomTom-TWOW) |
| The authors of MetaMap, MetaMapBWP and Cartographer | Supported waypoint providers |
| **Indian Type Foundry** | Rajdhani (SIL OFL 1.1) |
| **The Inter Project Authors** | Inter (SIL OFL 1.1) |

The full list is in [CONTRIBUTORS.md](CONTRIBUTORS.md), and in game behind the
**Credits** button at the bottom of the options panel — credit should be
visible to people using the addon, not only to people reading the repository.

A fan project, not affiliated with or endorsed by Blizzard Entertainment,
Zygor Guides LLC, RestedXP, or any server team. The interface deliberately
follows conventions set by Zygor and RestedXP; no art or code from either was
used — every texture in `media/` is generated by `Tools/make_assets.py`.
