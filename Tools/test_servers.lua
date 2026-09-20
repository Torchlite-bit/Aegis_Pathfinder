--[[
	Tests for guide data provenance.

	The point of Servers.lua is that a guide written for one server can point
	at nothing on another, silently. These checks make sure the mismatch is
	actually detected and that the default case stays quiet.

	Run:  lua5.1 Tools/test_servers.lua
]]

package.path = "Tools/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

AegisPathfinder = {
	db = { profile = {}, char = {} },
	qsplusguides = {},
	__printed = {},
}
function AegisPathfinder:Print(msg) table.insert(self.__printed, msg) end
function AegisPathfinder:Debug() end
function AegisPathfinder:UpdateStatusFrame() end

dofile("Servers.lua")

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

-- Registry -------------------------------------------------------------------

check(table.getn(AegisPathfinder.servers) == 3, "expected 3 servers, got %d",
	table.getn(AegisPathfinder.servers))

local native = 0
for _, s in ipairs(AegisPathfinder.servers) do
	check(s.key and s.label, "every server needs a key and a label")
	check(s.dataset == "native" or s.dataset == "untested",
		"%s has an unknown dataset state '%s'", s.label, tostring(s.dataset))
	if s.dataset == "native" then native = native + 1 end
end
check(native == 1,
	"exactly one server should be marked as having verified guide data, found %d", native)

check(AegisPathfinder:GetServerInfo("octowow").label == "OctoWoW",
	"GetServerInfo should resolve a known key")
check(AegisPathfinder:GetServerInfo("nosuchserver") == nil,
	"GetServerInfo should return nil for an unknown key")
check(AegisPathfinder:GetServerInfo(nil) == nil,
	"GetServerInfo should tolerate nil")

-- Default state --------------------------------------------------------------

check(AegisPathfinder:GetCurrentServer() == "octowow",
	"with nothing set, the default dataset's server is assumed")
check(AegisPathfinder:GetGuideDataSource("anything") == "octowow",
	"a guide that declares no source defaults to the shipped dataset")
check(AegisPathfinder:GetDataSourceWarning() == nil,
	"the default case must be silent -- a warning on every step is noise")

-- Mismatch -------------------------------------------------------------------

check(AegisPathfinder:SetCurrentServer("ravencraft") == true,
	"setting a known server should succeed")
check(AegisPathfinder:SetCurrentServer("nosuchserver") == false,
	"setting an unknown server should fail rather than store junk")
check(AegisPathfinder:GetCurrentServer() == "ravencraft",
	"a failed set must not clobber the current server")

local mismatch, source, current = AegisPathfinder:HasDataSourceMismatch()
check(mismatch == true, "OctoWoW data on RavenCraft is a mismatch")
check(source == "OctoWoW", "the source should be named, got '%s'", tostring(source))
check(current == "RavenCraft", "the current server should be named, got '%s'", tostring(current))

local warning = AegisPathfinder:GetDataSourceWarning()
check(warning ~= nil, "a mismatch should produce a warning line")
check(string.find(warning, "OctoWoW", 1, true) and string.find(warning, "RavenCraft", 1, true),
	"the warning should name both servers, got '%s'", tostring(warning))

-- Switching to an unverified server should say so once, at the time of the
-- switch, rather than staying silent until something goes wrong.
local saidSomething = false
for _, msg in ipairs(AegisPathfinder.__printed) do
	if string.find(msg, "has not been verified", 1, true) then saidSomething = true end
end
check(saidSomething, "switching to an unverified server should warn at the time")

-- A guide may declare its own source.
AegisPathfinder.qsplusguides["Ported Guide"] = { dataSource = "ravencraft", steps = {} }
check(AegisPathfinder:GetGuideDataSource("Ported Guide") == "ravencraft",
	"a guide's own dataSource should win over the default")
check(AegisPathfinder:HasDataSourceMismatch("Ported Guide") == false,
	"a guide authored for the current server is not a mismatch")

AegisPathfinder:SetCurrentServer("octowow")
check(AegisPathfinder:GetDataSourceWarning() == nil,
	"returning to the native server should silence the warning")
local m2 = AegisPathfinder:HasDataSourceMismatch("Ported Guide")
check(m2 == true, "a RavenCraft guide on OctoWoW is a mismatch in the other direction")

-- Cycling --------------------------------------------------------------------

local seen = {}
for _ = 1, 3 do
	AegisPathfinder:CycleServer()
	seen[AegisPathfinder:GetCurrentServer()] = true
end
local n = 0
for _ in pairs(seen) do n = n + 1 end
check(n == 3, "cycling should visit every server, saw %d", n)

AegisPathfinder.db.profile.server = "nosuchserver"
AegisPathfinder:CycleServer()
check(AegisPathfinder:GetServerInfo(AegisPathfinder:GetCurrentServer()) ~= nil,
	"cycling from an unrecognised stored value should recover, not stall")

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("Servers: %d checks", checks))
if table.getn(failures) == 0 then
	print("All server checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
