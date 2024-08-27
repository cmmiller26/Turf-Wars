--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage.Packages.Trove)

local LoadSlingshotConfig = require(ReplicatedStorage.Config.LoadSlingshotConfig)

local IsCharacterAlive = require(ReplicatedStorage.Utility.IsCharacterAlive)

local ProjectileCaster = require(ReplicatedFirst.Client.Modules.ProjectileCaster)

type AnimTracks = {
	Idle: AnimationTrack,
	Equip: AnimationTrack,
}

export type SlingshotController = {
	Instance: Model,
	Destroy: (self: SlingshotController) -> (),

	Equip: (self: SlingshotController) -> (),
	Unequip: (self: SlingshotController) -> (),

	Fire: (self: SlingshotController, toFire: boolean) -> (),
}
type self = SlingshotController & {
	_trove: Trove.Trove,

	_equipped: boolean,

	_config: LoadSlingshotConfig.Config,
	_animTracks: AnimTracks,

	_isFiring: boolean,
	_toFire: boolean,

	_onImpactEvent: BindableEvent,

	_init: (self: self, character: Model) -> (),

	_onProjectileImpact: (self: self, projectile: ProjectileCaster.Projectile, raycastResult: RaycastResult) -> (),
}

local Camera = Workspace.CurrentCamera

local Remotes = ReplicatedStorage.Remotes.Slingshot

local SlingshotController = {}
SlingshotController.__index = SlingshotController

function SlingshotController.new(instance: Model, character: Model): SlingshotController
	local self = setmetatable({} :: self, SlingshotController)

	self.Instance = instance
	self:_init(character)

	return self
end
function SlingshotController.Destroy(self: self)
	self._trove:Clean()
end

function SlingshotController.Equip(self: self)
	if self._equipped then
		return
	end
	self._equipped = true

	self._animTracks.Idle:Play()
	self._animTracks.Equip:Play(0)
end
function SlingshotController.Unequip(self: self)
	if not self._equipped then
		return
	end
	self._equipped = false

	for _, animTrack in pairs(self._animTracks) do
		animTrack:Stop()
	end
end

function SlingshotController.Fire(self: self, toFire: boolean)
	if not self._equipped then
		return
	end

	if not (toFire and self._toFire) then
		self._toFire = toFire
	end

	if not self._toFire or self._isFiring then
		return
	end

	self._isFiring = true

	local speed = self._config.StartSpeed
	while self._toFire and self._equipped do
		speed = math.min(self._config.MaxSpeed, speed + self._config.Resistance * RunService.PostSimulation:Wait())
	end

	if self._equipped then
		print("Firing Slingshot at speed " .. speed)

		local camCFrame = Camera.CFrame
		local origin = camCFrame.Position
		local direction = camCFrame.LookVector

		local timeStamp = Workspace:GetServerTimeNow()
		Remotes.Fire:FireServer(origin, direction, speed, timeStamp)

		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { self.Instance.Parent :: Instance }

		local projectileModifier: ProjectileCaster.Modifier = {
			Speed = speed,
			Gravity = self._config.Gravity,

			Lifetime = self._config.Lifetime,

			TimeStamp = timeStamp,
			PVInstance = self._config.Projectile,

			OnImpact = self._onImpactEvent,
		}

		ProjectileCaster.Cast(origin, direction, raycastParams, projectileModifier)

		task.wait(60 / self._config.RPM)
	end

	self._isFiring = false
end

function SlingshotController._init(self: self, character: Model)
	self._trove = Trove.new()

	self._equipped = false

	local configuration = self.Instance:FindFirstChildOfClass("Configuration")
	assert(configuration, "SlingshotController._init(): Expected Configuration in Instance")
	self._config = LoadSlingshotConfig(configuration)

	do
		local animator = (character:FindFirstChildOfClass("Humanoid") :: Humanoid):FindFirstChildOfClass("Animator")
		assert(animator, "SlingshotController._init(): Could not find Animator in Character")

		local animations = self.Instance:FindFirstChild("Animations")
		assert(
			typeof(animations) == "Instance" and animations:IsA("Folder"),
			"SlingshotController._init(): Expected 'Animations' Folder in Instance, got " .. typeof(animations)
		)

		local idleAnim = animations:FindFirstChild("Idle")
		assert(
			typeof(idleAnim) == "Instance" and idleAnim:IsA("Animation"),
			"SlingshotController._init(): Expected an 'Idle' Animation in Instance.Animations, got " .. typeof(idleAnim)
		)
		local equipAnim = animations:FindFirstChild("Equip")
		assert(
			typeof(equipAnim) == "Instance" and equipAnim:IsA("Animation"),
			"SlingshotController._init(): Expected an 'Equip' Animation in Instance.Animations, got "
				.. typeof(equipAnim)
		)
		self._animTracks = {
			Idle = animator:LoadAnimation(idleAnim),
			Equip = animator:LoadAnimation(equipAnim),
		}
		print("Loaded SlingshotController animations")
	end

	self._isFiring = false
	self._toFire = false

	self._onImpactEvent = Instance.new("BindableEvent")
	self._onImpactEvent.Event:Connect(function(projectile: ProjectileCaster.Projectile, raycastResult: RaycastResult)
		self:_onProjectileImpact(projectile, raycastResult)
	end)

	do
		self._trove:Connect(UserInputService.InputBegan, function(input: InputObject, gameProcessedEvent: boolean)
			if gameProcessedEvent then
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				self:Fire(true)
			end
		end)
		self._trove:Connect(UserInputService.InputEnded, function(input: InputObject, gameProcessedEvent: boolean)
			if gameProcessedEvent then
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				self:Fire(false)
			end
		end)
	end
end

function SlingshotController._onProjectileImpact(
	self: self,
	projectile: ProjectileCaster.Projectile,
	raycastResult: RaycastResult
)
	local character = raycastResult.Instance.Parent
	if not (character and character:IsA("Model") and IsCharacterAlive(character)) then
		return
	end

	Remotes.HitCharacter:FireServer(raycastResult.Instance, Workspace:GetServerTimeNow(), projectile.TimeStamp)
end

return SlingshotController
