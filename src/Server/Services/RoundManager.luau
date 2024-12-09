--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Teams = game:GetService("Teams")

-- External Dependencies
local Signal = require(ReplicatedStorage.Packages.Signal)
local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

-- Server modules
local Server = ServerScriptService.Server
local Types = require(Server.Types)

local Services = Server.Services
local PlayerRegistry = require(Services.PlayerRegistry)
local TurfService = require(Services.TurfService)

type RoundManager = {
	StateChanged: Signal.Signal<RMState>,

	GetState: (self: RoundManager) -> RMState,

	GetCurrentPhase: (self: RoundManager) -> Phase,
}
type RMInternal = RoundManager & {
	_state: RMState,
	_phaseIndex: number,

	_timer: thread?,

	_players: { Player },

	_team1: Team,
	_team2: Team,

	_init: (self: RMInternal) -> (),

	_changeState: (self: RMInternal, newState: RMState) -> (),

	_startIntermission: (self: RMInternal) -> (),

	_startRound: (self: RMInternal) -> (),
	_endRound: (self: RMInternal) -> (),

	_setPhaseIndex: (self: RMInternal, index: number) -> (),
	_nextPhase: (self: RMInternal) -> (),

	_checkPlayerCount: (self: RMInternal) -> (),
	_removePlayerFromRound: (self: RMInternal, player: Player) -> (),

	_onPlayerAdded: (self: RMInternal, player: Player) -> (),
	_onPlayerRemoving: (self: RMInternal, player: Player) -> (),
}

type RMState = "WaitingForPlayers" | "Intermission" | "PreRound" | "InRound" | "PostRound"

type Phase = {
	Type: PhaseType,
	Duration: number,
	TurfPerKill: number?,
}
type PhaseType = "Build" | "Combat"

-- Constants
local MIN_PLAYER_COUNT = 2

local INTERMISSION_LENGTH = 60

local PHASE_SEQUENCE: { Phase } = {
	{ Type = "Build", Duration = 40 },
	{ Type = "Combat", Duration = 90 },
	{ Type = "Build", Duration = 20 },
	{ Type = "Combat", Duration = 90, TurfPerKill = 3 },
}

local SPECTATOR_TEAM = Teams:WaitForChild("Spectators")

do -- TEMP
	MIN_PLAYER_COUNT = 1
	INTERMISSION_LENGTH = 5
	PHASE_SEQUENCE = {
		{ Type = "Combat", Duration = 90 },
	}
end

--[=[
	Fisher-Yates shuffle algorithm for shuffling a list in place.
	@param list -- The list to shuffle.
	@return { any } -- The shuffled list.
]=]
local function FYShuffle(list: { any }): { any }
	math.randomseed(os.clock())
	local shuffled = { table.unpack(list) }
	for i = #shuffled, 2, -1 do
		local j = math.random(i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	return shuffled
end

--[=[
	Sets the player handlers for a given list of players based on the handler type and team.
	@param players -- The list of players to set handlers for.
	@param handlerType -- The `HandlerType` of the handler to create for the players.
	@param team -- The `Team` to assign the players to.
]=]
local function SetPlayerHandlers(players: { Player }, handlerType: Types.HandlerType, team: Team): ()
	for _, player in ipairs(players) do
		player.Team = team
		PlayerRegistry:CreateHandler(player, handlerType)
	end
end

--[=[
    `RoundManager` is a singleton class responsible for managing the game rounds, including state transitions, player assignments, and phase management within a round.

    This class orchestrates the flow of the game by moving through various states such as "WaitingForPlayers", "Intermission", "PreRound", "InRound", and "PostRound".
	It handles team assignments, phase transitions (e.g., Build and Combat phases), and monitors player counts to start or end rounds accordingly.

    **Responsibilities:**
    - **State Management:** Controls the overall game state using a finite state machine.
    - **Phase Control:** Manages the sequence of phases within a round, each with a specific type (`"Build"` or `"Combat"`) and duration.
    - **Player Management:** Assigns players to teams (`Blue`, `Red`, or `Spectators`) and updates their handlers based on the current game state.
    - **Team Assignment:** Randomly shuffles players and distributes them evenly between teams.
    - **Player Count Monitoring:** Starts or ends rounds based on the number of active players.
    - **Signal Emission:** Provides a `StateChanged` signal to notify other systems of state transitions.

    **Key Features:**
    - **Singleton Pattern:** Ensures only one instance of `RoundManager` exists throughout the game.
    - **Random Team Assignment:** Uses the Fisher-Yates shuffle algorithm (`FYShuffle`) for fair team distribution.
    - **Dynamic Timing:** Utilizes `task.delay` to handle asynchronous phase transitions and timers.
    - **Temporary Overrides:** Includes temporary settings for testing purposes, such as reduced `MIN_PLAYER_COUNT` and phase durations.

    **Public Methods:**
    - `GetState()`: Returns the current state of the round manager.
    - `GetCurrentPhase()`: Returns the current phase within the round.

    **Events:**
    - `StateChanged: Signal<RMState>`: Fires whenever the round manager changes state.

    **Notes:**
    - The `RoundManager` relies on the `PlayerRegistry` service to create and manage player handlers.
    - Phases and durations are configurable via the `PHASE_SEQUENCE` table.
    - The class uses `Players.CharacterAutoLoads = false` to control character spawning manually.
    - Temporary configurations for testing are enclosed within a `do -- TEMP` block and should be adjusted for production.
]=]
local RoundManager = {}

local RMPublicMethods = {}
local RMPrivateMethods = {}

local _instance: RoundManager
function RoundManager.new(): RoundManager
	if _instance then
		error("[RoundManager.new]: Attempted to create multiple instances of a singleton")
	end

	local self = setmetatable({} :: RMInternal, { __index = CreateMultiIndex(RMPublicMethods, RMPrivateMethods) })

	self:_init()

	return self
end

--[=[
	Returns the current state of the round manager.
	@return RMState -- The current state of the round manager.
]=]
function RMPublicMethods.GetState(self: RMInternal): RMState
	return self._state
end

--[=[
	Returns the current phase of the round manager.
	@return Phase -- The current phase of the round manager.
]=]
function RMPublicMethods.GetCurrentPhase(self: RMInternal): Phase
	return PHASE_SEQUENCE[self._phaseIndex]
end

function RMPrivateMethods._init(self: RMInternal): ()
	_instance = self

	self.StateChanged = Signal.new()

	self._state = "WaitingForPlayers"
	self._phaseIndex = 0

	self._players = {}

	self._team1 = Teams:WaitForChild("Blue Team")
	self._team2 = Teams:WaitForChild("Red Team")

	Players.PlayerAdded:Connect(function(player: Player)
		self:_onPlayerAdded(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		self:_onPlayerRemoving(player)
	end)
end

function RMPrivateMethods._changeState(self: RMInternal, newState: RMState): ()
	if self._state == newState then
		return
	end

	if self._timer then
		if coroutine.status(self._timer) == "suspended" then
			coroutine.close(self._timer) -- Stop the timer from trying to enter the next phase
		end
		self._timer = nil
	end

	print("[RoundManager._changeState]: Changing state to " .. newState)

	self._state = newState
	self.StateChanged:Fire(newState)
end

function RMPrivateMethods._startIntermission(self: RMInternal): ()
	self:_changeState("Intermission")

	self._timer = task.delay(INTERMISSION_LENGTH, function()
		self:_startRound()
	end)
end

function RMPrivateMethods._startRound(self: RMInternal): ()
	if self._state ~= "Intermission" then
		return
	end

	self:_changeState("PreRound")

	TurfService:SetTeams(self._team1, self._team2)

	self._players = Players:GetPlayers()

	local blueTeam = {}
	local redTeam = {}
	for index, player in ipairs(FYShuffle(self._players)) do
		if index % 2 == 0 then
			table.insert(blueTeam, player)
		else
			table.insert(redTeam, player)
		end
	end
	SetPlayerHandlers(blueTeam, "Round", self._team1)
	SetPlayerHandlers(redTeam, "Round", self._team2)

	self:_changeState("InRound")
	self:_setPhaseIndex(1)
end
function RMPrivateMethods._endRound(self: RMInternal): ()
	if self._state == "PreRound" then
		self.StateChanged:Wait()
	elseif self._state ~= "InRound" then
		return
	end

	self:_changeState("PostRound")

	SetPlayerHandlers(self._players, "Lobby", SPECTATOR_TEAM)
	self._players = {}

	self:_checkPlayerCount()
end

function RMPrivateMethods._setPhaseIndex(self: RMInternal, index: number): ()
	self._phaseIndex = index

	local phase = PHASE_SEQUENCE[index]

	local isCombat = phase.Type == "Combat"
	if isCombat then
		TurfService:SetTurfPerKill(phase.TurfPerKill or 1)
	end

	for _, player in ipairs(self._players) do
		local handler = PlayerRegistry:GetHandler(player)
		if handler and handler:IsA("RoundPlayerHandler") then
			(handler :: Types.RoundPlayerHandler):SetCombatEnabled(isCombat)
		else
			warn(string.format("[RoundManager._setPhaseIndex]: %s does not have a RoundPlayerHandler", player.Name))
		end
	end

	print("[RoundManager._setPhaseIndex]: Starting " .. phase.Type .. " phase " .. index)

	self._timer = task.delay(phase.Duration, function()
		self:_nextPhase()
	end)
end
function RMPrivateMethods._nextPhase(self: RMInternal): ()
	if self._phaseIndex < #PHASE_SEQUENCE then
		self:_setPhaseIndex(self._phaseIndex + 1)
	else
		self:_endRound()
	end
end

function RMPrivateMethods._checkPlayerCount(self: RMInternal): ()
	if #Players:GetPlayers() >= MIN_PLAYER_COUNT then
		if self._state == "WaitingForPlayers" or self._state == "PostRound" then
			self:_startIntermission()
		end
	elseif self._state ~= "WaitingForPlayers" then
		self:_changeState("WaitingForPlayers")
	end
end
function RMPrivateMethods._removePlayerFromRound(self: RMInternal, player: Player): ()
	local index = table.find(self._players, player)
	if index then
		table.remove(self._players, index)

		if #self._players < MIN_PLAYER_COUNT then
			self:_endRound()
		end
	end
end

function RMPrivateMethods._onPlayerAdded(self: RMInternal, player: Player): ()
	PlayerRegistry:CreateHandler(player, "Lobby")
	if self._state == "WaitingForPlayers" then
		self:_checkPlayerCount()
	end
end
function RMPrivateMethods._onPlayerRemoving(self: RMInternal, player: Player): ()
	if self._state == "PreRound" or self._state == "InRound" then
		self:_removePlayerFromRound(player)
	else
		self:_checkPlayerCount()
	end
end

Players.CharacterAutoLoads = false

return RoundManager.new()
