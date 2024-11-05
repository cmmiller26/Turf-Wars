--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedFirst.Client.Types)
local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

local CharacterController = require(script.Parent)

type LobbyCharacterController = Types.CharacterController
type LCCInternal = LobbyCharacterController & CharacterController.CCInherited & {
	_init: (self: LCCInternal) -> (),
}

local LobbyCharacterController = {}

local LCCPublicMethods = {}
local LCCPrivateMethods = {}

function LobbyCharacterController.new(instance: Model): LobbyCharacterController
	local self = setmetatable(
		CharacterController.new(instance) :: LCCInternal,
		{ __index = CreateMultiIndex(LCCPublicMethods, CharacterController.InheritedMethods, LCCPrivateMethods) }
	)

	self:_init()

	return self
end

function LCCPrivateMethods._init(self: LCCInternal): ()
	self._className = "LobbyCharacterController"
end

return LobbyCharacterController
