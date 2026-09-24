#!/bin/sh
# Every check that can run without a WoW client.
#
#   sh Tools/run_tests.sh
#
# Run from the repository root. Exits non-zero if anything fails.
set -e

cd "$(dirname "$0")/.."

echo "== static verification =="
python3 Tools/verify.py

echo
echo "== profession source document =="
python3 Tools/convert_professions.py --check

echo
echo "== lua tests =="
lua5.1 Tools/test_theme.lua
lua5.1 Tools/test_professions.lua
lua5.1 Tools/test_guideengine.lua
lua5.1 Tools/test_navcallout.lua
lua5.1 Tools/test_servers.lua
lua5.1 Tools/test_dungeons.lua
lua5.1 Tools/test_guidelist.lua
lua5.1 Tools/test_materials.lua
lua5.1 Tools/test_objectivetabs.lua
lua5.1 Tools/test_objectivepanel.lua
lua5.1 Tools/test_options.lua
lua5.1 Tools/test_stacking.lua
lua5.1 Tools/test_scrolling.lua
lua5.1 Tools/test_minimap.lua

echo
echo "All offline checks passed."
echo "Not covered here: anything that needs a running 1.12 client -- whether the"
echo "UI actually looks like the concept, whether textures load, whether the"
echo "bundled fonts render. Those need an in-game pass."
