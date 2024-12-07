--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- External dependencies
local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

-- Client modules
local Types = require(ReplicatedFirst.Client.Types)

-- Superclass
local CharacterController = require(script.Parent)

type LobbyCharacterController = Types.CharacterController
type LCCInternal = LobbyCharacterController & CharacterController.CCProtected

-- Constants
local FIELD_OF_VIEW = 70

-- Player-related variables
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--[=[
    The `LobbyCharacterController` module extends the `CharacterController` to manage a character within the game lobby.
	It customizes the base functionality of `CharacterController` to fit the lobby environment, focusing on user experience and camera settings.

    **Responsibilities:**
    - **Camera Management:** Adjusts the camera to a classic mode with a specific field of view for the lobby experience.
    - **State Initialization:** Inherits and initializes core character state management from `CharacterController`.

    **Key Features:**
    - **Extension of CharacterController:** Inherits foundational methods for state management, tilt synchronization, and cleanup from `CharacterController`.
    - **Lobby-Specific Behavior:** Configures the camera for a more relaxed and exploratory environment, suitable for lobbies.
    - **Seamless Integration:** Maintains compatibility with the broader character management system while providing lobby-specific customization.

    **Public Methods:**
    - `new(instance: Model): LobbyCharacterController`: Constructs a new `LobbyCharacterController` for the specified character model.

    **Protected Methods:**
    - `_init(self: LCCInternal, instance: Model): ()`: Overrides the base `_init` method to apply lobby-specific camera settings.

    **Constants:**
    - `FIELD_OF_VIEW`: Defines the camera's field of view while the character is in the lobby.

    **Notes:**
    - **Inherits from CharacterController:** Leverages core functionality like tilt handling, cleanup, and state management from the parent class.
    - **Lobby Environment Focused:** Designed specifically for use in game lobbies, where interactions and gameplay mechanics are relaxed compared to active rounds.
    - **Camera Integration:** Configures camera settings to enhance the lobby experience.

    This module provides a tailored experience for characters in the game lobby, seamlessly extending the core functionality of `CharacterController`.
]=]
local LobbyCharacterController = {}

local LCCPublicMethods = {}
local LCCPrivateMethods = {}

--[=[
	Constructs a lobby character controller for the given character model.
	@param instance -- The character `Model` to control.
	@return LobbyCharacterController -- The lobby character controller instance.
]=]
function LobbyCharacterController.new(instance: Model): LobbyCharacterController
	local self = setmetatable({} :: LCCInternal, {
		__index = CreateMultiIndex(
			LCCPublicMethods,
			LCCPrivateMethods,
			CharacterController.PublicMethods,
			CharacterController.ProtectedMethods
		),
	})

	self:_init(instance)

	return self
end

-- @Override
function LCCPrivateMethods._init(self: LCCInternal, instance: Model): ()
	self._className = "LobbyCharacterController"

	CharacterController.ProtectedMethods._init(self, instance)

	LocalPlayer.CameraMode = Enum.CameraMode.Classic
	Camera.FieldOfView = FIELD_OF_VIEW
end

return LobbyCharacterController
