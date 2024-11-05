--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)
local Types = require(ServerScriptService.Server.Types)

local PlayerHandler = require(script.Parent)

type LobbyPlayerHandler = Types.PlayerHandler
type LPHInternal = LobbyPlayerHandler & PlayerHandler.PHInherited & {
	_init: (self: LPHInternal) -> (),
}

local LobbyPlayerHandler = {}

local LPHPublicMethods = {}
local LPHPrivateMethods = {}

function LobbyPlayerHandler.new(instance: Player): LobbyPlayerHandler
	local self = setmetatable(
		PlayerHandler.new(instance) :: LPHInternal,
		{ __index = CreateMultiIndex(LPHPublicMethods, PlayerHandler.InheritedMethods, LPHPrivateMethods) }
	)

	self:_init()

	return self
end

function LPHPrivateMethods._init(self: LPHInternal): ()
	self._className = "LobbyPlayerHandler"
end

return LobbyPlayerHandler
