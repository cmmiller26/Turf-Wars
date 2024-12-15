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

--[=[
	LobbyPlayerHandler extends [PlayerHandler] to manage a client's [LobbyCharacterController]. 
	Currently, it handles basic player initialization and assigns the `LobbyCharacter` [CharacterType]. 
	This class will be expanded in the future to include lobby-specific features and gameplay preparations.

	@class LobbyPlayerHandler
	@tag PlayerHandler
]=]
local LobbyPlayerHandler = {}

local LPHPublicMethods = {}
local LPHPrivateMethods = {}

--[=[
	Constructs a new `LobbyPlayerHandler` for the given [Player].
	@param instance Player
	@return LobbyPlayerHandler
	@within LobbyPlayerHandler
]=]
function LobbyPlayerHandler.new(instance: Player): LobbyPlayerHandler
	local self = setmetatable({} :: LPHInternal, {
		__index = CreateMultiIndex(
			LPHPublicMethods,
			LPHPrivateMethods,
			PlayerHandler.PublicMethods,
			PlayerHandler.PrivateMethods
		),
	})

	self:_init(instance)

	return self
end

--[=[
	Overrides [PlayerHandler:_init].
	@method _init
	@param instance Player
	@private
	@tag Override
	@within LobbyPlayerHandler
]=]
function LPHPrivateMethods._init(self: LPHInternal, instance: Player): ()
	self._characterType = "LobbyCharacter"

	PlayerHandler.PrivateMethods._init(self, instance)
end

return LobbyPlayerHandler
