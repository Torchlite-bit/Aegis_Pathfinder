# In-game test pass

The offline checks (`sh Tools/run_tests.sh`) prove the logic against a stubbed
1.12 API. They cannot prove that a window looks right, that a texture loads,
or that the server answers the way the stub does. This list is what only a
real client can check. Run it before a release.

**How to use it.** Copy it into a GitHub issue, where the boxes can be ticked,
and work down it. For anything wrong, add a screenshot, the version (Options →
About), and what the **Error log** says (Options → Maintenance), under the item.

Start with a **full client restart** (not `/reload`): new textures and files
are only found at startup.

---

## 1. Loading

- [ ] The load message in chat names the version you installed.
- [ ] No Lua error on login (the Error log is empty).
- [ ] `/apg` and `/pathfinder` open and close the guide; `/vg` is not
      Pathfinder's any more (the client says it doesn't know it).
- [ ] The guide, the options window and the guide browser fade in as they open.
- [ ] A character that used TurtleGuide, on a fresh install with no
      Pathfinder save, keeps its progress, and chat says it was imported.
- [ ] The minimap button is the Aegis: Pathfinder logo, round, in its own
      colours, no bigger than the other buttons round the minimap; hovering
      it shows a green ring and a tooltip.
- [ ] Click toggles the guide; right-click opens the options; dragging walks it
      round the minimap and it stays there after `/reload`.

## 2. First-time setup (a new character, or `/apg setup`)

- [ ] Step 1 offers only guides with a route for your race.
- [ ] Step 2: turning **Solo Self-Found** on dims Auction House, Group quests
      and Dungeons, and they can't be clicked; off again, they come back as they
      were.
- [ ] With Dungeons on (and Self-Found off) there is a step 3; the list shows
      levels and the quests each adds; Recommended / All / None work, and
      Recommended changes with the guide picked in step 1 (RestedXP ticks
      many, Optimized few). Untick the Deadmines: the Stockade says "(+4 with
      Deadmines)"; tick it again and the count goes back up.
- [ ] Finishing a guide on RestedXP as a Human at 19 goes on to Redridge; as a
      Night Elf, to Darkshore/Ashenvale. On Optimized, finishing the 30 guide
      goes on to 30-31, and the 40 one to 40-41.
- [ ] Finish: the chat line says what was set up, and the guide reloads.

## 3. The guide

- [ ] A new character opens at step 1, not at the end.
- [ ] In a fight, Escape clears your target and the guide stays open; its ✕
      still closes it. Escape still closes the options and the guide browser.
- [ ] Loch Modan (17-18), Crocolisk Hunting: Active Targets and the
      AegisTarget macro name Loch Crocolisk, not the Wetlands or Stranglethorn
      crocolisks.
- [ ] The Macros window's AegisTarget tile, and the macro on an action bar,
      show Hunter's Mark's icon, not a blank square; AegisItem shows the quest
      item's own icon.
- [ ] Tick a few steps, then switch group mode or a dungeon chip: the ticks
      stay on the same steps, and after `/reload` too.
- [ ] Tabs: a leveling guide says XP, a profession guide or crafting route PF,
      a dungeon guide DG, a class quest guide CL, a hardcore guide HC.
- [ ] A guide opened partway -- Loch Modan (17-18) with Crocolisk Hunting in
      the log -- opens at that quest and stays there as the log updates and
      after `/reload`; it does not drop back to step 1, 0 done.
- [ ] A quest with two things to collect (Crocolisk Hunting: meat and skins)
      shows a bar for each under the step, each filled to its count (4 of 5
      is four fifths full, 4 of 6 two thirds); a finished one stays, full.
      The guide's own progress bar under the step number matches "N of M".
- [ ] The step's accent bar down the left edge runs on past the bars to the
      footer.
- [ ] A step the addon ticks itself (a quest objective, travel with a waypoint
      addon) has a small ⟳ in its circle; a note has an empty circle; a done
      step is filled, with no ⟳.
- [ ] Accepting, completing and handing in a quest ticks its steps by itself.
- [ ] Optimized Loch Modan, Bingles' tools (Bingles' Supplies): each of the
      four notes has a ⟳ and ticks when that tool is in your bags. Pick up
      one ahead of its note and it ticks as soon as the guide reaches it.
- [ ] ◀ and ▶ step back and on; the tick marks the step done.
- [ ] Click ◀ a few times, then **right-click ▶**: back at your place, with the
      steps ticked as they were. Same the other way (▶ a few times, right-click ◀).
- [ ] Right-clicking the arrow pointing away from your place says which to use.
- [ ] Hovering ◀ / ▶ mentions the right-click.
- [ ] Several tabs: open a second guide beside the first; each keeps its place.
- [ ] Finishing a guide next to a custom zone at your level asks **Where next?**
- [ ] The expand button swaps one step for the whole guide; the grip resizes it.
- [ ] **Moonwhisper Coast** (52-60, both sides): Where next? offers it from 51;
      the arrow points where each step says. Its quest data is gathered by
      players, so note any step that sends you to the wrong place, any quest
      it never mentions, and any it asks for that you can't get. In Solo mode
      its bosses and what follows them are gone; in Group mode they are back.

## 4. Arrow and waypoints

- [ ] With TomTom or pfQuest, the arrow points at the step and counts down the
      distance.
- [ ] With TomTom, a RestedXP "Travel to Kalimdor" or "Travel to Eastern
      Kingdoms" step (the Onyxia attunement guides have them) gets a pin on
      the continent's map, and TomTom's arrow and ours point at it. With
      only pfQuest there is no waypoint for the step, and nothing in chat.
- [ ] Options → Navigation → Arrows: each switch turns its arrow on and off,
      and any two or all three can point at once. With TomTom taking the
      waypoints, pfQuest's arrow still points at the step when it is on.
- [ ] pfQuest's switch off hides pfQuest's arrow altogether; `/db arrow` turns
      it back on and the switch shows it on. An addon that isn't loaded has
      its switch dimmed, and the note names it.

## 5. Options window

- [ ] Opens beside the guide; categories down the left; the page shown is
      marked and named in the strip under the title.
- [ ] Every page opens at its top; a long page (Gear) scrolls, a short one
      doesn't show a scroll bar.
- [ ] No label is cut off or crowded, on any page (Gear and Action Buttons especially).
- [ ] The pages are Route, Dungeons, Filters, Appearance, Step Display,
      Automation, Action Buttons, Navigation, Gear (Item Score under it),
      Maintenance, About; no Behaviour. Each setting that was on Behaviour is
      on its new page as it was set.
- [ ] Appearance → *Lock window* and *Transparency* do what the guide's ≡ menu
      does, and each shows what the other set.
- [ ] Automation → *All quests*: an NPC with a quest the guide does not want
      gives it, and takes a finished one; a grey quest is left; with 18
      quests in the log, nothing more is taken. Off: only the guide's.
- [ ] Automation → *Pick the guide's quest from an NPC's list* off: the list
      stays open for you; the quest you click is still accepted.
- [ ] Automation → *Take the step's flight*: on a "Fly to …" step, opening the
      flight master's map flies there. On a zone with two flight paths you
      know, it says to pick one.
- [ ] Automation → buying: on a buy step (Soothing Spices in Southshore), the
      vendor sells you what is still needed, and says so.
- [ ] The **Sell greys** button sits on the vendor window, clear of its
      title and items (with pfUI too), and sells the greys, saying for how
      much. *Sell greys automatically* does it as the window opens.
- [ ] *Repair automatically* → *With my own money* repairs at a repairing
      vendor and says the cost; not with too little money.
- [ ] Holding Shift as any of these windows opens: nothing happens by itself.
- [ ] Appearance → *Guide window opacity* changes how see-through
      Transparency makes the guide (held off while Transparency is off);
      *Guide browser opacity* fades the browser, and it fades in to that.
- [ ] *Step text size* at 140%: titles and notes bigger, rows taller, nothing
      overlapping, in focus mode and overview.
- [ ] *Show the progress bar* off: the bar goes and the steps move up.
- [ ] *Grow upward*: with the guide near the bottom of the screen, a long step
      grows it upward; drag it, reload, and its bottom edge is where you left it.
- [ ] *Hide the guide in dungeons and raids*: entering an instance hides it;
      leaving shows it again (or not, with *Show it again* off). A battleground
      leaves it alone.
- [ ] *Hide the guide in combat* (and the action buttons): gone in a fight,
      back after it; a guide you had closed stays closed.
- [ ] Step Display → *Steps shown in focus mode* 3: the step and the next two,
      under its objective meter.
- [ ] *Skip setting my hearthstone* / *Skip discovering new flight paths*: those
      steps leave the guide at once.
- [ ] *Party sync* off: no party icon; an invitation from a party member is
      declined with no popup.
- [ ] Action Buttons → *Active items grow* Left, Up, Down: the buttons run
      that way; drag the window, change it again, and it grows from the
      matching corner where you left it.
- [ ] *Button size* makes the three small windows bigger and smaller, on top
      of the window scale.
- [ ] Unticking *Talk to NPC* or *Kill enemy* takes those target buttons out;
      the AegisTarget macro still cycles them all.
- [ ] With bags full (a quiver's room doesn't count), a delete button with the
      cheapest grey appears after the items and deletes it; with no greys it
      asks first, naming the item and its price; *Keep it* keeps it.
- [ ] *Mark whoever the target buttons target* off: a target button targets
      without a raid marker; quest icons still mark on mouseover.
- [ ] Step Display → *Ask before inviting my party* off: the party icon shares
      without the popup; the popup's "don't ask again" turns it off here.
- [ ] Drag the corner grip: the window grows wider and taller, and every page
      re-lays itself without gaps; it keeps the size after `/reload`.
- [ ] `/apg resetpanels` puts it back to its first size and place.
- [ ] A dropdown left open closes when you change page or close the window.
- [ ] **Filters**: turning Solo Self-Found on holds Group mode, Auction House
      and every dungeon chip off (dimmed, unclickable), and the Dungeons page
      says why; off again, they are as they were.
- [ ] **Appearance**: each theme recolours everything at once, no reload.
- [ ] Switches follow the theme; RavenCraft's on switch is near white. Turn on
      **Red and green switches**: every switch is green when on and red when
      off, in every theme; off again, they follow the theme. It is kept after
      `/reload`.
- [ ] Drag the **Scale** slider: only its number moves while you hold it; let
      go and every window takes that size. It never jumps to 60%.
- [ ] **Route**: the preview reaches the bottom of the page; drag the window
      taller and it shows more legs.
- [ ] **Dungeons**: Turtle WoW's own dungeons have chips. Turn on *Offer
      dungeon guides along the way*, tick one at your level, and finish a
      guide: Where next? lists its dungeon guide under the custom zones, and
      it opens in a tab beside the route.
- [ ] **A dungeon at your level**: with The Deadmines or Wailing Caverns ticked
      in the setup, level up to 21 (their guides say 17-24): a small window
      offers the dungeon guide. Open puts it in a tab beside the route; Not now
      closes it, and it is not offered again after a `/reload` or relog.

## 5a. The guide browser (the `+` on the tab bar, or ≡ → Guide menu)

- [ ] It opens on HOME, beside the guide, and fades in. Its header, sidebar,
      middle and right pane line up, and the sidebar's and right pane's
      bottom corners follow the window's rounded ones.
- [ ] HOME: Guides history lists what you opened last; Suggested guides
      lists your route's next leg, a class quest, ticked dungeons and custom
      zones at your level, each with why; Level tracker counts up the level
      you are at, and See more lists every level; Gold tracker rises when you
      loot or sell, in gold, silver and copper colours, and starts again
      tomorrow.
- [ ] The ⋮ on HOME hides and shows each panel; the rest move up.
- [ ] Each category opens; Leveling's folders open into their guides
      (Optimized → Levels 20-40), and the back chevron comes back up. The
      Coming Soon rows are greyed, and say so when pointed at.
- [ ] Pointing at a guide shows it on the right. **Check the pictures load**:
      a zone guide (Optimized → Darkshore) shows Darkshore's map fully
      explored -- the areas in their places, no gaps between tiles; a city
      guide's map whole; a dungeon (The Deadmines, Scarlet Monastery) its
      loading screen, not stretched; a class quest (Voidwalker) the class
      crest in the corner, the panel in the class's colour, the spell in the
      middle; a profession its icon. Note any that are blank.
- [ ] Every custom zone (Northwind, Gilneas, Tel'Abim, Moonwhisper Coast,
      Scarlet Enclave and the rest) shows its own map, whole, with no
      glitches.
- [ ] Every dungeon shows the loading screen Turtle WoW shows on the way in,
      whole, not squashed, with no logo or bars.
- [ ] Dungeons starts with **On the routes**: Optimized's Uldaman and Sunken
      Temple (and RestedXP's Scholomance Key), each saying whose route; they
      are no longer in Optimized's Levels 40-60.
- [ ] Left-click a guide: it opens beside the route. Right-click: it loads in
      the tab you are on. Load and Open beside the route do the same. Shift-
      click resets a finished guide.
- [ ] The row's star keeps a guide in Favorites, and stays lit there; the
      arrow opens it.
- [ ] The list's ⋮: colours by level (grey outlevelled, green in range,
      yellow, orange, red), ticks on finished guides, hiding finished and
      outlevelled ones, stars on suggested ones -- each switch takes at once
      and is kept after a `/reload`.
- [ ] Typing in the search box lists the guides with that in their name;
      Escape clears it and goes back to where you were.
- [ ] CURRENT lists the guides open in the guide window, the route first;
      RECENT the ones opened lately, by category.
- [ ] The corner grip resizes it (no smaller than 820x520); the list shows
      more rows as it grows; it reopens at that size and place, on the tab or
      category it was left on.
- [ ] **Return to Main** shows in the header while a guide is open beside
      the route, and takes you back.

## 5b. The guide window's ≡ menu

- [ ] The ≡ chip opens the menu under it, above every window; Escape and any
      item but the two switches close it.
- [ ] Guide menu opens the browser; Setup wizard the setup; Settings the
      options, all beside the guide.
- [ ] Lock window: the guide cannot be dragged and its grip is gone; untick
      and both come back; kept after a `/reload`.
- [ ] Transparency: the panel's body goes see-through and its shadow goes;
      kept after a `/reload`, and it survives a theme change.
- [ ] Reset window puts the windows back, the browser at its own size.
- [ ] Reload reloads the UI.

## 5c. Class quests

- [ ] The guide browser's Class Quests lists your class's guides only, lowest
      level first.
- [ ] A Goblin warlock's **Warlock: Voidwalker (10)**: Dabbling In Darkness on
      Blackstone Island, then Gan'rul Bloodeye in Orgrimmar; an Undead's goes to
      Carendin Halgar in the Undercity. Each quest's steps tick as you go, and
      the guide finishes by itself on the last hand-in.
- [ ] On a character whose route does not take it (RestedXP or a zone guide),
      reaching a class quest's level brings **A class quest at your level**:
      Open puts the guide in a tab beside the route, and finishing it brings
      you back to the route. Not now closes it, and it is not offered again
      after a `/reload`.
- [ ] On the Optimized route, whose legs take a warlock to the Voidwalker, it
      is not offered.
- [ ] Reaching the middle of a ticked dungeon and a class quest's level at the
      same level up: the dungeon's window first, the class quest's when you
      close it.
- [ ] Options → Step Display → *Offer class quests at their level* off: nothing
      is offered.
- [ ] A chain with a dungeon or raid in it (the Charger, Rhok'delar) is offered
      only in Group mode.
- [ ] A step whose quest is inside a dungeon points the arrow at its door
      (the Charger's Scholomance step).

## 6. Gear

- [ ] Item tooltips show the item score line: `+12%` green for an upgrade,
      red for worse, *empty slot*, *not for you*.
- [ ] **Item Score** page (under Gear): the spec picker, every weight on one
      line each (no wrapped names), editing a box changes the tooltips,
      Show all stats lengthens the page, Export → Import round-trips.
- [ ] `/apg gear` opens the options at Item Score, and again closes them.
- [ ] Gear Advisor: loot an upgrade → a pop-up with Equip / Decline; Equip puts
      it on; Decline is remembered; in a fight Equip waits.
- [ ] A quest with reward choices: the best one is marked.
- [ ] Upgrades are bordered in the bags.

## 7. Gear Finder (`/apg finder`)

- [ ] The character panel has a **Gear Finder** tab after Honor (after
      Reputation's neighbour when there is no Pet tab), looking like the
      others; clicking it shows the Gear Finder over the panel, wider than
      it, with the tabs still underneath.
- [ ] Only the page's own ✕ shows at its top right, not the character
      panel's as well; back on the character sheet, the panel's ✕ is back.
- [ ] Clicking Character, or pressing C, goes back to the character sheet;
      the ✕ and Escape close the panel.
- [ ] Dragging the page moves the character panel, with or without pfUI.
- [ ] With **pfUI**: the tab is skinned like pfUI's tabs and sits in their
      row, and the page lines up with pfUI's panel.
- [ ] At a levelling character: a cell per slot with its biggest upgrade,
      the gain, where it drops, and *at level N* for one you cannot wear
      yet; *No upgrade found* with the slot's empty picture where there is
      none; *Empty slot* for a slot you wear nothing in. Long names end in
      "..." rather than running into the next line.
- [ ] Hovering a cell shows the item's tooltip.
- [ ] Clicking a cell opens its list beside it: every upgrade, biggest
      first, with the drop chance; picking one marks the cell *Your pick*,
      and **Clear my pick** undoes it. A pick survives a /reload, and goes
      once you equip the item.
- [ ] The suggested dungeon shows its loading screen, the dungeon with most
      of the cells' items, its levels and slots; the arrows step through the
      rest and go round; picks that move the most upgrades elsewhere change
      it at once. **Open the guide** opens that dungeon's guide.
- [ ] The spec dropdown changes the spec, and the cells follow. A spec with
      no dungeon to suggest keeps the dropdown, to switch back.
- [ ] Slots fill from dungeons unticked on the Dungeons page too, and from
      quest rewards (most need no level).
- [ ] Quest, reputation and crafted gear (*Quest: …*, *Revered with …*,
      *Blacksmithing 300 …*) have cells but are never the suggestion.
- [ ] Options → Gear: **Upgrade sources** has five boxes, two to a row:
      **Dungeons**, **Raids**, **Quest rewards**, **Reputation vendors**,
      **Crafted gear**, the last three ticked as their old switches were.
      Dungeons alone: only dungeon drops in the cells. Ticking Raids says in
      chat it takes a minute or two, and the cells fill in as items load.
      With nothing ticked the footer says it has nowhere to look. The cog in the footer opens the options at this
      page, whether or not they were open.
- [ ] At 60: every dungeon, Turtle's own included; Molten Core shows Turtle's
      bosses (Incindis, Basalthar).
- [ ] Walking into a dungeon names its upgrades in chat.
- [ ] Switching the Gear Finder off in the options takes the tab away.
- [ ] With Solo Self-Found on: no dungeons, and crafted gear only from your own
      professions.

## 8. Professions

- [ ] A profession guide from the guide browser advances on your skill.
- [ ] **Shopping list** (`/apg materials`): counts what your bags hold, and
      **This step** / **Whole route** switch.
- [ ] **Cheapest route** (`/apg craft`): plans, **Scan prices** at the auction
      house fills prices in, **Load as guide** adds the planned guide.
- [ ] With Aegis: Exchange loaded: **Send to Exchange** puts the crafts on its
      Crafting tab, and Remove takes them back out.

## 9. Quest helpers

- [ ] **Active Items**: a button for the step's quest item; clicking uses it.
- [ ] **Active Targets**: a button for the step's NPC or mob; clicking targets
      and marks it.
- [ ] Quest icons: mousing over a quest NPC or mob puts the right raid marker
      on it (star to talk, skull to kill, cross to loot, square to interact).
- [ ] **Macros**: AegisTarget and AegisItem appear in your character macros and
      follow the guide from an action bar.
- [ ] With several of a step's mobs around (Crocolisk Hunting), AegisTarget
      takes the nearest, each press after it the next one out, then back to
      the nearest; a dead one is skipped; targeting something else first, the
      next press starts at the nearest again.

## 10. Party sharing

- [ ] In a party, the party icon asks to share; your partner gets a pop-up and
      the guide opens in a new tab.
- [ ] Each of you shows under the step with your progress; a finished step
      waits for the other.
- [ ] Leaving the group stops sharing.

## 11. The rest

- [ ] Options → About → **Credits** opens beside the options and closes with
      them.
- [ ] Options → Maintenance: **Rescan progress**, **Error log**, **Run setup**.
- [ ] The slash commands in the README all do what they say.
