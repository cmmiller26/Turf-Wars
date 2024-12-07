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

--[=[
    `TurfTracker` is a client-side singleton class responsible for tracking turf-related information.

    This class provides functionality to determine whether a position falls within a team’s turf.
	It listens for updates from the server regarding team assignments and turf changes, ensuring the client has accurate, up-to-date information for validation purposes.

    **Responsibilities:**
    - **Turf Ownership Validation:** Determines if a position is on a team’s turf using pre-defined lines.
    - **Team Synchronization:** Listens to remote events to update team assignments and turf ownership dynamically.
    - **Turf Line Management:** Tracks the state of turf lines and calculates bounds for ownership checks.

    **Key Features:**
    - **Singleton Pattern:** Ensures only one instance of `TurfTracker` exists on the client.
    - **Dynamic Updates:** Automatically synchronizes team and turf data with the server using remote events.
    - **Efficient Validation:** Uses pre-sorted lines to validate turf ownership quickly.

    **Public Methods:**
    - `IsPositionOnTurf(team: Team, position: Vector3): boolean`: Checks if a given position is within the bounds of a team’s turf.

    **Notes:**
    - This class relies on the `Lines` objects in the `Workspace` to represent turf boundaries.
    - Turf updates are received via the `Remotes.TurfChanged` and `Remotes.SetTeams` remote events.

    This class is designed to be used on the client for efficient local validation of turf-related actions.
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
	Returns whether the given position is on the turf of the given team.
	@param team -- The team to check the position against.
	@param position -- The position to check.
	@return boolean -- Whether the position is on the turf of the given team.
]=]
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
