--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- External dependencies
local Utility = ReplicatedStorage.Utility
local CreateMultiIndex = require(Utility.CreateMultiIndex)
local Grid = require(Utility.Grid)

type TurfService = {
	IsPositionOnTurf: (self: TurfService, team: Team, position: Vector3) -> boolean,
	ProcessBlockPlacement: (self: TurfService, team: Team, block: BasePart) -> (),

	RegisterKill: (self: TurfService, killer: Player, victim: Player) -> (),

	SetTeams: (self: TurfService, team1: Team, team2: Team) -> (),

	SetTurfPerKill: (self: TurfService, turfPerKill: number) -> (),
}
type TSInternal = TurfService & {
	_team1: Team,
	_team2: Team,

	_lines: { BasePart },
	_linesToBlocks: { [BasePart]: { BasePart } },

	_team1Turf: number,

	_turfPerKill: number,

	_playersOutOfBounds: { [Player]: boolean },

	_init: (self: TSInternal) -> (),

	_claimTurf: (self: TSInternal, team: Team) -> (),

	_getTurfBounds: (self: TSInternal, team: Team) -> (number, number),
	_enforceTurfBounds: (self: TSInternal) -> (),
}

-- Constants
local BOUND_KICK_DIRECTION = Vector3.new(0.5, 1, 0).Unit
local BOUND_KICK_SPEED = 150

-- Remote events folder
local Remotes = ReplicatedStorage.Remotes

--[[
	Assigns the spawn locations and team color parts of a spawn model to the given team.
	@param team Team
	@param spawn Model
]]
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

--[=[
	The team on the left side of the map, typically the blue team.
	@prop _team1 Team
	@private
	@within TurfService
]=]
--[=[
	The team on the right side of the map, typically the red team.
	@prop _team2 Team
	@private
	@within TurfService
]=]
--[=[
	The numerically ordered turf lines found in the [Workspace].
	@prop _lines { BasePart }
	@private
	@within TurfService
]=]
--[=[
	A mapping of turf lines to blocks placed on them.
	@prop _linesToBlocks { [BasePart]: { BasePart } }
	@private
	@within TurfService
]=]
--[=[
	The index of the turf line that separates the two teams.
	@prop _team1Turf number
	@private
	@within TurfService
]=]
--[=[
	The amount of turf claimed by a team per kill.
	@prop _turfPerKill number
	@private
	@within TurfService
]=]
--[=[
	A mapping of players that are out of bounds.
	@prop _playersOutOfBounds { [Player]: boolean }
	@private
	@within TurfService
]=]

--[=[
	TurfService is a singleton service responsible for managing the turf mechanics in the game. It tracks and enforces the boundaries 
	of each team's turf, processes block placements, and handles the claiming of turf during gameplay. TurfService ensures that 
	turf-related interactions are synchronized across all clients and adhere to game rules.

	### Core Responsibilities:
	- **Turf Tracking and Enforcement:**
		- Divides the game map into turf zones for two teams, defined by ordered turf lines in the [Workspace].
		- Enforces turf boundaries by monitoring player positions and pushing out-of-bounds players back within their team's turf.
	- **Block Management:**
		- Processes block placements by associating blocks with specific turf lines.
		- Removes blocks when turf is claimed by the opposing team.
	- **Turf Claiming:**
		- Allows teams to claim turf based on kills during combat phases.
		- Updates turf lines and sends notifications to clients about changes in turf control.
	- **Team and Spawn Management:**
		- Assigns spawn points and team color properties for each team's starting area.
		- Dynamically sets and updates teams based on gameplay progression.

	TurfService is critical for ensuring fair and engaging gameplay, maintaining team-specific turf zones,
	and providing dynamic gameplay through turf progression mechanics.

	@class TurfService
	@server
	@tag Singleton
]=]
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

--[=[
	Checks if the given position is within the turf of the specified team.
	@method IsPositionOnTurf
	@param team Team
	@param position Vector3
	@return boolean
	@within TurfService
]=]
function TSPublicMethods.IsPositionOnTurf(self: TSInternal, team: Team, position: Vector3): boolean
	if not (team == self._team1 or team == self._team2) then
		warn(string.format("[TurfService:IsPositionOnTurf]: %s is not a valid team", team.Name))
		return false
	end

	local minBound, maxBound = self:_getTurfBounds(team)
	return position.X >= minBound and position.X <= maxBound
end

--[=[
	Processes the placement of a block on the turf, associating it with the corresponding turf line.
	@method ProcessBlockPlacement
	@param team Team
	@param block BasePart
	@within TurfService
]=]
function TSPublicMethods.ProcessBlockPlacement(self: TSInternal, team: Team, block: BasePart): ()
	if not (team == self._team1 or team == self._team2) then
		warn(string.format("[TurfService:ProcessBlockPlacement]: %s is not a valid team", team.Name))
		return
	end

	local turfStart = team == self._team1 and self._team1Turf or self._team1Turf + 1
	local gridIndex = math.floor((self._lines[turfStart].Position.X - block.Position.X) / Grid.SIZE) + turfStart
	if gridIndex < 1 or gridIndex > #self._lines then
		warn("[TurfService:ProcessBlockPlacement]: Block is not within the turf bounds")
		return
	end

	local line = self._lines[gridIndex]
	if not self._linesToBlocks[line] then
		self._linesToBlocks[line] = {}
	end
	table.insert(self._linesToBlocks[line], block)
end

--[=[
	Registers a kill between two players, claiming turf for the killer's team.
	@method RegisterKill
	@param killer Player
	@param victim Player
	@within TurfService
]=]
function TSPublicMethods.RegisterKill(self: TSInternal, killer: Player, victim: Player): ()
	local killerTeam = killer.Team
	local victimTeam = victim.Team
	if
		not (
			(killerTeam == self._team1 and victimTeam == self._team2)
			or (killerTeam == self._team2 and victimTeam == self._team1)
		)
	then
		warn("[TurfService:RegisterKill]: Killer and victim teams do not match the configured teams")
		return
	end

	self:_claimTurf(killerTeam)
end

--[=[
	Sets the teams for the turf service, updating the turf lines and spawn locations.
	@method SetTeams
	@param team1 Team
	@param team2 Team
	@within TurfService
]=]
function TSPublicMethods.SetTeams(self: TSInternal, team1: Team, team2: Team): ()
	self._team1 = team1
	self._team2 = team2

	for _, blocks in pairs(self._linesToBlocks) do
		if blocks then
			for _, block in ipairs(blocks) do
				block:Destroy()
			end
		end
	end
	self._linesToBlocks = {}

	self._team1Turf = math.floor(#self._lines / 2)
	for index, line in ipairs(self._lines) do
		line.BrickColor = index <= self._team1Turf and team1.TeamColor or team2.TeamColor
	end

	local map = Workspace:FindFirstChild("Map") :: Model
	AssignSpawn(team1, map:FindFirstChild("Team1Spawn") :: Model)
	AssignSpawn(team2, map:FindFirstChild("Team2Spawn") :: Model)

	Remotes.SetTeams:FireAllClients(team1, team2)
end

--[=[
	Sets the amount of turf claimed by a team per kill.
	@method SetTurfPerKill
	@param turfPerKill number
	@within TurfService
]=]
function TSPublicMethods.SetTurfPerKill(self: TSInternal, turfPerKill: number): ()
	self._turfPerKill = turfPerKill
end

--[=[
	Initializes the turf service, sorting the turf lines and connecting to the necessary events.
	@method _init
	@private
	@within TurfService
]=]
function TSPrivateMethods._init(self: TSInternal): ()
	_instance = self

	self._lines = Workspace:WaitForChild("Lines"):GetChildren()
	table.sort(self._lines, function(a, b)
		return a.Name < b.Name
	end)
	self._linesToBlocks = {}

	self._team1Turf = 0

	self._turfPerKill = 0

	self._playersOutOfBounds = {}
	RunService.PostSimulation:Connect(function()
		self:_enforceTurfBounds()
	end)
end

--[=[
	Claims turf for the given team, updating the turf lines and destroying blocks on the claimed turf.
	@method _claimTurf
	@param team Team
	@private
	@within TurfService
]=]
function TSPrivateMethods._claimTurf(self: TSInternal, team: Team)
	local start, finish, step, teamColor
	if team == self._team1 then
		start = self._team1Turf + 1
		finish = math.min(self._team1Turf + self._turfPerKill, #self._lines)
		step = 1
		teamColor = self._team1.TeamColor
	else
		start = self._team1Turf
		finish = math.max(self._team1Turf - self._turfPerKill, 0)
		step = -1
		teamColor = self._team2.TeamColor
	end
	for index = start, finish, step do
		local line = self._lines[index]
		line.BrickColor = teamColor

		local blocks = self._linesToBlocks[line]
		if blocks then
			for _, block in ipairs(blocks) do
				block:Destroy()
			end
			self._linesToBlocks[line] = nil
		end
	end

	if finish == 0 or finish == #self._lines then
		print(string.format("[TurfService:_claimTurf]: %s wins!", team.Name))
		return
	end

	self._team1Turf = finish
	Remotes.TurfChanged:FireAllClients(finish)
end

--[=[
	Returns the minimum and maximum bounds of the turf for the given team.
	@method _getTurfBounds
	@param team Team
	@return number, number
	@private
	@within TurfService
]=]
function TSPrivateMethods._getTurfBounds(self: TSInternal, team: Team): (number, number)
	local turfStart, turfEnd
	if team == self._team1 then
		turfStart = self._team1Turf
		turfEnd = 1
	else
		turfStart = #self._lines
		turfEnd = self._team1Turf + 1
	end
	return self._lines[turfStart].Position.X - Grid.SIZE / 2, self._lines[turfEnd].Position.X + Grid.SIZE / 2
end

--[=[
	Enforces the turf bounds, kicking players back into bounds if they are out of bounds.
	@method _enforceTurfBounds
	@private
	@within TurfService
]=]
function TSPrivateMethods._enforceTurfBounds(self: TSInternal): ()
	if not (self._team1 and self._team2) then
		return
	end

	local team1MinBound, _ = self:_getTurfBounds(self._team1)
	local _, team2MaxBound = self:_getTurfBounds(self._team2)
	for _, player in ipairs(Players:GetPlayers()) do
		local team = player.Team
		if team ~= self._team1 and team ~= self._team2 then
			continue
		end

		local character = player.Character
		if not character then
			self._playersOutOfBounds[player] = nil
			continue
		end

		local rootPart = character.PrimaryPart
		if not rootPart then
			self._playersOutOfBounds[player] = nil
			continue
		end

		local isOutOfBounds = false
		if team == self._team1 then
			isOutOfBounds = rootPart.Position.X < team1MinBound
		else
			isOutOfBounds = rootPart.Position.X > team2MaxBound
		end
		if isOutOfBounds then
			if not self._playersOutOfBounds[player] then
				print(string.format("[TurfService:_enforceTurfBounds]: %s was kicked back into bounds", player.Name))
				self._playersOutOfBounds[player] = true

				character:PivotTo(character:GetPivot() + Vector3.new(0, Grid.SIZE, 0))

				rootPart.AssemblyLinearVelocity = Vector3.new(team == self._team1 and 1 or -1, 0, 0)
					* BOUND_KICK_DIRECTION
					* BOUND_KICK_SPEED
			end
		else
			self._playersOutOfBounds[player] = nil
		end
	end
end

return TurfService.new()
