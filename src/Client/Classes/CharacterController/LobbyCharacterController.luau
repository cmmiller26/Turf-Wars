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
type LCCInternal = LobbyCharacterController & CharacterController.CCInherited & {
	_init: (self: LCCInternal) -> (),
}

-- Constants
local FIELD_OF_VIEW = 70

-- Player-related references
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--[=[
	A LobbyCharacterController inherits CharacterController and is responsible for managing the player's character when in the lobby.
]=]
local LobbyCharacterController = {}

local LCCPublicMethods = {}
local LCCPrivateMethods = {}

--[=[
	Constructs a LobbyCharacterController for the given character.
	@param instance Model -- The player's character model
	@return LobbyCharacterController
]=]
function LobbyCharacterController.new(instance: Model): LobbyCharacterController
	local self = setmetatable(
		CharacterController.new(instance) :: LCCInternal,
		{ __index = CreateMultiIndex(LCCPublicMethods, LCCPrivateMethods, CharacterController.InheritedMethods) }
	)

	self:_init()

	return self
end

function LCCPrivateMethods._init(self: LCCInternal): ()
	self._className = "LobbyCharacterController"

	LocalPlayer.CameraMode = Enum.CameraMode.Classic
	Camera.FieldOfView = FIELD_OF_VIEW

	CharacterController.InheritedMethods._testFunction(self :: any)
end

return LobbyCharacterController
