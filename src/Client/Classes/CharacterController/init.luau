--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- External dependencies
local SharedTypes = require(ReplicatedStorage.SharedTypes)
local Trove = require(ReplicatedStorage.Packages.Trove)

-- Client modules
local Client = ReplicatedFirst.Client
local ClientTypes = require(Client.ClientTypes)

local TiltCharacter = require(Client.Classes.TiltCharacter)

type CharacterController = ClientTypes.CharacterController
export type CCProtected = {
	_characterType: SharedTypes.CharacterType,

	_trove: Trove.Trove,

	_isAlive: boolean,

	_tiltAccumulator: number,
	_tiltSendRate: number,
	_prevTiltAngle: number,

	_tiltCharacter: ClientTypes.TiltCharacter,

	_init: (self: CCInternal, instance: Model) -> (),

	_onDied: (self: CCInternal) -> (),

	_onPostSimulation: (self: CCInternal, deltaTime: number) -> (),
}
type CCInternal = CharacterController & CCProtected

-- Player-related variables
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Remote events folder
local Remotes = ReplicatedStorage.Remotes.Character

--[=[
	The character [Model] controlled by the character controller.
	@prop Instance Model
	@within CharacterController
]=]

--[=[
	The [CharacterType] of the character controller.
	@prop _characterType CharacterType
	@private
	@within CharacterController
]=]
--[=[
	The [Trove] used to manage the character controller's connections and resources.
	@prop _trove Trove
	@private
	@within CharacterController
]=]
--[=[
	Whether the character is alive.
	@prop _isAlive boolean
	@private
	@within CharacterController
]=]
--[=[
	The time accumulator for updating the tilt angle of the character.
	@prop _tiltAccumulator number
	@private
	@within CharacterController
]=]
--[=[
	The rate at which the tilt angle of the character is sent to the server.
	@prop _tiltSendRate number
	@private
	@within CharacterController
]=]
--[=[
	The previous tilt angle of the character.
	@prop _prevTiltAngle number
	@private
	@within CharacterController
]=]
--[=[
	The [TiltCharacter] instance used to update the tilt angle of the character.
	@prop _tiltCharacter TiltCharacter
	@private
	@within CharacterController
]=]

--[=[
	CharacterController is an abstract base class designed to manage the behavior and state of a player-controlled character in the game. 
	It provides foundational functionality such as tilt angle management, resource cleanup, and integration with Roblox services. 
	As an abstract class, it cannot be instantiated directly but must be extended by subclasses that define specific character behaviors 
	and additional features.

	### Core Features:
	- **Tilt Management**: Tracks and updates the tilt angle of the character based on the camera's look vector and communicates 
	  these changes to the server for replication.
	- **Lifecycle Events**: Responds to key character lifecycle events, such as death, and handles associated cleanup operations.
	- **Simulation Updates**: Executes logic during the [RunService.PostSimulation] event to ensure consistent updates tied to the game loop.
	- **Resource Management**: Utilizes the [Trove] library to manage connections and ensure proper cleanup of resources.

	### Server Interaction:
	- The tilt updates are sent to the server via the `Tilt` [RemoteEvent], which is handled by the [RoundPlayerHandler].
	- The [RoundPlayerHandler] ensures that the tilt updates are replicated to other clients, allowing them to see the character's 
	  updated tilt in real-time.

	### Usage:
	By extending this class, developers can focus on implementing custom behaviors while leveraging the built-in infrastructure 
	for robust character management. Subclasses are expected to override and expand upon the methods and properties provided by 
	the base class to suit specific gameplay mechanics.

	@class CharacterController
	@client
	@tag Abstract
]=]
local CharacterController = {}

local CCPublicMethods = {}
local CCPrivateMethods = {}

CharacterController.PublicMethods = CCPublicMethods
CharacterController.PrivateMethods = CCPrivateMethods

--[=[
	Cleans up all connections and resources used by the character controller.
	@method Destroy
	@within CharacterController
]=]
function CCPublicMethods.Destroy(self: CCInternal): ()
	self._trove:Clean()
end

--[=[
	Returns whether the character controller is of the given [CharacterType].
	@method IsA
	@param characterType CharacterType
	@return boolean
	@within CharacterController
]=]
function CCPublicMethods.IsA(self: CCInternal, characterType: SharedTypes.CharacterType): boolean
	return self._characterType == characterType
end

--[=[
	Initializes the character controller with the given character [Model], constructing the local [TiltCharacter].
	@method _init
	@param instance Model
	@private
	@within CharacterController
]=]
function CCPrivateMethods._init(self: CCInternal, instance: Model): ()
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

--[=[
	Handles character death, marking the character controller as dead and destroying it.
	@method _onDied
	@private
	@within CharacterController
]=]
function CCPrivateMethods._onDied(self: CCInternal): ()
	self._isAlive = false
	self:Destroy()
end

--[=[
	Processes post-simulation updates, such as updating the tilt angle of the character.
	@method _onPostSimulation
	@param deltaTime number
	@private
	@within CharacterController
]=]
function CCPrivateMethods._onPostSimulation(self: CCInternal, deltaTime: number): ()
	if not self._isAlive then
		return
	end

	-- Update the tilt angle at a fixed rate
	self._tiltAccumulator += deltaTime
	while self._tiltAccumulator >= self._tiltSendRate do
		self._tiltAccumulator -= self._tiltSendRate

		local tiltAngle = math.asin(Camera.CFrame.LookVector.Y)
		-- Only send updates if the tilt angle has changed
		if tiltAngle ~= self._prevTiltAngle then
			-- Don't update the local tilt character when in first person mode
			if LocalPlayer.CameraMode ~= Enum.CameraMode.LockFirstPerson then
				self._tiltCharacter:Update(tiltAngle)
			end

			-- Send the tilt angle to the server for replication
			Remotes.Tilt:FireServer(tiltAngle)

			self._prevTiltAngle = tiltAngle
		end
	end
end

return CharacterController
