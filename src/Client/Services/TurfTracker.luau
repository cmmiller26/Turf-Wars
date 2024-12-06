--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

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

local Remotes = ReplicatedStorage.Remotes

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

function TTPublicMethods.IsPositionOnTurf(self: TTInternal, team: Team, position: Vector3): boolean
	if not (team == self._team1 or team == self._team2) then
		warn(string.format("[TurfService.IsPositionOnTurf]: %s is not a valid team", team.Name))
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

function TTPrivateMethods._init(self: TTInternal): ()
	_instance = self

	Remotes.SetTeams.OnClientEvent:Connect(function(team1: Team, team2: Team)
		self:_onSetTeams(team1, team2)
	end)
	Remotes.TurfChanged.OnClientEvent:Connect(function(team1Turf: number)
		self._team1Turf = team1Turf
	end)
end

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
