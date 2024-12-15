--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- External dependencies
local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

type TurfTracker = {
	IsPositionOnTurf: (self: TurfTracker, team: Team, position: Vector3) -> boolean,
}
type TTInternal = TurfTracker & {
	_lines: { BasePart },

	_team1: Team,
	_team2: Team,

	_team1Turf: number,

	_init: (self: TTInternal) -> (),

	_onSetTeams: (self: TTInternal, team1: Team, team2: Team) -> (),
}

-- Remote event folder
local Remotes = ReplicatedStorage.Remotes

--[=[
	The numerically ordered turf lines found in the [Workspace].
	@prop _lines { BasePart }
	@private
	@within TurfTracker
]=]
--[=[
	The team on the left side of the map, typically the blue team.
	@prop _team1 Team
	@private
	@within TurfTracker
]=]
--[=[
	The team on the right side of the map, typically the red team.
	@prop _team2 Team
	@private
	@within TurfTracker
]=]
--[=[
	The index of the turf line that separates the two teams.
	@prop _team1Turf number
	@private
	@within TurfTracker
]=]

--[=[
	TurfTracker is a singleton class that keeps track of the game's teams and turf lines, providing a method to check if a position is on a team's turf.
	@class TurfTracker
	@client
	@tag Singleton
]=]
local TurfTracker = {}

local TTPublicMethods = {}
local TTPrivateMethods = {}

local _instance: TTInternal
function TurfTracker.new(): TTInternal
	if _instance then
		error("[TurfTracker.new]: Attempted to create multiple instances of a singleton", 2)
	end

	local self = setmetatable({} :: TTInternal, { __index = CreateMultiIndex(TTPublicMethods, TTPrivateMethods) })

	self:_init()

	return self
end

--[=[
	Checks if the given position is within the turf of the specified team.
	@method IsPositionOnTurf
	@param team Team
	@param position Vector3
	@return boolean
	@within TurfTracker
]=]
function TTPublicMethods.IsPositionOnTurf(self: TTInternal, team: Team, position: Vector3): boolean
	if not (team == self._team1 or team == self._team2) then
		warn(string.format("[TurfService:IsPositionOnTurf]: %s is not a valid team", team.Name))
		return false
	end

	local turfStart, turfEnd
	if team == self._team1 then
		turfStart = self._team1Turf
		turfEnd = 1
	elseif team == self._team2 then
		turfStart = #self._lines
		turfEnd = self._team1Turf + 1
	end

	local minBound = self._lines[turfStart].Position.X - (self._lines[turfStart].Size.X / 2)
	local maxBound = self._lines[turfEnd].Position.X + (self._lines[turfEnd].Size.X / 2)
	return position.X >= minBound and position.X <= maxBound
end

--[=[
	Initializes the turf tracker, connecting to the necessary remote events.
	@method _init
	@private
	@within TurfTracker
]=]
function TTPrivateMethods._init(self: TTInternal): ()
	_instance = self

	Remotes.SetTeams.OnClientEvent:Connect(function(team1: Team, team2: Team)
		self:_onSetTeams(team1, team2)
	end)
	Remotes.TurfChanged.OnClientEvent:Connect(function(team1Turf: number)
		self._team1Turf = team1Turf
	end)
end

--[=[
	Updates the turf tracker with the given [Team] instances and resets its turf line data.
	@method _onSetTeams
	@param team1 Team
	@param team2 Team
	@private
	@within TurfTracker
]=]
function TTPrivateMethods._onSetTeams(self: TTInternal, team1: Team, team2: Team): ()
	self._lines = Workspace:WaitForChild("Lines"):GetChildren()
	table.sort(self._lines, function(a, b)
		return a.Name < b.Name
	end)

	self._team1 = team1
	self._team2 = team2

	self._team1Turf = math.floor(#self._lines / 2)
end

return TurfTracker.new()
