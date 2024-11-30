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
	LobbyCharacterController extends CharacterController for managing players in the game lobby.
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
