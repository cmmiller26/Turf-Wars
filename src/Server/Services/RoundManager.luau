--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

local Classes = ServerScriptService.Server.Classes
local PlayerHandler = require(Classes.PlayerHandler)
local LobbyPlayerHandler = require(Classes.PlayerHandler.LobbyPlayerHandler)
local RoundPlayerHandler = require(Classes.PlayerHandler.RoundPlayerHandler)

type RoundManager = {}
type RMInternal = RoundManager & {
	_state: RMState,

	_phaseIndex: number,

	_players: { Player },

	_init: (self: RMInternal) -> (),

	_changeState: (self: RMInternal, newState: RMState) -> (),

	_setPhaseIndex: (self: RMInternal, index: number) -> (),
	_nextPhase: (self: RMInternal) -> (),

	_onPlayerAdded: (self: RMInternal, player: Player) -> (),
	_onPlayerRemoving: (self: RMInternal, player: Player) -> (),
}

type RMState = "WaitingForPlayers" | "Intermission" | "PreRound" | "InRound" | "PostRound"

type Phase = {
	Type: "Build" | "Combat",
	Duration: number,
}

local MIN_PLAYER_COUNT = 1

local INTERMISSION_LENGTH = 60

local PHASE_SEQUENCE = {
	{ Type = "Build", Duration = 60 },
	{ Type = "Combat", Duration = 90 },
	{ Type = "Build", Duration = 30 },
	{ Type = "Combat", Duration = 90 },
}

do -- TEMP: Shorten durations for testing
	INTERMISSION_LENGTH = 5
	for _, phase in ipairs(PHASE_SEQUENCE) do
		phase.Duration = 5
	end
end

local function SetPlayerHandlers(players: { Player }, handlerClass: any): ()
	for _, player in ipairs(players) do
		local handler = PlayerHandler.GetHandlerFromPlayer(player)
		if handler then
			handler:Destroy()
		end
		handlerClass.new(player)
	end
end

local RoundManager = {}

local RMPublicMethods = {}
local RMPrivateMethods = {}

function RoundManager.new(): RoundManager
	local self = setmetatable({} :: RMInternal, { __index = CreateMultiIndex(RMPublicMethods, RMPrivateMethods) })

	self:_init()

	return self
end

function RMPrivateMethods._init(self: RMInternal): ()
	self._state = "WaitingForPlayers"

	self._phaseIndex = 0

	self._players = {}

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
	self._state = newState

	print("RoundManager: Changing state to", newState)

	if newState == "Intermission" then
		task.delay(INTERMISSION_LENGTH, function()
			self:_changeState("PreRound")
		end)
	elseif newState == "PreRound" then
		self._players = Players:GetPlayers()
		SetPlayerHandlers(self._players, RoundPlayerHandler)
		self:_changeState("InRound")
	elseif newState == "InRound" then
		self:_setPhaseIndex(1)
	elseif newState == "PostRound" then
		SetPlayerHandlers(self._players, LobbyPlayerHandler)
		self:_changeState("Intermission")
	end
end

function RMPrivateMethods._setPhaseIndex(self: RMInternal, index: number): ()
	self._phaseIndex = index

	local phase = PHASE_SEQUENCE[index]

	print("RoundManager: Starting " .. phase.Type .. " phase " .. index)

	task.delay(phase.Duration, function()
		self:_nextPhase()
	end)
end
function RMPrivateMethods._nextPhase(self: RMInternal): ()
	if self._state ~= "InRound" then
		return
	end

	if self._phaseIndex == #PHASE_SEQUENCE then
		self:_changeState("PostRound")
	else
		self:_setPhaseIndex(self._phaseIndex + 1)
	end
end

function RMPrivateMethods._onPlayerAdded(self: RMInternal, player: Player): ()
	LobbyPlayerHandler.new(player)
	if self._state == "WaitingForPlayers" and #Players:GetPlayers() >= MIN_PLAYER_COUNT then
		self:_changeState("Intermission")
	end
end
function RMPrivateMethods._onPlayerRemoving(self: RMInternal, player: Player): ()
	table.remove(self._players, table.find(self._players, player))
	if #self._players < MIN_PLAYER_COUNT then
		self:_changeState("WaitingForPlayers")
	end
end

Players.CharacterAutoLoads = false

return RoundManager.new()
