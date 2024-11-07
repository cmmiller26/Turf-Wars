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
type LPHInternal = LobbyPlayerHandler & PlayerHandler.PHInherited

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
