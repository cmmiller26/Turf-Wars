--!strict

-- Services
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- External dependencies
local Trove = require(ReplicatedStorage.Packages.Trove)

local Types = require(ReplicatedFirst.Client.Types)
local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

type CharacterController = Types.CharacterController
type CCInternal = CharacterController & CCInherited & {
	_init: (self: CCInternal) -> (),

	_tiltAccumulator: number,
	_tiltSendRate: number,
	_prevTiltAngle: number,

	_onPostSimulation: (self: CCInternal, deltaTime: number) -> (),
}
export type CCInherited = {
	_className: string,

	_trove: Trove.Trove,
}

-- Camera reference
local Camera = Workspace.CurrentCamera

-- Remote folder reference
local Remotes = ReplicatedStorage.Remotes

--[=[
	CharacterController is an abstract class that provides basic functionality for managing a character.
	It is responsible for sending tilt data to the server.
]=]
local CharacterController = {}

local CCPublicMethods = {}
local CCPrivateMethods = {}

CharacterController.InheritedMethods = CCPublicMethods

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

	self._trove:Connect(RunService.PostSimulation, function(deltaTime: number)
		self:_onPostSimulation(deltaTime)
	end)
end

function CCPrivateMethods._onPostSimulation(self: CCInternal, deltaTime: number): ()
	-- Send tilt data to the server at the fixed send rate
	self._tiltAccumulator += deltaTime
	while self._tiltAccumulator >= self._tiltSendRate do
		self._tiltAccumulator -= self._tiltSendRate

		local tiltAngle = math.asin(Camera.CFrame.LookVector.Y)
		if tiltAngle ~= self._prevTiltAngle then
			Remotes.Tilt:FireServer(tiltAngle)
			self._prevTiltAngle = tiltAngle
		end
	end
end

return CharacterController
