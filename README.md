# Aegis: Pathfinder (v0.5.0)

**A levelling guide for 1.12 servers in the Turtle WoW family** — Turtle WoW,
OctoWoW, Capybara Paradise and RavenCraft. Part of the Aegis addon suite.

Your next objective on screen, an arrow pointing at it, and a guide that moves
on by itself as you accept, complete and turn in quests: the Zygor and RestedXP
experience, on a client older than both.

> **In development.** Not released yet.

<!-- IMAGE: the guide window in game, with the arrow -->

## What you get

- **Guides that follow you.** 1–60 for every race: Optimized (Joana's routes),
  RestedXP, RXP Hardcore, and Kamisayo Speedrun for Horde warriors. Steps tick
  themselves off, and a short setup on your first login picks your guide.
- **An arrow to every objective**, with waypoints through TomTom or pfQuest.
- **Filters that fit how you play.** Solo or group, Auction House steps on or
  off, Solo Self-Found, and only the dungeons you mean to run.
- **Gear.** An item score on every tooltip; a Gear Advisor that offers upgrades
  as you loot them and marks the best quest reward; a Gear finder that lists
  the upgrades waiting in your dungeons.
- **Fourteen professions, 1–300**, with trainers, reagents and a shopping list —
  and the cheapest route to 300 at today's auction house prices.
- **Quest helpers.** Buttons for the step's quest items and targets, raid marks
  on the mobs your quests want, and macros that follow the guide.
- **Play together** (beta). Share a guide with your party; a finished step
  waits for everyone.
- **Your server's colours.** Themes for Turtle WoW, OctoWoW, RavenCraft and
  Capybara Paradise, plus Day and Night.

<!-- IMAGE: an item tooltip with the item score, and the Gear Advisor pop-up -->

<!-- IMAGE: the options window, with its pages down the left -->

Every feature in detail: [docs/FEATURES.md](docs/FEATURES.md).

## Install

1. Install **[ClassicAPI](https://github.com/brues-code/ClassicAPI) v1.5.9 or
   newer**. It is required; the addon will not load without it.
2. Put the addon in `Interface/AddOns/`, in a folder named `Aegis_Pathfinder`.
3. Restart the client.

Recommended: [TomTom-TWOW](https://github.com/laytya/TomTom-TWOW) for
waypoints, and [pfQuest](https://github.com/shagu/pfQuest) with your server's
database (`pfQuest-turtle`, or `pfQuest-octo` on OctoWoW) for quest givers and
targets.

Coming from TurtleGuide or VanillaGuide+? Your progress carries over.

## Commands

| | |
|---|---|
| `/apg` | Open the guide |
| `/apg setup` | Run the first-time setup again |
| `/apg gear` | Stat weights behind the item score |
| `/apg finder` | Upgrades in the dungeons you run |
| `/apg craft` | Cheapest route to 300 in a profession |
| `/apg share` | Share your guide with your party |
| `/apg ssf` | Solo Self-Found on or off |

Right-click the shield on the minimap for the options. `/pathfinder` works
too. [All commands](docs/FEATURES.md#commands).

## Something broken?

1. Check the **version** in the load message or the options window's About page (`v0.5.0`) — quote it.
2. Open the **Error log** (options → Maintenance) and copy what it shows.
3. Say which guide and step you were on, and which server you play on.

What changed between versions: [CHANGELOG.md](CHANGELOG.md).

## Credits

Built on other people's work: [TourGuide](https://github.com/TekNoLogic/TourGuide)
by **Tekkub**, [VanillaGuide](https://github.com/isalcedo/VanillaGuide) by
**isalcedo**, [VanillaGuide-Plus](https://github.com/brues-code/VanillaGuide-Plus)
by **NostalgiaGeek**, **Brues** and **DonutsDelivery**, and
[ClassicAPI](https://github.com/brues-code/ClassicAPI) by **Brues**. Routes by
**[Joana](https://www.joanasworld.com/)**, **mrmr**, and **RestedXP** (Tactics
and Zeroji). Data from [pfQuest](https://github.com/shagu/pfQuest) (**shagu**),
[CraftRoute](https://github.com/Kitymeowmeow-turt/CraftRoute) (**Kitymeowmeow**),
[OctoPawn](https://github.com/iGreed1993/OctoPawn) (**iGreed**) and
[CMaNGOS](https://github.com/cmangos/classic-db).

Everyone is listed in [CONTRIBUTORS.md](CONTRIBUTORS.md), and in game under
options → About → **Credits**.

A fan project, not affiliated with or endorsed by Blizzard Entertainment, Zygor
Guides LLC, RestedXP, or any server team. The interface follows conventions set
by Zygor and RestedXP; no art or code from either was used.

## Licence

GNU General Public License v3.0 — see [LICENSE](LICENSE). The item score's
weights come from OctoPawn under its MIT licence, carried in
`ItemScoreData.lua`; the Ace2 libraries and the fonts keep their own licences
(see [media/README.md](media/README.md)).

## Contributing

[CONTRIBUTING.md](CONTRIBUTING.md) covers the checks, the code rules and
versions; [docs/GUIDE_AUTHORING.md](docs/GUIDE_AUTHORING.md) covers writing
guides.
