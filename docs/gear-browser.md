# Gear Finder dungeon browsing and raid availability

Open the Gear Finder and use the selector above the dungeon picture. **Suggested dungeons** preserves the original ranking based on the recommended items in your gear slots. Selecting a named dungeon/raid browses the full catalog, including places with no recommended items. Use the mouse wheel over the open menu to reach more entries; the arrows also browse the catalog while a named dungeon is selected.

In browse mode, the count includes all unique upgrades found in that dungeon under the current scoring settings, not only the biggest upgrade in each slot. Click the count for the item list and hover an item for its tooltip. A searched dungeon with no upgrades shows zero. Places excluded by level, faction or source settings say **Not searched (filters / level)**, rather than claiming there are no upgrades. Browsing does not change those filters or evaluate gear above their limits.

The dungeon selector puts the biggest available upgrade first, using percentage gain, then raw score gain to break ties. Places without a found, eligible upgrade remain below those with upgrades, alphabetically. Dungeon item popups use the same biggest-gain-first order while preserving each item's equipment slot and pick behavior. Empty slots use the finder's existing empty-slot worth.

Under **Settings > Gear > Available raids**, select which raids your server has released. All raids default available to preserve existing searches; disable **Ruins of Ahn'Qiraj (AQ20)**, **Temple of Ahn'Qiraj (AQ40)** or **Naxxramas** if your server has not released them. Every catalog raid has its own checkbox. The main **Raids** upgrade source must also be enabled to search raids. Choices are saved per character and can be changed as content releases. Unavailable raids remain in the browser, labeled **Unavailable on this server**, but are excluded from gear searches.

Known raid hand-in quests obey availability too: T3 and the included Naxx raid hand-ins require Naxx; T2.5 and Imperial Qiraji hand-ins require AQ40; AQ20 set hand-ins and the Ossirian turn-in require AQ20. Ordinary quest rewards stay enabled. These checks use explicit quest IDs verified in GearData, not broad reputation-faction exclusions. Enabling a raid restores its quest rewards when the **Quest rewards** source is enabled, independently of the boss-drop **Raids** source.

Verification: the gear finder, item score and options suites cover these changes. Check the selector's mouse-wheel behavior, item popup and raid checkboxes in game after reloading. No new addon dependency or TOC file was added.

Legendary and higher-quality items are excluded from upgrade suggestions across dungeon, quest, reputation and crafting sources. Both cached metadata and the loaded client item quality are checked; epic and lower-quality upgrades remain eligible. This excludes temporary quest weapons such as Andonisus without changing item scoring/tooltips or equipped-item comparisons.

When AtlasLoot is installed, its registered dungeon, raid and world-boss loot augments the bundled catalog. Existing items use AtlasLoot boss names and drop rates; unlisted items keep bundled sources. AtlasLoot remains optional and its files are not modified. Pathfinder scores also appear on AtlasLoot's item and comparison tooltips.

The integration targets [Otari98/AtlasLoot](https://github.com/Otari98/AtlasLoot). Offline import checks cover the installed 4.0.3 database and version 4.1.0 at commit `248f2b44a0edfb62a15a59ae91c584e946976bac`: 5,189 loot-source rows, including Incindis, Ezzel Darkbrewer and world bosses, with explicit AQ/Naxx availability choices preserved. Tooltip frames are `AtlasLootTooltip` and `AtlasLootTooltip2`. These checks do not replace an in-game visual check.
