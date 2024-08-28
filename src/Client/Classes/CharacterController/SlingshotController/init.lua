--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage.Packages.Trove)

local IsCharacterAlive = require(ReplicatedStorage.Utility.IsCharacterAlive)

local LoadSlingshotConfig = require(ReplicatedStorage.Config.LoadSlingshotConfig)

local ProjectileCaster = require(ReplicatedFirst.Client.Modules.ProjectileCaster)

export type SlingshotController = {
	Instance: Model,

	Equipped: boolean,

	Destroy: (self: SlingshotController) -> (),

	Equip: (self: SlingshotController) -> (),
	Unequip: (self: SlingshotController) -> (),

	Fire: (self: SlingshotController, toFire: boolean) -> (),
}
type self = SlingshotController & {
	_trove: Trove.Trove,

	_config: LoadSlingshotConfig.Config,

	_animTracks: AnimationTracks,

	_isFiring: boolean,
	_toFire: boolean,

	_onImpactEvent: BindableEvent,

	_init: (self: self, character: Model) -> (),

	_onProjectileImpact: (self: self, projectile: ProjectileCaster.Projectile, raycastResult: RaycastResult) -> (),
}

type AnimationTracks = {
	Idle: AnimationTrack,
	Equip: AnimationTrack,
}

local Camera = Workspace.CurrentCamera

local Remotes = ReplicatedStorage.Remotes.Slingshot

local SlingshotController = {}
SlingshotController.__index = SlingshotController

function SlingshotController.new(instance: Model, character: Model): SlingshotController
	local self = setmetatable({} :: self, SlingshotController)

	self.Instance = instance

	self.Equipped = false

	self:_init(character)

	return self
end
function SlingshotController.Destroy(self: self)
	self._trove:Clean()
end

function SlingshotController.Equip(self: self)
	if self.Equipped then
		return
	end
	self.Equipped = true

	self._animTracks.Idle:Play()
	self._animTracks.Equip:Play(0)
end
function SlingshotController.Unequip(self: self)
	if not self.Equipped then
		return
	end
	self.Equipped = false

	self:Fire(false)

	for _, animTrack in pairs(self._animTracks) do
		animTrack:Stop()
	end
end

function SlingshotController.Fire(self: self, toFire: boolean)
	if not (toFire and self._toFire) then
		self._toFire = toFire
	end

	if not (self._toFire and self.Equipped) or self._isFiring then
		return
	end

	self._isFiring = true

	local speed = self._config.StartSpeed
	while self._toFire and self.Equipped do
		speed = math.min(speed + self._config.Resistance * RunService.PostSimulation:Wait(), self._config.MaxSpeed)
	end

	if self.Equipped then
		local origin = Camera.CFrame.Position
		local direction = Camera.CFrame.LookVector

		local timeStamp = Workspace:GetServerTimeNow()
		Remotes.Fire:FireServer(origin, direction, speed, timeStamp)

		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = { self.Instance.Parent :: Instance }
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude

		local projectileModifier: ProjectileCaster.Modifier = {
			Speed = speed,
			Gravity = self._config.Gravity,

			Lifetime = self._config.Lifetime,

			PVInstance = self._config.Projectile,

			TimeStamp = timeStamp,

			OnImpact = self._onImpactEvent,
		}
		ProjectileCaster.Cast(origin, direction, raycastParams, projectileModifier)

		task.wait(60 / self._config.RPM)
	end

	self._isFiring = false
end

function SlingshotController._init(self: self, character: Model)
	self._trove = Trove.new()

	local configuration = self.Instance:FindFirstChildOfClass("Configuration")
	if not configuration then
		error("Configuration not found in slingshot", 2)
	end
	self._config = LoadSlingshotConfig(configuration)

	do
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
		local animator = humanoid:FindFirstChildOfClass("Animator") :: Animator

		local animations = self.Instance:FindFirstChild("Animations")
		if not (animations and animations:IsA("Folder")) then
			error("'Animations' Folder not found in slingshot", 2)
		end

		local idleAnim = animations:FindFirstChild("Idle")
		if not (idleAnim and idleAnim:IsA("Animation")) then
			error("'Idle' Animation not found in slingshot animations", 2)
		end
		local equipAnim = animations:FindFirstChild("Equip")
		if not (equipAnim and equipAnim:IsA("Animation")) then
			error("'Equip' Animation not found in slingshot animations", 2)
		end

		self._animTracks = {
			Idle = self._trove:Add(animator:LoadAnimation(idleAnim)),
			Equip = self._trove:Add(animator:LoadAnimation(equipAnim)),
		}
	end

	self._isFiring = false
	self._toFire = false

	self._onImpactEvent = self._trove:Add(Instance.new("BindableEvent"))
	self._onImpactEvent.Event:Connect(function(projectile: ProjectileCaster.Projectile, raycastResult: RaycastResult)
		self:_onProjectileImpact(projectile, raycastResult)
	end)

	do
		self._trove:Connect(UserInputService.InputBegan, function(input: InputObject, gameProocessedEvent: boolean)
			if gameProocessedEvent then
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				self:Fire(true)
			end
		end)
		self._trove:Connect(UserInputService.InputEnded, function(input: InputObject, gameProocessedEvent: boolean)
			if gameProocessedEvent then
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
	local hitPart = raycastResult.Instance
	if not hitPart:IsA("BasePart") then
		return
	end

	local character = hitPart.Parent
	if not (character and character:IsA("Model") and IsCharacterAlive(character)) then
		return
	end

	Remotes.RegisterHit:FireServer(hitPart, Workspace:GetServerTimeNow(), projectile.TimeStamp)
end

return SlingshotController
