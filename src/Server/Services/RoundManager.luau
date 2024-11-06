--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

local PlayerHandler = ServerScriptService.Server.Classes.PlayerHandler
local LobbyPlayerHandler = require(PlayerHandler.LobbyPlayerHandler)
local RoundPlayerHandler = require(PlayerHandler.RoundPlayerHandler)

type RoundManager = {}
type RMInternal = RoundManager & {
	_state: RMState,

	_phaseIndex: number,

	_init: (self: RMInternal) -> (),

	_onPlayerAdded: (self: RMInternal, player: Player) -> (),
	_onPlayerRemoving: (self: RMInternal, player: Player) -> (),
}

type RMState = "WaitingForPlayers" | "Intermission" | "PreRound" | "InRound" | "PostRound"

local PHASE_SEQUENCE = {
	{
		Name = "Build",
		Duration = 60,
	},
	{
		Name = "Combat",
		Duration = 90,
	},
	{
		Name = "Build",
		Duration = 30,
	},
	{
		Name = "Combat",
		Duration = 90,
	},
}

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

	Players.PlayerAdded:Connect(function(player: Player)
		self:_onPlayerAdded(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		self:_onPlayerRemoving(player)
	end)
end

function RMPrivateMethods._onPlayerAdded(self: RMInternal, player: Player): ()
	LobbyPlayerHandler.new(player)
end
function RMPrivateMethods._onPlayerRemoving(self: RMInternal, player: Player): () end

Players.CharacterAutoLoads = false

return RoundManager.new()
