--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- External dependencies
local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

-- Server modules
local ServerTypes = require(ServerScriptService.Server.ServerTypes)

-- Superclass
local PlayerHandler = require(script.Parent)

type LobbyPlayerHandler = ServerTypes.PlayerHandler
type LPHInternal = LobbyPlayerHandler & PlayerHandler.PHProtected

local LobbyPlayerHandler = {}

local LPHPublicMethods = {}
local LPHPrivateMethods = {}

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

return LobbyPlayerHandler
