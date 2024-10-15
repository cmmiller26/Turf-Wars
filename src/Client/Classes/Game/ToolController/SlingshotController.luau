--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- External dependencies
local ProjectileService = require(ReplicatedFirst.Client.Services.ProjectileService)
local GetSlingshotConfig = require(ReplicatedStorage.Config.Game.GetSlingshotConfig)
local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

-- Superclass
local ToolController = require(script.Parent)

export type SlingshotController = ToolController.ToolController & {
	FireProjectile: (self: SlingshotController, toFire: boolean) -> (),
}
type SCInternal = SlingshotController & ToolController.TCInherited & {
	_config: GetSlingshotConfig.Config,

	_toFire: boolean,

	_onProjectileImpactEvent: BindableEvent,

	_init: (self: SCInternal) -> (),

	_onProjectileImpact: (
		self: SCInternal,
		projectile: ProjectileService.Projectile,
		raycastResult: RaycastResult
	) -> (),
}

-- Player reference
local LocalPlayer = Players.LocalPlayer

-- Workspace references
local Camera = Workspace.CurrentCamera
local Blocks = Workspace:WaitForChild("Blocks")

-- ReplicatedStorage references
local Remotes = ReplicatedStorage.Remotes.Game.Slingshot

--[=[
	A SlingshotController is a subclass of ToolController for using the slingshot tool.
	It inherits all the basic tool functionality such as equipping and unequipping.
	It adds the ability to fire projectiles.
]=]
local SlingshotController = {}

local SCPublicMethods = {}
local SCPrivateMethods = {}

--[=[
	Constructs a SlingshotController for the given slingshot instance and character.
	@param instance The slingshot model.
	@param character The player's character model.
	@return SlingshotController
]=]
function SlingshotController.new(instance: Model, character: Model): SlingshotController
	local self = setmetatable(
		ToolController.new(instance, character) :: SCInternal,
		{ __index = CreateMultiIndex(ToolController.InheritedMethods, SCPublicMethods, SCPrivateMethods) }
	)

	self.MouseIcon = "rbxasset://textures/GunCursor.png"

	self:_init()

	return self
end

--[=[
	Fires a projectile from the slingshot.
	Draws the slingshot when toFire is true, fires the projectile when toFire is false.
	@param toFire boolean -- Whether to draw the slingshot or fire the projectile.
]=]
function SCPublicMethods.FireProjectile(self: SlingshotController, toFire: boolean): ()
	local internal = self :: SCInternal

	internal._toFire = toFire
	-- Ensure the slingshot is equipped, set to fire, and not currently active
	if not self.Equipped or self.IsActive or not internal._toFire then
		return
	end

	self.IsActive = true

	local speed = internal._config.Projectile.StartSpeed -- Start the projectile at its initial speed
	while self.Equipped and internal._toFire do
		-- Increase the speed of the projectile while the slingshot is drawn
		speed = math.min(
			speed + internal._config.DrawSpeed * RunService.PostSimulation:Wait(),
			internal._config.Projectile.MaxSpeed
		)
	end

	-- Ensure the slingshot is still equipped
	if self.Equipped then
		local origin = Camera.CFrame.Position
		local direction = Camera.CFrame.LookVector

		local timestamp = Workspace:GetServerTimeNow()
		-- Send fire projectile request to the server
		Remotes.FireProjectile:FireServer(origin, direction, speed, timestamp)

		-- Set up raycast parameters to exclude the character
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = { self.Instance.Parent :: Instance }
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude

		local projectileModifier: ProjectileService.Modifier = {
			Speed = speed,
			Gravity = internal._config.Projectile.Gravity,

			Lifetime = internal._config.Projectile.Lifetime,

			PVInstance = internal._config.Projectile.PVInstance,
			Color = LocalPlayer.TeamColor.Color,

			Timestamp = timestamp,

			OnImpact = internal._onProjectileImpactEvent,
		}
		-- Cast the projectile
		ProjectileService.Cast(origin, direction, raycastParams, projectileModifier)

		task.wait(60 / internal._config.RPM)
	end

	self.IsActive = false
end

function SCPrivateMethods._init(self: SCInternal): ()
	self._className = "SlingshotController"

	-- Load the Slingshot configuration
	local configuration = self.Instance:FindFirstChildOfClass("Configuration")
	if not configuration then
		error("Configuration not found in Instance", 2)
	end
	self._config = GetSlingshotConfig(configuration)

	self._toFire = false

	-- Create an event to handle projectile impacts
	local bindableEvent = Instance.new("BindableEvent")
	bindableEvent.Event:Connect(function(projectile: ProjectileService.Projectile, raycastResult: RaycastResult)
		self:_onProjectileImpact(projectile, raycastResult)
	end)
	self._onProjectileImpactEvent = bindableEvent
end

function SCPrivateMethods._onProjectileImpact(
	self: SCInternal,
	projectile: ProjectileService.Projectile,
	raycastResult: RaycastResult
): ()
	local hitPart = raycastResult.Instance
	if not hitPart:IsA("BasePart") then
		return
	end

	local hitParent = hitPart.Parent
	if not hitParent then
		return
	end

	if hitParent == Blocks then
		if hitPart.BrickColor == LocalPlayer.TeamColor then
			return
		end
		-- Send block hit registration request to the server
		Remotes.RegisterHit:FireServer("Block", hitPart, Workspace:GetServerTimeNow(), projectile.Timestamp)
	elseif hitParent:FindFirstChildOfClass("Humanoid") then
		-- Send character hit registration request to the server
		Remotes.RegisterHit:FireServer("Character", hitPart, Workspace:GetServerTimeNow(), projectile.Timestamp)
	end
end

return SlingshotController
