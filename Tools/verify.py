#!/usr/bin/env python3
"""Offline verification for AEGIS: Pathfinder.

Checks what can be checked without a WoW client:

  syntax   every Lua file parses
  lua50    no Lua 5.1-only constructs that would fail on the 1.12 client
  toc      every file the .toc loads exists, in order
  xml      every Guides.xml lists files that exist, and lists all of them
  theme    no Blizzard chrome or stock icon art on a themed panel
  scope    no bare `Theme` in a file that never declares one
  media    every texture is a TGA the 1.12 client can load
  textures every path Theme.lua hands the client resolves to a real file

Run from the repository root:  python3 Tools/verify.py
Exits non-zero if any check fails.
"""

import os
import re
import struct
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUAC = "luac5.1"

# Vendored Ace2 libraries are upstream code we do not police.
SKIP_DIRS = {".git", "libs", ".release"}


def walk(exts, skip=SKIP_DIRS):
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in skip]
        for fn in filenames:
            if os.path.splitext(fn)[1] in exts:
                yield os.path.join(dirpath, fn)


def rel(path):
    return os.path.relpath(path, ROOT)


class Report:
    def __init__(self):
        self.failures = []
        self.counts = {}

    def ok(self, check, n):
        self.counts[check] = n

    def fail(self, check, path, detail):
        self.failures.append((check, rel(path) if path else "-", detail))

    def summary(self):
        for check, n in self.counts.items():
            print("  %-8s %d passed" % (check, n))
        if not self.failures:
            print("\nAll checks passed.")
            return 0
        print("\n%d failure(s):\n" % len(self.failures))
        for check, path, detail in self.failures:
            print("  [%s] %s\n      %s" % (check, path, detail))
        return 1


def check_syntax(rep):
    files = sorted(walk({".lua"}))
    for path in files:
        proc = subprocess.run([LUAC, "-p", "-o", os.devnull, path],
                              capture_output=True, text=True)
        if proc.returncode != 0:
            rep.fail("syntax", path, proc.stderr.strip().splitlines()[0])
    rep.ok("syntax", len(files))


# Constructs that parse under 5.1 but are absent from the 5.0 runtime in the
# 1.12 client. Each is (regex, explanation, replacement to use instead).
LUA50_BANNED = [
    (re.compile(r"[^%\w]#[A-Za-z_({\"']"), "# length operator", "table.getn() / string.len()"),
    (re.compile(r"\bstring\.gmatch\b|:gmatch\("), "string.gmatch", "string.gfind()"),
    # Bare select() only. AegisPathfinder.select is the addon's own 5.0-safe
    # shim, so a qualified call is fine.
    (re.compile(r"(?<![.:\w])select\s*\(\s*[\"'#]"), "select()", "explicit named parameters"),
    (re.compile(r"\bmodule\s*\("), "module()", "a plain global table"),
    (re.compile(r"\b\d+//\d+"), "// integer division", "math.floor(a/b)"),
]


def pkgmeta_ignored():
    """Paths .pkgmeta excludes from the packaged addon.

    These are desktop-side tooling (converters, docs, task notes) that run on a
    normal Lua/Python install and never reach the 1.12 client, so the Lua 5.0
    restrictions do not apply to them.
    """
    path = os.path.join(ROOT, ".pkgmeta")
    if not os.path.exists(path):
        return set()
    body = open(path, encoding="utf-8").read()
    block = re.search(r"^ignore:\s*\n((?:\s+-\s+\S+\n?)+)", body, re.M)
    if not block:
        return set()
    return {m.strip() for m in re.findall(r"-\s+(\S+)", block.group(1))}


def is_shipped(path):
    relative = rel(path)
    for ignored in pkgmeta_ignored():
        if relative == ignored or relative.startswith(ignored.rstrip("/") + os.sep):
            return False
    return True


def _scan_lua(src, keep_strings):
    """Blank out Lua comments, and optionally string literals, in one pass.

    Comments and strings have to be recognised together: a `--` inside a
    string is not a comment, and a quote inside a comment is not a string.
    Stripping them in two separate regex passes got that wrong -- a message
    reading "open -- close one" lost its closing quote to the comment pass,
    and the string pass then ran on across the following lines.

    Newlines are always kept, so a failure still points at the right line.
    """
    out = []
    i, n = 0, len(src)

    def long_bracket(at):
        # "[[", "[=[", ... -> the matching closer, or None if not a long bracket
        m = re.match(r"\[(=*)\[", src[at:])
        return ("]" + m.group(1) + "]", len(m.group(0))) if m else (None, 0)

    def blank(text):
        return "".join(c if c == "\n" else " " for c in text)

    while i < n:
        c = src[i]
        if src.startswith("--", i):
            closer, width = long_bracket(i + 2)
            if closer:
                end = src.find(closer, i + 2 + width)
                end = n if end < 0 else end + len(closer)
            else:
                end = src.find("\n", i)
                end = n if end < 0 else end
            out.append(blank(src[i:end]))
            i = end
        elif c == "[" and long_bracket(i)[0]:
            closer, width = long_bracket(i)
            end = src.find(closer, i + width)
            end = n if end < 0 else end + len(closer)
            out.append(src[i:end] if keep_strings else '""' + blank(src[i:end])[2:])
            i = end
        elif c in "\"'":
            j = i + 1
            while j < n and src[j] != c and src[j] != "\n":
                j += 2 if src[j] == "\\" else 1
            end = min(j + 1, n)
            out.append(src[i:end] if keep_strings else c + c + blank(src[i + 2:end]))
            i = end
        else:
            out.append(c)
            i += 1
    return "".join(out)


def strip_lua_comments(src):
    """Blank out comments, keeping string literals."""
    return _scan_lua(src, keep_strings=True)


def strip_lua_noise(src):
    """Blank out comments and string literals so we only scan real code.

    Use this for checks about Lua syntax. Anything looking for a texture path
    or a frame template name must read the strings, so it wants
    strip_lua_comments instead -- see check_theme.
    """
    return _scan_lua(src, keep_strings=False)


def check_lua50(rep):
    files = [p for p in sorted(walk({".lua"})) if is_shipped(p)]
    for path in files:
        code = strip_lua_noise(open(path, encoding="utf-8", errors="replace").read())
        for lineno, line in enumerate(code.splitlines(), 1):
            for pattern, what, instead in LUA50_BANNED:
                if pattern.search(line):
                    rep.fail("lua50", path,
                             "line %d uses %s (1.12 is Lua 5.0 -- use %s)"
                             % (lineno, what, instead))
    rep.ok("lua50", len(files))


def toc_entries(toc_path):
    for raw in open(toc_path, encoding="utf-8", errors="replace"):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        yield line.replace("\\", os.sep)


def check_toc(rep):
    tocs = sorted(walk({".toc"}))
    if not tocs:
        rep.fail("toc", None, "no .toc file found")
        return
    n = 0
    for toc in tocs:
        # WoW requires Interface/AddOns/<Folder>/<Folder>.toc -- the packager
        # supplies the folder name, so the .toc basename must match package-as.
        pkg = os.path.join(ROOT, ".pkgmeta")
        if os.path.exists(pkg):
            m = re.search(r"^package-as:\s*(\S+)", open(pkg).read(), re.M)
            if m and m.group(1) != os.path.splitext(os.path.basename(toc))[0]:
                rep.fail("toc", toc, "basename must match .pkgmeta package-as (%s)" % m.group(1))
        for entry in toc_entries(toc):
            target = os.path.join(os.path.dirname(toc), entry)
            if not os.path.exists(target):
                rep.fail("toc", toc, "missing file: %s" % entry)
            n += 1
    rep.ok("toc", n)


def check_xml(rep):
    n = 0
    for xml in sorted(walk({".xml"})):
        body = open(xml, encoding="utf-8", errors="replace").read()
        listed = set(re.findall(r'<Script\s+file="([^"]+)"', body))
        folder = os.path.dirname(xml)
        for entry in sorted(listed):
            if not os.path.exists(os.path.join(folder, entry)):
                rep.fail("xml", xml, "lists missing file: %s" % entry)
            n += 1
        # A guide file nobody lists never loads -- silent content loss.
        on_disk = {f for f in os.listdir(folder) if f.endswith(".lua")}
        for orphan in sorted(on_disk - listed):
            rep.fail("xml", xml, "file on disk is not listed: %s" % orphan)
    rep.ok("xml", n)


# Blizzard chrome the reskin replaced. Any of these creeping back means a panel
# has drifted off the theme, which is invisible until someone loads the client.
BLIZZARD_CHROME = [
    (re.compile(r"\bSetBackdrop\s*\("), "SetBackdrop -- use Theme:Panel or Theme:Strip"),
    (re.compile(r"TooltipBorderBG"), "TooltipBorderBG -- use Theme:Panel"),
    (re.compile(r"Interface\\\\DialogFrame"), "Blizzard dialog art -- use Theme:Panel"),
    (re.compile(r"Interface\\\\Buttons\\\\UI-CheckBox"), "Blizzard checkbox -- use Theme:StepCheck"),
    (re.compile(r"Interface\\\\Buttons\\\\UI-Panel-Button"), "Blizzard button art -- use the themed button"),
    (re.compile(r"SetFontObject\s*\(\s*GameFont"), "GameFont object -- use Theme:SetFont"),
    # Templates pull in the same art by name rather than by path, which is how
    # every panel in the addon kept its Blizzard chrome through the first
    # reskin pass: the palette changed underneath, the buttons did not.
    (re.compile(r'"UIPanelButtonTemplate"'), "UIPanelButtonTemplate -- use Theme:PanelButton"),
    (re.compile(r'"UIPanelCloseButton"'), "UIPanelCloseButton -- use Theme:CloseChip"),
    (re.compile(r'"OptionsButtonTemplate"'), "OptionsButtonTemplate -- use Theme:PanelButton"),
    (re.compile(r'"UIPanelScroll(Up|Down)ButtonTemplate"'), "Blizzard scroll button -- use Theme:ScrollBar"),
    (re.compile(r"Interface\\\\Buttons\\\\UI-ScrollBar"), "Blizzard scrollbar art -- use Theme:ScrollBar"),
    # Stock icon art: bevelled, bordered, and a different palette to the
    # generated glyphs in media/icons.
    (re.compile(r"Interface\\\\Icons\\\\"), "Blizzard icon art -- use Theme.actionIcon / Theme.glyph"),
    (re.compile(r"Interface\\\\GossipFrame\\\\"), "Blizzard gossip art -- use Theme.actionIcon"),
]

# WidgetWarlock keeps TooltipBorderBG as public API for guides written against
# it. Its scrollbar is Theme:ScrollBar now, so nothing else here is exempt.
CHROME_EXEMPT = {"WidgetWarlock.lua"}


def check_theme(rep):
    files = [p for p in sorted(walk({".lua"}))
             if is_shipped(p) and os.path.basename(p) not in CHROME_EXEMPT]
    for path in files:
        # Comments only: every pattern here names a texture path or a frame
        # template, and both live inside string literals. Scanning the
        # string-blanked source made this check silently vacuous, which is how
        # a reskinned addon kept drawing Blizzard buttons and quest icons.
        code = strip_lua_comments(open(path, encoding="utf-8", errors="replace").read())
        for lineno, line in enumerate(code.splitlines(), 1):
            for pattern, why in BLIZZARD_CHROME:
                if pattern.search(line):
                    rep.fail("theme", path, "line %d uses %s" % (lineno, why))
    rep.ok("theme", len(files))


# A bare `Theme` only works in a file that declares `local Theme`: there is no
# global of that name, and Core.lua loads before Theme.lua so it could not have
# one anyway. Three buttons in Core.lua were written as Theme:PanelButton and
# failed on first use, aborting the route and starting-zone dialogs half-built.
BARE_THEME = re.compile(r"(?<![.\w])Theme\s*[:.]")
# Top level only: a `local Theme` inside one function does nothing for the
# rest of the file, and letting it exempt the whole file is how this check
# first passed over the very bug it was written for.
LOCAL_THEME = re.compile(r"^local\s+Theme\s*=", re.M)


def check_theme_scope(rep):
    files = [p for p in sorted(walk({".lua"})) if is_shipped(p)]
    for path in files:
        src = open(path, encoding="utf-8", errors="replace").read()
        if LOCAL_THEME.search(src) or os.path.basename(path) == "Theme.lua":
            continue
        code = strip_lua_noise(src)
        for lineno, line in enumerate(code.splitlines(), 1):
            if BARE_THEME.search(line):
                rep.fail("scope", path,
                         "line %d uses a bare Theme with no `local Theme` in the file "
                         "-- use AegisPathfinder.Theme" % lineno)
    rep.ok("scope", len(files))


def check_media(rep):
    files = sorted(walk({".tga", ".blp"}))
    for path in files:
        if path.endswith(".blp"):
            continue
        with open(path, "rb") as fh:
            header = fh.read(18)
        if len(header) < 18:
            rep.fail("media", path, "truncated TGA header")
            continue
        image_type = header[2]
        width, height, depth = struct.unpack("<HHB", header[12:17])
        if image_type not in (2, 10):
            rep.fail("media", path, "image type %d; 1.12 wants uncompressed/RLE truecolor" % image_type)
        if depth != 32:
            rep.fail("media", path, "%d-bit; 1.12 textures must be 32-bit" % depth)
        for label, value in (("width", width), ("height", height)):
            if value == 0 or (value & (value - 1)) != 0:
                rep.fail("media", path, "%s %d is not a power of two" % (label, value))
    rep.ok("media", len(files))


# Every "Interface\\AddOns\\..." path Theme.lua hands the client. The client
# reports a missing texture by drawing nothing at all, so a typo or a renamed
# folder is invisible until someone notices a blank square -- which is exactly
# what a stale "AegisPathfinder\\media\\resting.tga" did here.
ADDON_TEXTURE = re.compile(r'"(Interface\\\\AddOns\\\\[^"]+)"')


def check_texture_paths(rep):
    theme = os.path.join(ROOT, "Theme.lua")
    if not os.path.exists(theme):
        return
    src = strip_lua_comments(open(theme, encoding="utf-8", errors="replace").read())

    # MEDIA .. "name" concatenations, resolved the way Lua would.
    media = re.search(r'local MEDIA = "([^"]+)"', src)
    prefix = media.group(1) if media else ""
    paths = set(ADDON_TEXTURE.findall(src))
    for suffix in re.findall(r'MEDIA \.\. "([^"]+)"', src):
        paths.add(prefix + suffix)

    checked = 0
    for path in sorted(paths):
        rel = path.replace("\\\\", "/").replace("\\", "/")
        marker = "Interface/AddOns/"
        if marker not in rel:
            continue
        tail = rel.split(marker, 1)[1]
        # Strip the addon folder; what is left is relative to the repo root.
        parts = tail.split("/", 1)
        if len(parts) != 2:
            continue
        folder, inner = parts
        expected = os.path.basename(ROOT)
        if folder != expected:
            rep.fail("textures", "Theme.lua",
                     "%s points at folder '%s', but the addon is '%s'"
                     % (path, folder, expected))
            continue
        local = os.path.join(ROOT, *inner.split("/"))
        checked += 1
        # The client appends the extension itself, so try both.
        if not any(os.path.exists(local + ext) for ext in (".tga", ".blp", "")):
            rep.fail("textures", "Theme.lua", "%s has no file on disk" % path)
    rep.ok("textures", checked)


# Every window is in the DIALOG strata, where the client draws frames in
# level order across all windows at once. A window that is not registered with
# Theme's stacking keeps the level it was built at, and interleaves with any
# window it overlaps -- chips and scrollbars drawn through the other's body.
# Theme:Chrome registers its window; anything else calls RegisterWindow.
DIALOG_STRATA = re.compile(r'SetFrameStrata\s*\(\s*"DIALOG"\s*\)')
STACKED = re.compile(r"(?:\bChrome|\bRegisterWindow)\s*\(")


def check_stacking(rep):
    files = [p for p in sorted(walk({".lua"}))
             if is_shipped(p) and os.path.basename(p) != "Theme.lua"]
    for path in files:
        code = strip_lua_comments(open(path, encoding="utf-8", errors="replace").read())
        windows = len(DIALOG_STRATA.findall(code))
        stacked = len(STACKED.findall(code))
        if windows > stacked:
            rep.fail("stacking", path,
                     "%d DIALOG window(s) but %d registered with Theme's stacking "
                     "-- use Theme:Chrome or Theme:RegisterWindow" % (windows, stacked))
    rep.ok("stacking", len(files))


def main():
    print("Verifying %s\n" % ROOT)
    rep = Report()
    check_syntax(rep)
    check_lua50(rep)
    check_toc(rep)
    check_xml(rep)
    check_theme(rep)
    check_theme_scope(rep)
    check_stacking(rep)
    check_media(rep)
    check_texture_paths(rep)
    return rep.summary()


if __name__ == "__main__":
    sys.exit(main())
