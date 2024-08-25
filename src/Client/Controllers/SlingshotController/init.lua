--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage.Packages.Trove)

local ProjectileCaster = require(ReplicatedFirst.Client.Modules.ProjectileCaster)

local LoadConfig = require(script.LoadConfig)

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

	_config: LoadConfig.Config,
	_animTracks: AnimTracks,

	_isFiring: boolean,
	_toFire: boolean,

	_raycastParams: RaycastParams,
	_projectileModifier: ProjectileCaster.ProjectileModifier,

	_init: (self: self, character: Model) -> (),

	_onProjectileImpact: (self: self, raycastResult: RaycastResult) -> (),
}

local Camera = Workspace.CurrentCamera

local Remotes = ReplicatedStorage.Remotes.Slingshot

local SlingshotController = {}
SlingshotController.__index = SlingshotController

function SlingshotController.new(instance: Model, character: Model): SlingshotController
	assert(
		typeof(instance) == "Instance" and instance:IsA("Model"),
		"SlingshotController.new(): Expected Model for argument #1, got " .. typeof(instance)
	)
	assert(
		typeof(character) == "Instance" and character:IsA("Model"),
		"SlingshotController.new(): Expected Model for argument #2, got " .. typeof(character)
	)

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
		print("Firing at speed " .. speed)

		local camCFrame = Camera.CFrame
		local origin = camCFrame.Position
		local direction = camCFrame.LookVector

		local timeStamp = Workspace:GetServerTimeNow()
		Remotes.Fire:FireServer(origin, direction, speed, timeStamp)

		self._projectileModifier.Speed = speed
		self._projectileModifier.TimeStamp = timeStamp

		ProjectileCaster.Cast(origin, direction, self._raycastParams, self._projectileModifier)

		task.wait(60 / self._config.RPM)
	end

	self._isFiring = false
end

function SlingshotController._init(self: self, character: Model)
	self._trove = Trove.new()

	self._equipped = false

	local config = self.Instance:FindFirstChild("Config")
	assert(
		typeof(config) == "Instance" and config:IsA("Configuration"),
		"SlingshotController._init(): Expected a 'Config' Configuration in self.Instance, got " .. typeof(config)
	)
	self._config = LoadConfig(config)

	do
		local animator = (character:FindFirstChild("Humanoid") :: Instance):FindFirstChild("Animator") :: Animator

		local animations = self.Instance:FindFirstChild("Animations")
		assert(
			typeof(animations) == "Instance" and animations:IsA("Folder"),
			"SlingshotController._init(): Expected a 'Animations' Folder in self.Instance, got " .. typeof(animations)
		)

		local idleAnim = animations:FindFirstChild("Idle")
		assert(
			typeof(idleAnim) == "Instance" and idleAnim:IsA("Animation"),
			"SlingshotController._init(): Expected an 'Idle' Animation in self.Instance.Animations, got "
				.. typeof(idleAnim)
		)
		local equipAnim = animations:FindFirstChild("Equip")
		assert(
			typeof(equipAnim) == "Instance" and equipAnim:IsA("Animation"),
			"SlingshotController._init(): Expected an 'Equip' Animation in self.Instance.Animations, got "
				.. typeof(equipAnim)
		)

		self._animTracks = {
			Idle = animator:LoadAnimation(idleAnim),
			Equip = animator:LoadAnimation(equipAnim),
		}
	end

	self._isFiring = false
	self._toFire = false

	self._raycastParams = RaycastParams.new()
	self._raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	self._raycastParams.FilterDescendantsInstances = { character }

	local onImpactEvent = Instance.new("BindableEvent")
	onImpactEvent.Event:Connect(function(raycastResult: RaycastResult)
		self:_onProjectileImpact(raycastResult)
	end)

	self._projectileModifier = {
		Gravity = self._config.Gravity,
		Lifetime = self._config.Lifetime,
		PVInstance = self._config.Projectile,
		OnImpact = onImpactEvent,
	}

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

function SlingshotController._onProjectileImpact(self: self, raycastResult: RaycastResult)
	print(raycastResult.Instance)
end

return SlingshotController
