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
- [ ] The minimap button is the Aegis: Pathfinder logo, round, in its own
      colours; hovering it shows a green ring and a tooltip.
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
      still closes it. Escape still closes the options and the guide list.
- [ ] Loch Modan (17-18), Crocolisk Hunting: Active Targets and the
      AegisTarget macro name Loch Crocolisk, not the Wetlands or Stranglethorn
      crocolisks.
- [ ] The Macros window's AegisTarget tile, and the macro on an action bar,
      show Hunter's Mark's icon, not a blank square; AegisItem shows the quest
      item's own icon.
- [ ] Tick a few steps, then switch group mode or a dungeon chip: the ticks
      stay on the same steps, and after `/reload` too.
- [ ] Tabs: a leveling guide says XP, a profession guide or crafting route PF,
      a dungeon guide DG, a hardcore guide HC.
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
- [ ] No label is cut off or crowded, on any page (Gear, Behaviour especially).
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

## 7. Gear finder (`/apg finder`)

- [ ] At a levelling character: upgrades from the dungeons at your level, each
      with who drops it, where, and the chance — and quest, reputation and
      crafted gear (*Quest: …*, *Revered with …*, *Blacksmithing 300 …*).
- [ ] The note names up to four places and counts the rest, without running
      over the list.
- [ ] Turning **Include raids** on says in chat it takes a minute or two; the
      list fills in as items load.
- [ ] At 60: every dungeon, Turtle's own included; Molten Core shows Turtle's
      bosses (Incindis, Basalthar).
- [ ] Walking into a dungeon names its upgrades in chat.
- [ ] Options → Gear: switching off quest, reputation or crafted gear removes
      them from the list.
- [ ] With Solo Self-Found on: no dungeons, and crafted gear only from your own
      professions.

## 8. Professions

- [ ] A profession guide from the guide list advances on your skill.
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
