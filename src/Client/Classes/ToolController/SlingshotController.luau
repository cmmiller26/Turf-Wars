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

-- Constants
local MOUSE_ICON = "rbxasset://textures/GunCursor.png"

-- Player-related variables
local LocalPlayer = Players.LocalPlayer

-- Workspace variables
local Camera = Workspace.CurrentCamera
local Blocks = Workspace:WaitForChild("Blocks")

-- Remote events folder
local Remotes = ReplicatedStorage.Remotes.Tool.Slingshot

--[=[
    The `SlingshotController` module manages the functionality of a slingshot tool, allowing players to draw and fire projectiles with dynamic speed and trajectory.

    This class extends `ToolController`, integrating seamlessly with the `RoundCharacterController` for enhanced gameplay mechanics.
	It handles projectile casting, impact detection, and synchronization with the server, ensuring smooth and responsive interactions.

    **Responsibilities:**
    - **Projectile Firing:** Handles the drawing and firing of projectiles with speed scaling based on draw duration.
    - **Impact Registration:** Detects and processes projectile impacts on blocks and humanoids, sending relevant data to the server.
    - **Tool State Management:** Manages tool state transitions, animations, and interactions within the game environment.
    - **Configuration Integration:** Utilizes tool-specific configurations for properties such as projectile speed, gravity, and lifetime.

    **Key Features:**
    - **Dynamic Projectile Behavior:** Simulates realistic projectile trajectories using `ProjectileCaster`.
    - **Impact Handling:** Differentiates between impacts on blocks and characters, applying appropriate logic for each.
    - **Server Synchronization:** Communicates projectile firing and impact data to the server for consistent gameplay.
    - **Customizable Settings:** Leverages a configuration object to define slingshot-specific behavior.

    **Public Methods:**
    - `ActivatePrimary(self: SCInternal, toActivate: boolean): ()`: Handles the drawing and firing logic of the slingshot tool.

    **Private Methods:**
    - `_fireProjectile(self: SCInternal, toFire: boolean): ()`: Manages the core logic for projectile firing, including speed calculation and simulation setup.
    - `_onProjectileImpact(self: SCInternal, projectile: ProjectileCaster.Projectile, raycastResult: RaycastResult): ()`: Processes projectile impact events, distinguishing between blocks and characters.

    **Notes:**
    - Assumes the slingshot tool includes a `Configuration` instance defining projectile properties.
    - Designed for use within a team-based game environment, with logic to prevent friendly fire.
    - Relies on the `ProjectileCaster` module for projectile simulation and impact detection.
]=]
local SlingshotController = {}

local SCPublicMethods = {}
local SCPrivateMethods = {}

--[=[
	Constructs a slingshot controller for the given slingshot model and round character controller using it.
	@param instance -- The slingshot `Model` to control.
	@param roundCharController -- The `RoundCharacterController` using the slingshot.
	@return SlingshotController -- The slingshot controller instance.
]=]
function SlingshotController.new(
	instance: Model,
	roundCharController: Types.RoundCharacterController
): SlingshotController
	local self = setmetatable({} :: SCInternal, {
		__index = CreateMultiIndex(
			SCPublicMethods,
			SCPrivateMethods,
			ToolController.PublicMethods,
			ToolController.ProtectedMethods
		),
	})

	self:_init(instance, roundCharController)

	return self
end

--[=[
	Fires a projectile from the slingshot.
	Draws the slingshot when toActivate is true, fires the projectile when toActivate is false.
	@param toActivate -- Whether to draw the slingshot or fire the projectile.
]=]
-- @Override
function SCPublicMethods.ActivatePrimary(self: SCInternal, toActivate: boolean): ()
	self:_fireProjectile(toActivate)
end

-- @Override
function SCPrivateMethods._init(
	self: SCInternal,
	instance: Model,
	roundCharController: Types.RoundCharacterController
): ()
	self._className = "SlingshotController"

	ToolController.ProtectedMethods._init(self, instance, roundCharController)

	self.MouseIcon = MOUSE_ICON

	local configuration = self.Instance:FindFirstChildOfClass("Configuration")
	if not configuration then
		error("[SlingshotController._init]: Configuration not found in Instance", 2)
	end
	self._config = GetSlingshotConfig(configuration)

	self._toFire = false

	self._onProjectileImpactEvent = self._trove:Add(Instance.new("BindableEvent"))
	self._trove:Connect(
		self._onProjectileImpactEvent.Event,
		function(projectile: ProjectileCaster.Projectile, raycastResult: RaycastResult)
			self:_onProjectileImpact(projectile, raycastResult)
		end
	)
end

function SCPrivateMethods._fireProjectile(self: SCInternal, toFire: boolean): ()
	self._toFire = toFire
	if not self.Equipped or self.IsActive or not self._toFire or not self._roundCharController:GetCombatEnabled() then
		return
	end

	self.IsActive = true

	local speed = self._config.Projectile.StartSpeed
	local beginTick = os.clock()
	while self.Equipped and self._toFire do
		RunService.PostSimulation:Wait()
	end
	-- Update speed based on how long the player was drawing the slingshot
	speed = math.min(speed + self._config.DrawSpeed * (os.clock() - beginTick), self._config.Projectile.MaxSpeed)

	-- Ensure the slingshot is still equipped
	if self.Equipped then
		local origin = Camera.CFrame.Position
		local direction = Camera.CFrame.LookVector

		local timestamp = Workspace:GetServerTimeNow()
		Remotes.FireProjectile:FireServer(origin, direction, speed, timestamp)

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

		print("[SlingshotController._onProjectileImpact]: Hit block")

		Remotes.RegisterHit:FireServer("Block", hitPart, Workspace:GetServerTimeNow(), projectile.Timestamp)
	else
		local humanoid = hitParent:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		local player = Players:GetPlayerFromCharacter(hitParent)
		if not player or player.Team == LocalPlayer.Team then
			return
		end

		print(string.format("[SlingshotController._onProjectileImpact]: Hit %s's %s", hitParent.Name, hitPart.Name))

		Remotes.RegisterHit:FireServer("Character", hitPart, Workspace:GetServerTimeNow(), projectile.Timestamp)
	end
end

return SlingshotController
