--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Teams = game:GetService("Teams")

local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

local Server = ServerScriptService.Server
local Types = require(Server.Types)

local PlayerManager = require(Server.Services.PlayerManager)

type RoundManager = {
	GetCurrentPhase: (self: RoundManager) -> Phase,
}
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

local MIN_PLAYER_COUNT = 2

local INTERMISSION_LENGTH = 60

local PHASE_SEQUENCE: { Phase } = {
	{ Type = "Build", Duration = 40 },
	{ Type = "Combat", Duration = 90 },
	{ Type = "Build", Duration = 20 },
	{ Type = "Combat", Duration = 90 },
}

local TEAMS = {
	Blue = Teams:FindFirstChild("Blue"),
	Red = Teams:FindFirstChild("Red"),
	Spectators = Teams:FindFirstChild("Spectators"),
}

do -- TEMP
	MIN_PLAYER_COUNT = 1
	INTERMISSION_LENGTH = 5
	for _, phase in ipairs(PHASE_SEQUENCE) do
		phase.Duration = 5
	end
end

local function SetPlayerHandlers(players: { Player }, handlerType: string, team: Team): ()
	for _, player in ipairs(players) do
		player.Team = team
		PlayerManager:CreateHandler(player, handlerType)
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

function RMPublicMethods.GetCurrentPhase(self: RMInternal): Phase
	return PHASE_SEQUENCE[self._phaseIndex]
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

		local blueTeam = {}
		local redTeam = {}
		for index, player in ipairs(self._players) do
			if index % 2 == 0 then
				table.insert(blueTeam, player)
			else
				table.insert(redTeam, player)
			end
		end
		SetPlayerHandlers(blueTeam, "Round", TEAMS.Blue)
		SetPlayerHandlers(redTeam, "Round", TEAMS.Red)

		self:_changeState("InRound")
	elseif newState == "InRound" then
		self:_setPhaseIndex(1)
	elseif newState == "PostRound" then
		SetPlayerHandlers(self._players, "Lobby", TEAMS.Spectators)
		self:_changeState("Intermission")
	end
end

function RMPrivateMethods._setPhaseIndex(self: RMInternal, index: number): ()
	self._phaseIndex = index

	local phase = PHASE_SEQUENCE[index]
	for _, player in ipairs(self._players) do
		local handler = PlayerManager:GetHandler(player)
		if handler and handler:IsA("RoundPlayerHandler") then
			(handler :: Types.RoundPlayerHandler):SetCombatEnabled(phase.Type == "Combat")
		else
			warn(string.format("%s's RoundPlayerHandler not found", player.Name))
		end
	end

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
	PlayerManager:CreateHandler(player, "Lobby")

	if self._state == "WaitingForPlayers" and #Players:GetPlayers() >= MIN_PLAYER_COUNT then
		self:_changeState("Intermission")
	end
end
function RMPrivateMethods._onPlayerRemoving(self: RMInternal, player: Player): ()
	local index = table.find(self._players, player)
	if index then
		table.remove(self._players, index)

		if #self._players < MIN_PLAYER_COUNT then
			self:_changeState("WaitingForPlayers")
		end
	end
end

Players.CharacterAutoLoads = false

return RoundManager.new()
