--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- External dependencies
local Trove = require(ReplicatedStorage.Packages.Trove)

local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

local Client = ReplicatedFirst.Client
local Types = require(Client.Types)

local TiltCharacter = require(Client.Classes.TiltCharacter)

type CharacterController = Types.CharacterController
type CCInternal = CharacterController & CCInherited & {
	_tiltAccumulator: number,
	_tiltSendRate: number,
	_prevTiltAngle: number,

	_tiltCharacter: Types.TiltCharacter,

	_init: (self: CCInternal) -> (),

	_onPostSimulation: (self: CCInternal, deltaTime: number) -> (),
}
export type CCInherited = {
	_className: string,

	_trove: Trove.Trove,
}

-- Player-related references
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Remote folder reference
local Remotes = ReplicatedStorage.Remotes.Character

--[=[
	CharacterController is an abstract class that provides basic functionality for managing a character.
	The base class is responsible for sending tilt data to the server.
]=]
local CharacterController = {}

local CCPublicMethods = {}
local CCPrivateMethods = {}

--[=[
	Constructs a CharacterController for the given character.
	@param instance Model -- The character model to control
	@return CharacterController
]=]
function CharacterController.new(instance: Model): CharacterController
	local self = setmetatable({} :: CCInternal, { __index = CreateMultiIndex(CCPublicMethods, CCPrivateMethods) })

	self.Instance = instance

	self:_init()

	return self
end

--[=[
	Destroys the CharacterController, cleaning up any resources.
]=]
function CCPublicMethods.Destroy(self: CharacterController): ()
	(self :: CCInternal)._trove:Clean()
end

--[=[
	Checks if the CharacterController is an instance of the given class.
	@param className string -- The class name to check against
	@return boolean -- Whether the CharacterController is an instance of the given class
]=]
function CCPublicMethods.IsA(self: CharacterController, className: string): boolean
	return (self :: CCInternal)._className == className
end

function CCPrivateMethods._init(self: CCInternal): ()
	self._trove = Trove.new()

	self._tiltAccumulator = 0
	self._tiltSendRate = Remotes.Tilt.SendRate.Value
	self._prevTiltAngle = 0

	self._tiltCharacter = TiltCharacter.new(self.Instance, self._tiltSendRate)

	self._trove:Connect(RunService.PostSimulation, function(deltaTime: number)
		CCPrivateMethods._onPostSimulation(self, deltaTime)
	end)
end

function CCPrivateMethods._onPostSimulation(self: CCInternal, deltaTime: number): ()
	-- Send tilt data to the server at the fixed send rate
	self._tiltAccumulator += deltaTime
	while self._tiltAccumulator >= self._tiltSendRate do
		self._tiltAccumulator -= self._tiltSendRate

		local tiltAngle = math.asin(Camera.CFrame.LookVector.Y)
		if tiltAngle ~= self._prevTiltAngle then
			-- Only update the local tilt character if the camera is not in first person mode
			if LocalPlayer.CameraMode ~= Enum.CameraMode.LockFirstPerson then
				self._tiltCharacter:Update(tiltAngle)
			end

			Remotes.Tilt:FireServer(tiltAngle)

			self._prevTiltAngle = tiltAngle
		end
	end
end

CharacterController.InheritedMethods = {
	Destroy = CCPublicMethods.Destroy,
	IsA = CCPublicMethods.IsA,
}

return CharacterController
