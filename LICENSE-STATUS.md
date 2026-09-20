# Licensing status — read before distributing a build

AEGIS: Pathfinder is a derivative work. This file records what was found when
its provenance was traced, what is unresolved, and what has to happen before a
release is published.

**Summary: do not publish a release yet.** The code this addon is built from
carries no licence at any point in its chain, so nobody has yet granted the
right to redistribute it — under this name or any other.

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

## Why this is a problem

The decision taken for this project was "match upstream's licence". That
instruction cannot be carried out, because **upstream grants no licence at
all**.

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

## Decision

Ask upstream first, before restructuring anything. A drafted issue is ready at
[docs/upstream-license-request.md](docs/upstream-license-request.md) — it needs
to be posted by the repository owner, under their own name, on
<https://github.com/brues-code/VanillaGuide-Plus>.

The project keeps its AEGIS: Pathfinder naming. Renaming would not have changed
the position anyway: what a work is called is a trademark question, while
redistribution is a copyright one.

If upstream declines or does not reply, the fallback is the companion-addon
route below, which needs no permission because it redistributes none of their
code.

## What has to happen before a release

1. **Ask upstream to license their work.** Post the drafted issue. Many addon
   authors simply never got round to a licence and will say yes.
2. **Trace consent back through the chain** as far as is reachable —
   NostalgiaGeek, isalcedo, and Tekkub. Tekkub's TourGuide is the oldest link
   and the least likely to respond; if it cannot be resolved, get advice on how
   much original TourGuide code actually survives in the current tree, since
   the answer may be "very little".
3. **Then choose a licence** consistent with whatever permission is obtained,
   and replace the MIT `LICENSE` in this repository if MIT is not it.
4. **Until then**, keep the work on a branch and do not publish a packaged
   release, a CurseForge listing, or a tagged version. The
   `.github/workflows/release.yml` packager triggers on `v*` tags — do not push
   one.

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

## Fallback: ship as a companion addon

If permission does not come, the work can be published without it — by shipping
only what is original to this project and skinning VanillaGuide+ at runtime
rather than modifying it. The user installs VanillaGuide+ themselves.

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
