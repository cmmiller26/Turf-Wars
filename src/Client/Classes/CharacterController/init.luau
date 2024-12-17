--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

-- External dependencies
local SharedTypes = require(ReplicatedStorage.SharedTypes)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Grid = require(ReplicatedStorage.Utility.Grid)

-- Client modules
local Client = ReplicatedFirst.Client
local ClientTypes = require(Client.ClientTypes)

local TiltCharacter = require(Client.Classes.TiltCharacter)

type CharacterController = ClientTypes.CharacterController
export type CCProtected = {
	_characterType: SharedTypes.CharacterType,

	_trove: Trove.Trove,

	_humanoid: Humanoid,
	_isAlive: boolean,

	_isSneaking: boolean,
	_wasSneaking: boolean,
	_preSneakPos: Vector3,

	_tiltAccumulator: number,
	_tiltSendRate: number,
	_prevTiltAngle: number,

	_tiltCharacter: ClientTypes.TiltCharacter,

	_init: (self: CCInternal, instance: Model) -> (),

	_onDied: (self: CCInternal) -> (),

	_onPreSimulation: (self: CCInternal, deltaTime: number) -> (),
	_onPostSimulation: (self: CCInternal, deltaTime: number) -> (),
}
type CCInternal = CharacterController & CCProtected

-- Constants

local HUMANOID_SNEAK_SPEED = 8
local HUMANOID_SPRINT_SPEED = 24

local HUMANOID_HIP_HEIGHT = 3 -- The distance from the character's root part to the ground
local GROUND_RAYCAST_DISTANCE = HUMANOID_HIP_HEIGHT + 0.5

local VALID_SNEAK_HUMANOID_STATES = {
	[Enum.HumanoidStateType.Landed] = true,
	[Enum.HumanoidStateType.Running] = true,
}
local EDGE_SNEAK_DISTANCE = 1

-- Player-related variables
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Remote events folder
local Remotes = ReplicatedStorage.Remotes.Character

--[=[
	The character [Model] controlled by the character controller.
	@prop Instance Model
	@readonly
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
	The [Humanoid] instance of the character.
	@prop _humanoid Humanoid
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
	Whether the character is sneaking.
	@prop _isSneaking boolean
	@private
	@within CharacterController
]=]
--[=[
	Whether the character was sneaking in the previous frame.
	@prop _wasSneaking boolean
	@private
	@within CharacterController
]=]
--[=[
	The previous grid position the character was sneaking on.
	@prop _preSneakPos Vector3
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
	Enables or disables sneaking for the character. While sneaking, the character's movement is slowed, 
	and they are prevented from falling off block edges.
	@method Sneak
	@param toSneak boolean
	@private
	@within CharacterController
]=]
function CCPublicMethods.Sneak(self: CCInternal, toSneak: boolean): ()
	self._isSneaking = toSneak
	self._humanoid.WalkSpeed = toSneak and HUMANOID_SNEAK_SPEED or StarterPlayer.CharacterWalkSpeed
end

--[=[
	Enables or disables sprinting for the character. While sprinting, the character's movement speed is increased.
	@method Sprint
	@param toSprint boolean
	@private
	@within CharacterController
]=]
function CCPublicMethods.Sprint(self: CCInternal, toSprint: boolean): ()
	if self._isSneaking then
		return
	end
	self._humanoid.WalkSpeed = toSprint and HUMANOID_SPRINT_SPEED or StarterPlayer.CharacterWalkSpeed
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

	self._humanoid = self.Instance:FindFirstChildOfClass("Humanoid") :: Humanoid
	self._isAlive = true

	self._isSneaking = false
	self._wasSneaking = false
	self._preSneakPos = Vector3.new()

	self._tiltAccumulator = 0
	self._tiltSendRate = Remotes.Tilt.SendRate.Value
	self._prevTiltAngle = 0

	self._tiltCharacter = TiltCharacter.new(self.Instance, self._tiltSendRate)

	self._trove:Connect(self._humanoid.Died, function()
		self:_onDied()
	end)

	self._trove:Connect(RunService.PostSimulation, function(deltaTime: number)
		self:_onPreSimulation(deltaTime)
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
	Processes pre-simulation updates, such as handling sneaking behavior and edge detection.
	@method _onPreSimulation
	@param deltaTime number
	@private
	@within CharacterController
]=]
function CCPrivateMethods._onPreSimulation(self: CCInternal, deltaTime: number): ()
	if not self._isAlive then
		return
	end

	local justSnuck = self._isSneaking and not self._wasSneaking
	self._wasSneaking = self._isSneaking

	if not self._isSneaking and self._humanoid:GetStateEnabled(Enum.HumanoidStateType.Freefall) then
		return
	end

	local humanoidState = self._humanoid:GetState()
	if humanoidState == Enum.HumanoidStateType.Jumping then
		self._humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
		return
	elseif not VALID_SNEAK_HUMANOID_STATES[humanoidState] then
		return
	end

	local rootPart = self.Instance.PrimaryPart :: BasePart
	local rootCFrame = self.Instance:GetPivot()

	local sneakPos = Grid.SnapPosition(rootCFrame.Position)
	sneakPos = Vector3.new(sneakPos.X, rootCFrame.Position.Y, sneakPos.Z)
	if sneakPos == self._preSneakPos then
		return
	end

	if justSnuck then
		self._preSneakPos = sneakPos
		print("[CharacterController:_onPreSimulation]: Started sneaking")
		return
	end

	local direction = Vector3.new(0, -GROUND_RAYCAST_DISTANCE, 0)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { self.Instance }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	if humanoidState == Enum.HumanoidStateType.Landed then
		local raycastResult = Workspace:Blockcast(rootCFrame, rootPart.Size, direction, raycastParams)
		if raycastResult then
			local hitPos = raycastResult.Position
			local newSneakPos = Grid.SnapPosition(hitPos + (raycastResult.Instance.Position - hitPos) * Grid.SIZE / 2)
			self._preSneakPos = newSneakPos + Vector3.new(0, Grid.SIZE / 2 + HUMANOID_HIP_HEIGHT, 0)
			print("[CharacterController:_onPreSimulation]: Sneak jump landed")
		end
		return
	end

	if not Workspace:Raycast(self._preSneakPos, direction, raycastParams) then
		self._humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
		self._preSneakPos = sneakPos
		print("[CharacterController:_onPreSimulation]: Sneak has nothing to stand on")
		return
	end

	local minX, maxX = self._preSneakPos.X - Grid.SIZE / 2, self._preSneakPos.X + Grid.SIZE / 2
	local minZ, maxZ = self._preSneakPos.Z - Grid.SIZE / 2, self._preSneakPos.Z + Grid.SIZE / 2
	local isXEdge = rootCFrame.Position.X < minX or rootCFrame.Position.X > maxX
	local isZEdge = rootCFrame.Position.Z < minZ or rootCFrame.Position.Z > maxZ

	local origin = Vector3.new(
		isXEdge and sneakPos.X or self._preSneakPos.X,
		self._preSneakPos.Y,
		isZEdge and sneakPos.Z or self._preSneakPos.Z
	)
	if Workspace:Raycast(origin, direction, raycastParams) then
		self._humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
		self._preSneakPos = sneakPos
		return
	end

	if self._humanoid.Jump then
		self._humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		print("[CharacterController:_onPreSimulation]: Sneak jump")
		return
	end

	local xClamped = math.clamp(rootCFrame.Position.X, minX - EDGE_SNEAK_DISTANCE, maxX + EDGE_SNEAK_DISTANCE)
	local zClamped = math.clamp(rootCFrame.Position.Z, minZ - EDGE_SNEAK_DISTANCE, maxZ + EDGE_SNEAK_DISTANCE)

	if not self._isSneaking and (rootCFrame.Position.X ~= xClamped or rootCFrame.Position.Z ~= zClamped) then
		self._humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
		print("[CharacterController:_onPreSimulation]: Stopped sneaking and fell off edge")
		return
	end
	self._humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)

	local edgeProj = Vector3.zero
	if isXEdge and isZEdge then
		local xDiff = Vector3.new(sneakPos.X - self._preSneakPos.X, 0, 0)
		local zDiff = Vector3.new(0, 0, sneakPos.Z - self._preSneakPos.Z)
		if Workspace:Raycast(origin - zDiff, direction, raycastParams) then
			self._preSneakPos = sneakPos - zDiff
			isXEdge = false
		elseif Workspace:Raycast(origin - xDiff, direction, raycastParams) then
			self._preSneakPos = sneakPos - xDiff
			isZEdge = false
		end
	else
		local moveDirection = self._humanoid.MoveDirection
		if moveDirection ~= Vector3.zero then
			local edgeDir = Vector3.new(isXEdge and 1 or 0, 0, isZEdge and 1 or 0)
			local moveDelta = moveDirection * self._humanoid.WalkSpeed * deltaTime
			edgeProj = (moveDelta:Dot(edgeDir) / edgeDir.Magnitude ^ 2) * edgeDir
		end
	end

	self.Instance:PivotTo(
		CFrame.lookAlong(
			Vector3.new(
				isXEdge and xClamped or rootCFrame.Position.X + edgeProj.X,
				self._preSneakPos.Y,
				isZEdge and zClamped or rootCFrame.Position.Z + edgeProj.Z
			),
			rootCFrame.LookVector
		)
	)

	local rootVel = rootPart.AssemblyLinearVelocity
	rootPart.AssemblyLinearVelocity = Vector3.new(rootVel.X, 0, rootVel.Z)

	print("[CharacterController:_onPreSimulation]: Sneaking on edge")
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
