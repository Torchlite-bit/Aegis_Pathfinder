# Licensing status — read before distributing a build

AEGIS: Pathfinder is a derivative work. This file records what was found when
its provenance was traced, what is unresolved, and what has to happen before a
release is published.

**Status: permission granted by brues-code; not yet published.**

The repository owner reports that brues-code has given permission to build on
and publish VanillaGuide+. That clears the blocker this file was opened for.
Development continues; no release is planned yet, so the remaining items below
stay open rather than urgent.

> **To complete the record:** add a link to where permission was given (issue,
> comment or message) and, if brues-code named a licence, which one. A durable
> reference matters more than the fact being true — it is what a future
> contributor or a package host will ask for.

## What was traced

The repository lineage, newest first:

| Project | Licence |
|---|---|
| `Torchlite-bit/Aegis_Pathfinder` (this repo) | MIT, © 2026 Torchlite |
| `Torchlite-bit/Aegis_Pathfinder_Plus` (fork) | **none** |
| `brues-code/VanillaGuide-Plus` | **none** |
| `NostalgiaGeek/VanillaGuide-Plus` | **none** |
| `isalcedo/VanillaGuide` | **none** |
| `TekNoLogic/TourGuide` (Tekkub) | **none** in the repository |

None of these repositories contains a `LICENSE`, `COPYING` or `NOTICE` file,
and none of their READMEs states licence terms. The Ace2 libraries vendored
under `libs/` carry authorship headers but no licence text either.

This was checked against the repositories themselves in September 2026. A web
search additionally reported TourGuide as "All Rights Reserved" on CurseForge;
that could not be confirmed directly, because CurseForge is blocked by the
egress proxy in the environment this work was done in. **Treat the CurseForge
detail as unverified.** The GitHub finding — no stated licence anywhere in the
chain — was verified directly and is the part that matters.

## Why this mattered

The decision originally taken for this project was "match upstream's licence".
That could not be carried out, because **upstream granted no licence at all**.

Absent an explicit grant, copyright defaults to all rights reserved. The
default is not permissive:

- Nobody in this chain has been given the right to redistribute the code, or
  to publish modified versions of it.
- The MIT licence currently in this repository cannot be applied to the ported
  code. MIT is a grant, and only a copyright holder can make one. Torchlite
  holds copyright in Torchlite's own contributions, not in Tekkub's, isalcedo's,
  NostalgiaGeek's or brues-code's.
- This is not a copyleft problem, which would have a clean remedy (adopt the
  same copyleft licence). It is an absence-of-permission problem, and the only
  remedy is to obtain permission.

None of this stops development. It stops *distribution*.

## Resolution

brues-code granted permission. The fork stays a fork: the single-addon
architecture and the AEGIS: Pathfinder naming both stand, and the
companion-addon fallback described below is no longer needed. It is kept on
record because it remains the route that needs nobody's permission, should the
position ever change.

The request that was drafted for this is kept at
[docs/upstream-license-request.md](docs/upstream-license-request.md) — it is
now historical, but its second half is still worth acting on: the two
load-breaking defects it lists are fixed on a branch here and worth offering
upstream, along with the parser extensions the profession guides needed.

**Still open, and worth settling before a public release rather than now:**

- Permission covers brues-code's own work. The earlier links in the chain —
  NostalgiaGeek, isalcedo, Tekkub — have not been asked, and none of them
  licensed their code either. In practice brues-code's say-so is what most
  people in this community would act on, and how much original TourGuide code
  survives in the current tree is an open question, likely "not much". Worth
  establishing before publishing, not before continuing to build.
- A `LICENSE` that reflects the grant. The MIT file currently in this
  repository was written before any of this was traced and should be replaced
  or confirmed once brues-code's preferred terms are known.

## What has to happen before a release

1. ~~Ask upstream to license their work.~~ **Done** — permission granted.
2. **Record where permission was given**, so the grant is verifiable by someone
   who was not in the conversation.
3. **Settle the rest of the chain** — NostalgiaGeek, isalcedo, Tekkub — or
   establish how little of their code survives. Not blocking development.
4. **Choose a `LICENSE`** consistent with the grant, replacing or confirming
   the MIT file currently here.
5. **Add `media/fonts/OFL.txt`** (see below). Small, easy to forget, and
   genuinely required once fonts are redistributed.

Until those are settled, do not push a `v*` tag: `.github/workflows/release.yml`
packages and publishes a release on one.

## Guide content

Separate from the code, and also unresolved.

The leveling routes are credited to **Joana's Vanilla WoW Guides**, which are a
commercial product sold at joanasworld.com. Route content derived from a paid
guide raises its own permission question, independent of the addon code.
`Guides/Optimized/` additionally credits **mrmr**. The RestedXP route packs
derive from **RestedXP Guides**, also a commercial product.

The professions reference converted in `Guides/Professions/` was supplied by
the repository owner; its own provenance is not recorded anywhere in this
repository and should be, before release.

## Font licensing

`media/fonts/` bundles Rajdhani and Inter, both under the SIL Open Font Licence
1.1. The OFL requires the full licence text to accompany redistributed font
files, and `media/fonts/OFL.txt` is **missing**: the text could not be
retrieved here, because `openfontlicense.org` and `scripts.sil.org` are both
blocked by the egress proxy, and writing a legal text from memory risks an
inaccurate one.

Download `OFL.txt` from <https://openfontlicense.org> and place it in
`media/fonts/` before distributing a build. This one is trivially fixable and
should not be forgotten just because the larger question above is open.

## Fallback, no longer needed: ship as a companion addon

Retained for the record. Permission has been granted, so this is not the route
being taken — but it is the one that needs nobody's permission, because it
redistributes none of upstream's code: ship only what is original to this
project and skin VanillaGuide+ at runtime rather than modifying it, with the
user installing VanillaGuide+ themselves.

What is already original and could ship as-is:

| | |
|---|---|
| `Theme.lua`, `Professions.lua`, `Servers.lua`, `Credits.lua` | ~770 lines |
| `Guides/Professions/` | 14 guides |
| `media/` | 33 generated textures (excluding the two inherited) |
| `Tools/` | converters, verifier, API stub, tests |

What would have to change, being modifications to upstream files rather than
additions:

- The frame reskin becomes runtime skinning. `TurtleGuide.statusframe` and
  `TurtleGuide.objectiveframe` are globals, so a companion addon can restyle
  them after load, which is how skinning addons generally work.
- The profession guides move from QuestShell+ tables to the pipe DSL, and
  register through the public `RegisterGuide`. This matters because
  `stepToTagString` is a `local` in `QuestShellPlusParser.lua` and so cannot be
  hooked from outside; `GetObjectiveTag` lives on the addon table and can be
  wrapped, which is all the trade-skill tags actually need.

This is more robust against upstream changes than a fork, at the cost of
depending on their internals and asking users to install two addons.

## What is not blocked

Everything except distribution. Developing, testing, running the addon
locally, and pushing to this repository are all unaffected.
