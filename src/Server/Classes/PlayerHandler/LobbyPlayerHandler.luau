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

--[=[
    `LobbyPlayerHandler` is a specialized subclass of `PlayerHandler` for managing players in the game lobby.

    This class extends the `PlayerHandler` superclass, adding functionality specific to lobby-related behavior, such as handling player remotes and character controller assignments during the lobby phase of the game.

    **Responsibilities:**
    - **Player Management:** Manages player-specific behavior while they are in the lobby.
    - **Remote Handling:** Sets up remotes specific to the lobby state.
    - **Character Controller Assignment:** Assigns a "LobbyCharacter" controller type to players.

    **Key Features:**
    - **Inheritance:** Inherits methods and properties from `PlayerHandler` for seamless integration with the player handling system.
    - **Custom Initialization:** Overrides the `_init` method to configure lobby-specific properties.
    - **Reusable Architecture:** Designed as part of the broader player management system, making it interchangeable with other `PlayerHandler` subclasses.

    **Public Methods:**
    - `new(instance: Player): LobbyPlayerHandler`: Constructs a `LobbyPlayerHandler` for the given player.

    **Notes:**
    - This class works in conjunction with the `PlayerHandler` superclass, leveraging its `ProtectedMethods` for shared functionality.
    - The `LobbyCharacter` controller type is set during initialization for use in lobby-related gameplay.
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

return LobbyPlayerHandler
