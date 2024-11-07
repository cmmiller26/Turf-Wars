--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- External dependencies
local ProjectileCaster = require(ReplicatedFirst.Client.Services.ProjectileCaster)
local GetSlingshotConfig = require(ReplicatedStorage.Config.GetSlingshotConfig)
local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

-- Client modules
local Types = require(ReplicatedFirst.Client.Types)

-- Superclass
local ToolController = require(script.Parent)

type SlingshotController = Types.ToolController
type SCInternal = SlingshotController & ToolController.TCProtected & {
	_config: GetSlingshotConfig.Config,

	_toFire: boolean,

	_onProjectileImpactEvent: BindableEvent,

	_fireProjectile: (self: SCInternal, toFire: boolean) -> (),

	_onProjectileImpact: (
		self: SCInternal,
		projectile: ProjectileCaster.Projectile,
		raycastResult: RaycastResult
	) -> (),
}

-- Player reference
local LocalPlayer = Players.LocalPlayer

-- Workspace references
local Camera = Workspace.CurrentCamera
local Blocks = Workspace:WaitForChild("Blocks")

-- ReplicatedStorage references
local Remotes = ReplicatedStorage.Remotes.Tool.Slingshot

--[=[
	A SlingshotController is a subclass of ToolController for using the slingshot tool.
	It adds the ability to fire projectiles.
]=]
local SlingshotController = {}

local SCPublicMethods = {}
local SCPrivateMethods = {}

--[=[
    Constructs a SlingshotController for the given slingshot instance and character.
    @param instance Model -- The slingshot instance.
    @param character Model -- The character model
    @return SlingshotController -- The SlingshotController instance.
]=]
function SlingshotController.new(instance: Model, character: Model): SlingshotController
	local self = setmetatable({} :: SCInternal, {
		__index = CreateMultiIndex(
			SCPublicMethods,
			SCPrivateMethods,
			ToolController.PublicMethods,
			ToolController.ProtectedMethods
		),
	})

	self:_init(instance, character)

	return self
end

--[=[
	Fires a projectile from the slingshot.
	Draws the slingshot when toActivate is true, fires the projectile when toActivate is false.
	@param toActivate boolean -- Whether to draw the slingshot or fire the projectile.
]=]
-- @Override
function SCPublicMethods.ActivatePrimary(self: SlingshotController, toActivate: boolean): ()
	(self :: SCInternal):_fireProjectile(toActivate)
end

-- @Override
function SCPrivateMethods._init(self: SCInternal, instance: Model, character: Model): ()
	self._className = "SlingshotController"

	-- Initialize the superclass
	ToolController.ProtectedMethods._init(self, instance, character)

	self.MouseIcon = "rbxasset://textures/GunCursor.png"

	-- Load the Slingshot configuration
	local configuration = self.Instance:FindFirstChildOfClass("Configuration")
	if not configuration then
		error("Configuration not found in Instance", 2)
	end
	self._config = GetSlingshotConfig(configuration)

	self._toFire = false

	-- Create an event to handle projectile impacts
	local bindableEvent = Instance.new("BindableEvent")
	bindableEvent.Event:Connect(function(projectile: ProjectileCaster.Projectile, raycastResult: RaycastResult)
		self:_onProjectileImpact(projectile, raycastResult)
	end)
	self._onProjectileImpactEvent = bindableEvent
end

function SCPrivateMethods._fireProjectile(self: SCInternal, toFire: boolean): ()
	self._toFire = toFire
	-- Ensure the slingshot is equipped, set to fire, and not currently active
	if not self.Equipped or self.IsActive or not self._toFire then
		return
	end

	self.IsActive = true

	local speed = self._config.Projectile.StartSpeed -- Start the projectile at its initial speed
	while self.Equipped and self._toFire do
		-- Increase the speed of the projectile while the slingshot is drawn
		speed = math.min(
			speed + self._config.DrawSpeed * RunService.PostSimulation:Wait(),
			self._config.Projectile.MaxSpeed
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

		local projectileModifier: ProjectileCaster.Modifier = {
			Speed = speed,
			Gravity = self._config.Projectile.Gravity,

			Lifetime = self._config.Projectile.Lifetime,

			PVInstance = self._config.Projectile.PVInstance,
			Color = LocalPlayer.TeamColor.Color,

			Timestamp = timestamp,

			OnImpact = self._onProjectileImpactEvent,
		}
		-- Cast the projectile
		ProjectileCaster.Cast(origin, direction, raycastParams, projectileModifier)

		task.wait(60 / self._config.RPM)
	end

	self.IsActive = false
end

function SCPrivateMethods._onProjectileImpact(
	_,
	projectile: ProjectileCaster.Projectile,
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
