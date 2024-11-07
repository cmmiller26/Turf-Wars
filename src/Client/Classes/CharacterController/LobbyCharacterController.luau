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

-- Player-related references
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--[=[
	A LobbyCharacterController is a subclass of CharacterController for controlling the player's character while in the lobby.
]=]
local LobbyCharacterController = {}

local LCCPublicMethods = {}
local LCCPrivateMethods = {}

--[=[
	Constructs a LobbyCharacterController for the given character instance.
	@param instance Model -- The player's character model
	@return LobbyCharacterController -- The LobbyCharacterController instance
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

	-- Initialize the superclass
	CharacterController.ProtectedMethods._init(self, instance)

	LocalPlayer.CameraMode = Enum.CameraMode.Classic
	Camera.FieldOfView = FIELD_OF_VIEW
end

return LobbyCharacterController
