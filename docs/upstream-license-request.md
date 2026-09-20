# Draft: licence request to upstream

Post this as an issue on <https://github.com/brues-code/VanillaGuide-Plus>.
It is written to go out under your name. Edit freely — the tone matters more
than the wording, and it should sound like you.

Why this exists: nothing in the lineage carries a licence, so the right to
redistribute has never been granted. See [../LICENSE-STATUS.md](../LICENSE-STATUS.md).
A release is blocked until this is resolved, though development is not.

**Suggested title:** `Would you consider adding a LICENSE file?`

---

Hi — first off, thanks for VanillaGuide+. The ClassicAPI work in particular is
what makes proper automatic step advancement possible on a 1.12 client at all,
and it's been a pleasure to build on.

I've forked it and have been working on a reskin plus a set of profession
guides (1–300 routes with trainers, craft counts and reagents, tracked against
your actual skill level). Before I put any of that in front of other people I
wanted to sort out licensing, and I noticed the repo doesn't have a `LICENSE`
file.

I went back through the lineage and it looks like the same is true further up —
neither isalcedo's VanillaGuide nor Tekkub's TourGuide states terms either. So
I don't think this is anything deliberate on your part, just something nobody
has got round to. But without a licence, the default is all rights reserved,
which means I don't actually have permission to publish a fork.

**Would you be willing to add one?** Anything permissive or copyleft works for
me — MIT and GPLv3 are both common for WoW addons, and I'd happily match
whichever you prefer. If you'd rather not decide for the whole lineage, even a
note in the README saying forks are welcome would be enough for me to work
with.

If the answer is no, or if you'd rather leave it alone, that's genuinely fine
and I won't push it. I'd just restructure my work as a companion addon that
requires VanillaGuide+ to be installed separately, so I'm not redistributing
your code at all.

Either way, credit is already in place: your work, isalcedo's, Tekkub's,
Joana's routes, shagu's pfQuest and the Ace2 authors are all credited in a
`CONTRIBUTORS.md` and in an in-game credits panel. Happy to word any of it
however you'd like.

One other thing that might be useful to you regardless: while working on this I
found two things in the current tree that look like bugs rather than choices.

- `Guides/RXP/Alliance/Guides.xml` and `Guides/RXP/Horde/Guides.xml` between
  them reference 56 guide files that don't exist in the repo — WotLK-era names
  like `Chilled_Meat_Sholazar_Basin_34a.lua` and `Dire_Maul_Key.lua` that came
  in with the RXP converter commit but were never produced. A missing
  `<Script file>` is a load error, so I think this is breaking the RXP route
  packs.
- `RXPConverter.lua:124` uses `continue`, which isn't a keyword in any version
  of Lua, so that file has never parsed.

I have fixes for both on a branch and I'm glad to open a PR if it'd help —
along with the parser extensions the profession guides needed, if you want
them upstream.

Thanks either way.

---

## If there's no reply

Give it a couple of weeks. Silence is not consent, so if nothing comes back,
the companion-addon restructure described in `LICENSE-STATUS.md` is the route
that doesn't need an answer.

It may also be worth trying the other links in the chain, in rough order of
likely responsiveness: NostalgiaGeek, then isalcedo, then Tekkub. Tekkub's
TourGuide is old enough that it may be worth asking how much original TourGuide
code actually survives in the current tree before chasing it — the answer may
well be "not much".
