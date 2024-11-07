--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- External dependencies
local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

-- Server modules
local Types = require(ServerScriptService.Server.Types)

-- Superclass
local PlayerHandler = require(script.Parent)

type LobbyPlayerHandler = Types.PlayerHandler
type LPHInternal = LobbyPlayerHandler & PlayerHandler.PHProtected

-- Constants
local RESPAWN_TIME = 5

--[=[
	A LobbyPlayerHandler inherits PlayerHandler to handle a player while in the lobby.
]=]
local LobbyPlayerHandler = {}

local LPHPublicMethods = {}
local LPHPrivateMethods = {}

--[=[
	Constructs a LobbyPlayerHandler for the given player.
	@param instance Player -- The player instance
	@return LobbyPlayerHandler
]=]
function LobbyPlayerHandler.new(instance: Player): LobbyPlayerHandler
	local self = setmetatable(
		{} :: LPHInternal,
		{ __index = CreateMultiIndex(LPHPublicMethods, LPHPrivateMethods, PlayerHandler) }
	)

	self:_init(instance)

	return self
end

-- @Override
function LPHPrivateMethods._init(self: LPHInternal, instance: Player): ()
	self._className = "LobbyPlayerHandler"

	PlayerHandler._init(self, instance)

	self._charControllerType = "LobbyCharacter"

	self.Instance:LoadCharacter()
end

-- @Override
function LPHPrivateMethods._onDied(self: LPHInternal): ()
	PlayerHandler._onDied(self)

	task.wait(RESPAWN_TIME)

	self.Instance:LoadCharacter()
end

return LobbyPlayerHandler
