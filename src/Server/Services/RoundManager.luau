--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Teams = game:GetService("Teams")

-- External Dependencies
local SharedTypes = require(ReplicatedStorage.SharedTypes)
local Signal = require(ReplicatedStorage.Packages.Signal)
local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

-- Server modules
local Server = ServerScriptService.Server
local ServerTypes = require(Server.ServerTypes)

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

--[=[
	@type RMState "WaitingForPlayers" | "Intermission" | "PreRound" | "InRound" | "PostRound"
	@within RoundManager
]=]
type RMState = "WaitingForPlayers" | "Intermission" | "PreRound" | "InRound" | "PostRound"

--[=[
	A phase of the round.
	@interface Phase
	@field Type PhaseType
	@field Duration number -- How long the phase lasts in seconds.
	@field TurfPerKill? number -- The amount of turf gained per kill. Only applies to combat phases.
	@within RoundManager
]=]
type Phase = {
	Type: PhaseType,
	Duration: number,
	TurfPerKill: number?,
}
--[=[
	@type PhaseType = "Build" | "Combat"
	@within RoundManager
]=]
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

--[[
	Fisher-Yates shuffle algorithm for shuffling a list in place.
	@param list { any }
	@return { any }
]]
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
	Fired when the state of the round manager changes.
	@prop StateChanged Signal<RMState>
	@within RoundManager
]=]

--[=[
	The current state of the round manager.
	@prop _state RMState
	@private
	@within RoundManager
]=]
--[=[
	What index of the phase sequence the round manager is currently on.
	@prop _phaseIndex number
	@private
	@within RoundManager
]=]
--[=[
	The timer for the current phase.
	@prop _timer thread?
	@private
	@within RoundManager
]=]
--[=[
	The list of players in the round.
	@prop _players { Player }
	@private
	@within RoundManager
]=]
--[=[
	The team on the left side of the map, typically the blue team.
	@prop _team1 Team
	@private
	@within RoundManager
]=]
--[=[
	The team on the right side of the map, typically the red team.
	@prop _team2 Team
	@private
	@within RoundManager
]=]

--[[
	Creates player handlers for a list of players and sets their team.
	@param players { Player }
	@param characterType CharacterType
	@param team Team
]]
local function SetPlayerHandlers(players: { Player }, characterType: SharedTypes.CharacterType, team: Team): ()
	for _, player in ipairs(players) do
		player.Team = team
		PlayerRegistry:CreateHandler(player, characterType)
	end
end

--[=[
	RoundManager is a singleton class that manages the lifecycle of gameplay rounds, including their states and phases. 
	It handles team assignments, player management, and transitions between various round phases such as building and combat. 
	The class ensures that game rules, such as turf mechanics and player combat states, are consistently enforced throughout the round.

	### Core Responsibilities:
	- **Round States:**
		- Manages transitions between different states ([RMState]) and broadcasts them via the `StateChanged` [Signal].
	- **Phases:**
		- Orchestrates a sequence of build and combat phases using the `PHASE_SEQUENCE` configuration.
		- Ensures proper timing and transitions between phases with a built-in timer.
	- **Player Management:**
		- Distributes players evenly between two teams (`Blue Team` and `Red Team`) at the start of a round.
		- Uses the [PlayerRegistry] to assign different [PlayerHandler] instances to players based on their current state.
		- Handles players joining or leaving the game dynamically, adjusting team and state transitions accordingly.

	### Features:
	- **Team and Turf Integration:**
		- Coordinates with [TurfService] to manage turf mechanics, including turf gained per kill and team-specific actions.
		- Dynamically adjusts team composition and ensures balanced gameplay.
	- **Phase-Specific Behavior:**
		- Toggles player combat states during combat phases and ensures only valid actions occur during building phases.
		- Configures per-phase attributes, such as `TurfPerKill`, to define gameplay behavior dynamically.
	- **Player Safety and Cleanup:**
		- Automatically removes players from the round if they leave the game or switch teams.
		- Resets players to spectator mode (`LobbyCharacter`) at the end of a round.

	RoundManager provides a robust framework for managing competitive gameplay rounds, ensuring fairness, consistency, and dynamic phase-based interactions. 
	Through seamless integration with player handlers and turf mechanics, it orchestrates engaging and balanced gameplay.

	@class RoundManager
	@server
	@tag Singleton
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
	@method GetState
	@return RMState
	@within RoundManager
]=]
function RMPublicMethods.GetState(self: RMInternal): RMState
	return self._state
end

--[=[
	Returns the current phase of the round.
	@method GetCurrentPhase
	@return Phase
	@within RoundManager
]=]
function RMPublicMethods.GetCurrentPhase(self: RMInternal): Phase
	return PHASE_SEQUENCE[self._phaseIndex]
end

--[=[
	Initializes the round manager, setting up event listeners and the initial state.
	@method _init
	@private
	@within RoundManager
]=]
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

--[=[
	Changes the state of the round manager and fires the StateChanged event.
	@method _changeState
	@param newState RMState
	@private
	@within RoundManager
]=]
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

	print("[RoundManager:_changeState]: Changing state to " .. newState)

	self._state = newState
	self.StateChanged:Fire(newState)
end

--[=[
	Starts the intermission phase of the round.
	@method _startIntermission
	@private
	@within RoundManager
]=]
function RMPrivateMethods._startIntermission(self: RMInternal): ()
	self:_changeState("Intermission")

	self._timer = task.delay(INTERMISSION_LENGTH, function()
		self:_startRound()
	end)
end

--[=[
	Starts the round by setting up the teams and players.
	@method _startRound
	@private
	@within RoundManager
]=]
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
	SetPlayerHandlers(blueTeam, "RoundCharacter", self._team1)
	SetPlayerHandlers(redTeam, "RoundCharacter", self._team2)

	self:_changeState("InRound")
	self:_setPhaseIndex(1)
end

--[=[
	Ends the round by setting all players to spectators and checking if enough players are left to start a new round.
	@method _endRound
	@private
	@within RoundManager
]=]
function RMPrivateMethods._endRound(self: RMInternal): ()
	if self._state == "PreRound" then
		self.StateChanged:Wait()
	elseif self._state ~= "InRound" then
		return
	end

	self:_changeState("PostRound")

	SetPlayerHandlers(self._players, "LobbyCharacter", SPECTATOR_TEAM)
	self._players = {}

	self:_checkPlayerCount()
end

--[=[
	Sets the current phase index and updates the state of the round manager.
	@method _setPhaseIndex
	@param index number
	@private
	@within RoundManager
]=]
function RMPrivateMethods._setPhaseIndex(self: RMInternal, index: number): ()
	self._phaseIndex = index

	local phase = PHASE_SEQUENCE[index]

	local isCombat = phase.Type == "Combat"
	if isCombat then
		TurfService:SetTurfPerKill(phase.TurfPerKill or 1)
	end

	for _, player in ipairs(self._players) do
		local handler = PlayerRegistry:GetHandler(player)
		if handler and handler:IsCharacterType("RoundCharacter") then
			(handler :: ServerTypes.RoundPlayerHandler):SetCombatEnabled(isCombat)
		else
			warn(string.format("[RoundManager:_setPhaseIndex]: %s does not have a RoundPlayerHandler", player.Name))
		end
	end

	print("[RoundManager:_setPhaseIndex]: Starting " .. phase.Type .. " phase " .. index)

	self._timer = task.delay(phase.Duration, function()
		self:_nextPhase()
	end)
end

--[=[
	Advances to the next phase in the sequence or ends the round if there are no more phases.
	@method _nextPhase
	@private
	@within RoundManager
]=]
function RMPrivateMethods._nextPhase(self: RMInternal): ()
	if self._phaseIndex < #PHASE_SEQUENCE then
		self:_setPhaseIndex(self._phaseIndex + 1)
	else
		self:_endRound()
	end
end

--[=[
	Checks if there are enough players to start the round and transitions to the intermission phase if there are.
	@method _checkPlayerCount
	@private
	@within RoundManager
]=]
function RMPrivateMethods._checkPlayerCount(self: RMInternal): ()
	if #Players:GetPlayers() >= MIN_PLAYER_COUNT then
		if self._state == "WaitingForPlayers" or self._state == "PostRound" then
			self:_startIntermission()
		end
	elseif self._state ~= "WaitingForPlayers" then
		self:_changeState("WaitingForPlayers")
	end
end

--[=[
	Removes a player from the round and ends the round if there are not enough players left.
	@method _removePlayerFromRound
	@param player Player
	@private
	@within RoundManager
]=]
function RMPrivateMethods._removePlayerFromRound(self: RMInternal, player: Player): ()
	local index = table.find(self._players, player)
	if index then
		table.remove(self._players, index)

		if #self._players < MIN_PLAYER_COUNT then
			self:_endRound()
		end
	end
end

--[=[
	Handles when a player is added to the game.
	@method _onPlayerAdded
	@param player Player
	@private
	@within RoundManager
]=]
function RMPrivateMethods._onPlayerAdded(self: RMInternal, player: Player): ()
	PlayerRegistry:CreateHandler(player, "LobbyCharacter")
	if self._state == "WaitingForPlayers" then
		self:_checkPlayerCount()
	end
end

--[=[
	Handles when a player is removed from the game.
	@method _onPlayerRemoving
	@param player Player
	@private
	@within RoundManager
]=]
function RMPrivateMethods._onPlayerRemoving(self: RMInternal, player: Player): ()
	if self._state == "PreRound" or self._state == "InRound" then
		self:_removePlayerFromRound(player)
	else
		self:_checkPlayerCount()
	end
end

Players.CharacterAutoLoads = false

return RoundManager.new()
