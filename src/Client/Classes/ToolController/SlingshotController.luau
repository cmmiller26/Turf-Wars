--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- External dependencies
local SharedTypes = require(ReplicatedStorage.SharedTypes)
local GetSlingshotConfig = require(ReplicatedStorage.Config.GetSlingshotConfig)
local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

-- Client modules
local Client = ReplicatedFirst.Client
local ClientTypes = require(Client.ClientTypes)
local ProjectileCaster = require(Client.Services.ProjectileCaster)

-- Superclass
local ToolController = require(script.Parent)

type SlingshotController = ClientTypes.ToolController
type SCInternal = SlingshotController & ToolController.TCProtected & {
	_config: SharedTypes.SlingshotConfig,

	_toFire: boolean,

	_onProjectileImpactEvent: BindableEvent,

	_fireProjectile: (self: SCInternal, toFire: boolean) -> (),

	_onProjectileImpact: (
		self: SCInternal,
		projectile: ClientTypes.Projectile,
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
	The [SlingshotConfig] generated from the [Configuration] found in the slingshot controller's `Instance`.
	@prop _config: SlingshotConfig
	@private
	@within SlingshotController
]=]
--[=[
	Whether the player is currently drawing the slingshot.
	@prop _toFire: boolean
	@private
	@within SlingshotController
]=]
--[=[
	A [BindableEvent] to be passed to the [ProjectileCaster] to handle projectile impacts.
	@prop _onProjectileImpactEvent: BindableEvent
	@private
	@within SlingshotController
]=]

--[=[
	SlingshotController extends [ToolController] to manage the behavior of a slingshot tool during gameplay. 
	It allows players to fire projectiles using the [ProjectileCaster], handling the physics, visuals, and interactions 
	of the projectiles. The slingshot is equipped with a charging mechanic that determines projectile speed based on 
	how long the player draws before firing.

	### Core Features:
	- **Projectile Firing**: Allows players to fire projectiles with configurable speed, gravity, and lifetime.
	- **Charging Mechanic**: Increases projectile speed dynamically based on the draw duration, up to a defined maximum.
	- **Impact Handling**: Detects and processes projectile impacts on blocks or characters, registering hits with the server.
	- **Real-Time Integration**: Uses Roblox's [RunService] to ensure smooth and consistent updates during gameplay.

	### Server Interaction:
	- The `_fireProjectile` method fires the `FireProjectile` [RemoteEvent] to notify the server about the origin, direction, 
	  speed, and timestamp of the projectile being fired.
	- The `_onProjectileImpact` method fires the `RegisterHit` [RemoteEvent] to notify the server of projectile impacts, 
	  specifying the [ProjectileHitType], the impacted part, and timing details.
	- These remotes are handled by the [RoundPlayerHandler] on the server, which processes the projectile firing and 
	  hit registration to synchronize gameplay across clients and ensure consistent game state management.

	### Highlights:
	- Implements the `ActivatePrimary` method to manage the slingshot's firing behavior.
	- Uses [ProjectileCaster] for raycasting and managing projectile trajectories and collisions.
	
	@class SlingshotController
	@tag ToolController
]=]
local SlingshotController = {}

local SCPublicMethods = {}
local SCPrivateMethods = {}

--[=[
	Constructs a new `SlingshotController` for the given tool [Model] and [RoundCharacterController].
	@param instance Model
	@param roundCharController RoundCharacterController
	@return SlingshotController
	@within SlingshotController
]=]
function SlingshotController.new(
	instance: Model,
	roundCharController: ClientTypes.RoundCharacterController
): SlingshotController
	local self = setmetatable({} :: SCInternal, {
		__index = CreateMultiIndex(
			SCPublicMethods,
			SCPrivateMethods,
			ToolController.PublicMethods,
			ToolController.PrivateMethods
		),
	})

	self:_init(instance, roundCharController)

	return self
end

--[=[
	Overrides [ToolController:ActivatePrimary] to fire a projectile.
	If `toActivate` is true, the slingshot will be drawn until the method is called again with `toActivate` set to false,
	at which point the projectile will be fired.
	@method ActivatePrimary
	@param toActivate boolean
	@tag Override
	@within SlingshotController
]=]
function SCPublicMethods.ActivatePrimary(self: SCInternal, toActivate: boolean): ()
	self:_fireProjectile(toActivate)
end

--[=[
	Overrides [ToolController:_init] to generate the [SlingshotConfig] and create the `_onProjectileImpactEvent` [BindableEvent].
	@method _init
	@private
	@tag Override
	@within SlingshotController
]=]
function SCPrivateMethods._init(
	self: SCInternal,
	instance: Model,
	roundCharController: ClientTypes.RoundCharacterController
): ()
	self._toolType = "Slingshot"

	ToolController.PrivateMethods._init(self, instance, roundCharController)

	self.MouseIcon = MOUSE_ICON

	local configuration = self.Instance:FindFirstChildOfClass("Configuration")
	if not configuration then
		error("[SlingshotController:_init]: Configuration not found in Instance", 2)
	end
	self._config = GetSlingshotConfig(configuration)

	self._toFire = false

	self._onProjectileImpactEvent = self._trove:Add(Instance.new("BindableEvent"))
	self._trove:Connect(
		self._onProjectileImpactEvent.Event,
		function(projectile: ClientTypes.Projectile, raycastResult: RaycastResult)
			self:_onProjectileImpact(projectile, raycastResult)
		end
	)
end

--[=[
	If `toFire` is true, the slingshot will be drawn, increasing the speed of the projectile,
	until the method is called again with `toFire` set to false, at which point the projectile will be fired.
	@method _fireProjectile
	@param toFire boolean
	@private
	@within SlingshotController
]=]
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

		local projectileModifier: ClientTypes.ProjectileModifier = {
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

--[=[
	Handles the impact of a projectile on a [BasePart], registering the hit with the server as either a block or a character.
	@method _onProjectileImpact
	@param projectile ProjectileCaster.Projectile
	@param raycastResult RaycastResult
	@private
	@within SlingshotController
]=]
function SCPrivateMethods._onProjectileImpact(_, projectile: ClientTypes.Projectile, raycastResult: RaycastResult): ()
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

		print("[SlingshotController:_onProjectileImpact]: Hit block")

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

		print(string.format("[SlingshotController:_onProjectileImpact]: Hit %s's %s", hitParent.Name, hitPart.Name))

		Remotes.RegisterHit:FireServer("Character", hitPart, Workspace:GetServerTimeNow(), projectile.Timestamp)
	end
end

return SlingshotController
