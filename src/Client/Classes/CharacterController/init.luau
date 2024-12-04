--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- External dependencies
local Trove = require(ReplicatedStorage.Packages.Trove)

-- Client modules
local Client = ReplicatedFirst.Client
local Types = require(Client.Types)

local TiltCharacter = require(Client.Classes.TiltCharacter)

type CharacterController = Types.CharacterController
type CCInternal = CharacterController & CCProtected
export type CCProtected = {
	_className: string,

	_trove: Trove.Trove,

	_isAlive: boolean,

	_tiltAccumulator: number,
	_tiltSendRate: number,
	_prevTiltAngle: number,

	_tiltCharacter: Types.TiltCharacter,

	_init: (self: CCInternal, instance: Model) -> (),

	_onDied: (self: CCInternal) -> (),

	_onPostSimulation: (self: CCInternal, deltaTime: number) -> (),
}

-- Player-related variables
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Remote events folder
local Remotes = ReplicatedStorage.Remotes.Character

--[=[
	CharacterController is an abstract base class for managing a player's character.

	This class provides foundational functionality such as tracking the character's state, 
	handling tilt updates, and cleaning up resources. It is designed to be extended by 
	subclasses for implementing specific character behaviors and should not be instantiated 
	directly.

	Responsibilities:
	- Manage character state (alive or dead).
	- Synchronize tilt data between client and server.
	- Clean up resources via a `Trove` instance.
]=]
local CharacterController = {}

local CCPublicMethods = {}
local CCProtectedMethods = {}

CharacterController.PublicMethods = CCPublicMethods
CharacterController.ProtectedMethods = CCProtectedMethods

--[=[
	Destroys the character controller, cleaning up all connections and resources used by it.
]=]
function CCPublicMethods.Destroy(self: CCInternal): ()
	self._trove:Clean()
end

--[=[
	Checks if the character controller is an instance of the given class name.
	@param className -- The class name to check against.
	@return boolean -- True if the instance is of the given class name, false otherwise.
]=]
function CCPublicMethods.IsA(self: CCInternal, className: string): boolean
	return self._className == className
end

function CCProtectedMethods._init(self: CCInternal, instance: Model): ()
	self._trove = Trove.new()

	self.Instance = instance

	self._isAlive = true

	self._tiltAccumulator = 0
	self._tiltSendRate = Remotes.Tilt.SendRate.Value
	self._prevTiltAngle = 0

	self._tiltCharacter = TiltCharacter.new(self.Instance, self._tiltSendRate)

	local humanoid = self.Instance:FindFirstChildOfClass("Humanoid") :: Humanoid
	self._trove:Connect(humanoid.Died, function()
		self:_onDied()
	end)

	self._trove:Connect(RunService.PostSimulation, function(deltaTime: number)
		self:_onPostSimulation(deltaTime)
	end)
end

function CCProtectedMethods._onDied(self: CCInternal): ()
	self._isAlive = false
	self:Destroy()
end

function CCProtectedMethods._onPostSimulation(self: CCInternal, deltaTime: number): ()
	if not self._isAlive then
		return
	end

	self._tiltAccumulator += deltaTime
	while self._tiltAccumulator >= self._tiltSendRate do
		self._tiltAccumulator -= self._tiltSendRate

		local tiltAngle = math.asin(Camera.CFrame.LookVector.Y)
		if tiltAngle ~= self._prevTiltAngle then
			-- Don't update the local tilt character when in first person mode
			if LocalPlayer.CameraMode ~= Enum.CameraMode.LockFirstPerson then
				self._tiltCharacter:Update(tiltAngle)
			end

			Remotes.Tilt:FireServer(tiltAngle)

			self._prevTiltAngle = tiltAngle
		end
	end
end

return CharacterController
