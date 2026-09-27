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
lua5.1 Tools/test_dungeons.lua
lua5.1 Tools/test_filtertags.lua
lua5.1 Tools/test_smartskip.lua
lua5.1 Tools/test_yourplace.lua
lua5.1 Tools/test_itemscore.lua
lua5.1 Tools/test_gearframe.lua
lua5.1 Tools/test_gearadvisor.lua
lua5.1 Tools/test_gearfinder.lua
lua5.1 Tools/test_guidelist.lua
lua5.1 Tools/test_materials.lua
lua5.1 Tools/test_craftplanner.lua
lua5.1 Tools/test_craftroute.lua
lua5.1 Tools/test_partysync.lua
lua5.1 Tools/test_activeframes.lua
lua5.1 Tools/test_nextguide.lua
lua5.1 Tools/test_setup.lua
lua5.1 Tools/test_objectivetabs.lua
lua5.1 Tools/test_objectivepanel.lua
lua5.1 Tools/test_options.lua
lua5.1 Tools/test_stacking.lua
lua5.1 Tools/test_scrolling.lua
lua5.1 Tools/test_minimap.lua
lua5.1 Tools/test_navigation.lua
lua5.1 Tools/test_professionsteps.lua

echo
echo "All offline checks passed."
echo "Not covered here: anything that needs a running 1.12 client -- whether the"
echo "UI actually looks like the concept, whether textures load, whether the"
echo "bundled fonts render. Those need an in-game pass."
