# Changelog

All notable changes to **Aegis: Pathfinder**.

Format loosely follows [Keep a Changelog](https://keepachangelog.com/).
The version here matches `## Version` in `Aegis_Pathfinder.toc` and the number
in the load message and the options panel's About section — quote it in bug
reports.

> ⚠️ Releases marked **restart** add or remove a `.lua` file. WoW 1.12 reads the
> file list at startup, so `/reload` won't pick them up — you need to fully
> restart the client. Everything else is `/reload`-safe.

> **One push, one MINOR.** A body of work that lands in one merge takes a
> single MINOR bump, and every change inside it — each phase, each fix found
> along the way — is a PATCH under it. The MINOR moves again at the next body
> of work, not at the next feature within this one.

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

[0.1.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
