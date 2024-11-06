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

local RESPAWN_TIME = 5

local LobbyPlayerHandler = {}

local LPHPublicMethods = {}
local LPHPrivateMethods = {}

function LobbyPlayerHandler.new(instance: Player): LobbyPlayerHandler
	local self = setmetatable(
		PlayerHandler.new(instance) :: LPHInternal,
		{ __index = CreateMultiIndex(LPHPublicMethods, LPHPrivateMethods, PlayerHandler.InheritedMethods) }
	)

	self:_init()

	return self
end

function LPHPrivateMethods._init(self: LPHInternal): ()
	self._className = "LobbyPlayerHandler"
	self._charControllerType = "LobbyCharacter"

	self.Instance:LoadCharacter()
end

-- @Override
function LPHPrivateMethods._onDied(self: LPHInternal): ()
	PlayerHandler.InheritedMethods._onDied(self)

	task.wait(RESPAWN_TIME)

	self.Instance:LoadCharacter()
end

return LobbyPlayerHandler
