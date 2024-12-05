--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

type TurfService = {
	RegisterKill: (self: TurfService, killer: Player, victim: Player) -> (),

	SetTeams: (self: TurfService, team1: Team, team2: Team) -> (),
}
type TSInternal = TurfService & {
	_team1: Team,
	_team2: Team,

	_team1Turf: number,

	_init: (self: TSInternal) -> (),

	_claimTurf: (self: TSInternal, team: Team, amount: number) -> (),
}

local LINES: { BasePart } = Workspace:WaitForChild("Lines"):GetChildren()

local function AssignSpawn(team: Team, spawn: Model): ()
	local spawnLocations = spawn:FindFirstChild("SpawnLocations") :: Folder
	for _, child in ipairs(spawnLocations:GetChildren()) do
		(child :: SpawnLocation).TeamColor = team.TeamColor
	end

	local teamColorParts = spawn:FindFirstChild("TeamColorParts") :: Folder
	for _, descendant in ipairs(teamColorParts:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.BrickColor = team.TeamColor
		end
	end
end

local TurfService = {}

local TSPublicMethods = {}
local TSPrivateMethods = {}

local _instance: TSInternal
function TurfService.new(): TSInternal
	if _instance then
		error("[TurfService.new]: Attempted to create multiple instances of a singleton", 2)
	end

	local self = setmetatable({} :: TSInternal, { __index = CreateMultiIndex(TSPublicMethods, TSPrivateMethods) })

	self:_init()

	return self
end

function TSPublicMethods.RegisterKill(self: TSInternal, killer: Player, victim: Player): ()
	local killerTeam = killer.Team
	local victimTeam = victim.Team
	if
		not (
			(killerTeam == self._team1 and victimTeam == self._team2)
			or (killerTeam == self._team2 and victimTeam == self._team1)
		)
	then
		warn("[TurfService.RegisterKill]: Killer and victim teams do not match the configured teams")
		return
	end

	self:_claimTurf(killerTeam, 1)
end

function TSPublicMethods.SetTeams(self: TSInternal, team1: Team, team2: Team): ()
	self._team1 = team1
	self._team2 = team2

	local map = Workspace:FindFirstChild("Map") :: Model
	AssignSpawn(team1, map:FindFirstChild("Team1Spawn") :: Model)
	AssignSpawn(team2, map:FindFirstChild("Team2Spawn") :: Model)

	self._team1Turf = math.floor(#LINES / 2)
	for index, line in ipairs(LINES) do
		line.BrickColor = index <= self._team1Turf and team1.TeamColor or team2.TeamColor
	end
end

function TSPrivateMethods._init(self: TSInternal): ()
	_instance = self
end

function TSPrivateMethods._claimTurf(self: TSInternal, team: Team, amount: number): ()
	local newTurf
	if team == self._team1 then
		newTurf = math.min(self._team1Turf + amount, #LINES)
		for index = self._team1Turf + 1, newTurf do
			LINES[index].BrickColor = self._team1.TeamColor
		end
	else
		newTurf = math.max(self._team1Turf - amount, 0)
		for index = self._team1Turf, newTurf + 1, -1 do
			LINES[index].BrickColor = self._team2.TeamColor
		end
	end

	if newTurf == 0 or newTurf == #LINES then
		-- TODO: Handle win condition
		print(string.format("[TurfService._claimTurf]: %s wins!", team.Name))
		return
	end

	self._team1Turf = newTurf
end

return TurfService.new()
