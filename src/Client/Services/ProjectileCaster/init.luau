--!strict

-- Services
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Client modules
local ClientTypes = require(ReplicatedFirst.Client.ClientTypes)

-- Constants
local THREAD_COUNT = 8

--[=[
	ProjectileCaster is a high-performance module for managing the simulation and casting of projectiles. 
	It utilizes parallel Luau threads via [Actor] instances to distribute computational tasks, ensuring 
	optimized performance for high-frequency projectile simulations. This design is inspired by 
	[Secure-Cast by 1Axen](https://github.com/1Axen/Secure-Cast) and integrates seamlessly with game environments 
	that require fast, reliable projectile handling.

	### Core Features:
	- **Parallel Processing**: Distributes projectile simulation tasks across multiple [Actor] instances, 
	  leveraging Roblox's parallel Luau capabilities to reduce performance bottlenecks.
	- **Customizable Behavior**: Allows the use of [ProjectileModifier] to adjust projectile properties such as speed, gravity, and lifetime.
	- **Dynamic Actor Assignment**: Automatically assigns tasks to the least-busy [Actor] for efficient workload distribution.
	- **Projectile Management**: Stores active projectiles in the `PROJECTILE_CASTER_VISUALS` folder in [Workspace], 
	  enabling proper organization and rendering of projectiles.

	### Usage:
	To cast a projectile, specify its origin, direction, raycast parameters, and any desired modifiers:
	```lua
	local origin = Vector3.new(0, 10, 0)
	local direction = Vector3.new(1, 0, 0).Unit * 100 -- Direction scaled by speed
	local raycastParams = RaycastParams.new()
	local modifier = {
		Speed = 100,
		Gravity = Vector3.new(0, -9.81, 0),
		Lifetime = 5,
	}

	ProjectileCaster.Cast(origin, direction, raycastParams, modifier)
	```

	@class ProjectileCaster
	@client
]=]
local ProjectileCaster = {}

local actors: { Actor } = {}

--[=[
	Casts a [Projectile] with the specified origin, direction, raycast parameters, and [ProjectileModifier].
	@param origin Vector3
	@param direction Vector3
	@param raycastParams RaycastParams
	@param modifier ProjectileModifier
	@within ProjectileCaster
]=]
function ProjectileCaster.Cast(
	origin: Vector3,
	direction: Vector3,
	raycastParams: RaycastParams,
	modifier: ClientTypes.ProjectileModifier
)
	table.sort(actors, function(a, b)
		return a:GetAttribute("Tasks") < b:GetAttribute("Tasks")
	end)
	actors[1]:SendMessage("Cast", origin, direction, raycastParams, modifier)
end

local actorFolder = Instance.new("Folder")
actorFolder.Name = "PROJECTILE_CASTER_ACTORS"
actorFolder.Parent = ReplicatedFirst
for _ = 1, THREAD_COUNT do
	local actor = Instance.new("Actor")
	actor:SetAttribute("Tasks", 0)
	actor.Parent = actorFolder

	local controller = script.Controller:Clone()
	controller.Enabled = true
	controller.Parent = actor

	table.insert(actors, actor)
end

local visualFolder = Instance.new("Folder")
visualFolder.Name = "PROJECTILE_CASTER_VISUALS"
visualFolder.Parent = Workspace

-- Wait to initialize the actors until their controllers are enabled
RunService.PostSimulation:Wait()
for _, actor in ipairs(actors) do
	actor:SendMessage("Initialize", script.Simulation)
end

return ProjectileCaster
