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
    The `CharacterController` module is an abstract base class for managing a player's character in the game. It provides core functionality for handling character state, tilt synchronization, and resource cleanup, designed to be extended by subclasses for specific behaviors.

    **Responsibilities:**
    - **State Management:** Tracks whether the character is alive or dead and cleans up resources upon death.
    - **Tilt Synchronization:** Calculates the camera tilt angle and synchronizes it between the client and server for consistent gameplay interactions.
    - **Resource Management:** Uses `Trove` for managing and cleaning up connections and resources.

    **Key Features:**
    - **Abstract Base Class:** Serves as a foundational class to be extended by specific character controller implementations.
    - **Tilt Handling:** Integrates with `TiltCharacter` to manage client-side tilt updates and animations.
    - **Server Synchronization:** Periodically sends tilt data to the server at a configurable rate.
    - **Automatic Cleanup:** Ensures proper cleanup of resources and connections when the character dies or the controller is destroyed.

    **Public Methods:**
    - `Destroy(self: CCInternal): ()`: Cleans up all resources and connections used by the character controller.
    - `IsA(self: CCInternal, className: string): boolean`: Checks if the character controller is an instance of a specific class.

    **Protected Methods:**
    - `_init(self: CCInternal, instance: Model): ()`: Initializes the character controller with a character model.
    - `_onDied(self: CCInternal): ()`: Handles character death, marking the character as not alive and cleaning up resources.
    - `_onPostSimulation(self: CCInternal, deltaTime: number): ()`: Handles periodic tilt updates based on camera orientation.

    **Notes:**
    - **Extension Required:** This class is abstract and should not be instantiated directly. Subclasses should extend it to implement specific behaviors.
    - **Tilt Integration:** Requires `TiltCharacter` for managing tilt animations and interactions.
    - **Dependencies:** Relies on `Trove` for resource management and the server's `Remotes.Tilt` for tilt synchronization.

    This module provides a robust foundation for creating custom character controllers with dynamic behavior and tilt-based interactions.
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
