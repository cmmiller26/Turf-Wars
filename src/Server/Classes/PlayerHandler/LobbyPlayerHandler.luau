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
	LobbyPlayerHandler extends PlayerHandler for managing players in the game lobby.
]=]
local LobbyPlayerHandler = {}

local LPHPublicMethods = {}
local LPHPrivateMethods = {}

--[=[
	Constructs a lobby player handler for the given player.
	@param instance -- The `Player` to handle remotes for.
	@return LobbyPlayerHandler -- The lobby player handler instance.
]=]
function LobbyPlayerHandler.new(instance: Player): LobbyPlayerHandler
	local self = setmetatable({} :: LPHInternal, {
		__index = CreateMultiIndex(
			LPHPublicMethods,
			LPHPrivateMethods,
			PlayerHandler.PublicMethods,
			PlayerHandler.ProtectedMethods
		),
	})

	self:_init(instance)

	return self
end

-- @Override
function LPHPrivateMethods._init(self: LPHInternal, instance: Player): ()
	self._className = "LobbyPlayerHandler"

	PlayerHandler.ProtectedMethods._init(self, instance)

	self._charControllerType = "LobbyCharacter"
end

-- @Override
function LPHPrivateMethods._onDied(self: LPHInternal): ()
	PlayerHandler.ProtectedMethods._onDied(self)

	self._trove:Add(task.delay(RESPAWN_TIME, function()
		self.Instance:LoadCharacter()
	end))
end

return LobbyPlayerHandler
