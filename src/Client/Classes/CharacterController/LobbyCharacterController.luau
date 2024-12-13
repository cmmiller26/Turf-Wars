--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- External dependencies
local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

-- Client modules
local ClientTypes = require(ReplicatedFirst.Client.ClientTypes)

-- Superclass
local CharacterController = require(script.Parent)

type LobbyCharacterController = ClientTypes.CharacterController
type LCCInternal = LobbyCharacterController & CharacterController.CCProtected

-- Constants
local FIELD_OF_VIEW = 70

-- Player-related variables
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--[=[
	LobbyCharacterController extends [CharacterController] to manage a character within the lobby.
	@class LobbyCharacterController
	@tag CharacterController
]=]
local LobbyCharacterController = {}

local LCCPublicMethods = {}
local LCCPrivateMethods = {}

--[=[
	Constructs a new `LobbyCharacterController` for the given character model.
	@param instance Model
	@return LobbyCharacterController
	@within LobbyCharacterController
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

--[=[
	Overrides [CharacterController:_init] to initialize the lobby character controller with the given character model.
	@method _init
	@param instance Model
	@private
	@tag Override
	@within LobbyCharacterController
]=]
function LCCPrivateMethods._init(self: LCCInternal, instance: Model): ()
	self._characterType = "Lobby"

	CharacterController.ProtectedMethods._init(self, instance)

	LocalPlayer.CameraMode = Enum.CameraMode.Classic
	Camera.FieldOfView = FIELD_OF_VIEW
end

return LobbyCharacterController
