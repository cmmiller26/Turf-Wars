--!strict

-- Services
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Simulation module
local Simulation = require(script.Simulation)
export type Modifier = Simulation.Modifier
export type Projectile = Simulation.Projectile

-- Constants
local THREAD_COUNT = 8

--[=[
	The `ProjectileCaster` module manages the simulation and casting of projectiles using parallel Luau threads for optimized performance.

	This implementation utilizes `Actor` instances to distribute projectile simulation tasks across multiple threads, enabling high-performance handling of numerous projectiles in real-time.
	Inspired by [Secure-Cast by 1Axen](https://github.com/1Axen/Secure-Cast), this module is designed for scalability and smooth gameplay, even in scenarios with a high number of projectiles.

	Responsibilities:
	- Distribute projectile simulation tasks among multiple `Actor` instances.
	- Manage the lifecycle of projectiles, including initialization, simulation, and cleanup.
	- Provide a simple interface for casting projectiles with configurable parameters.

	Features:
	- **Multithreaded Simulation:** Spreads workload across `THREAD_COUNT` actors to maximize performance.
	- **Dynamic Task Assignment:** Selects the actor with the fewest tasks to maintain load balance.
	- **Customizable Behavior:** Supports modifiers for fine-tuning projectile behavior (e.g., gravity, lifetime).

	Notes:
	- Requires a `Simulation` module to handle individual projectile physics.
	- Automatically initializes actors and their controllers on startup.
]=]
local ProjectileCaster = {}

local actors: { Actor } = {}

--[=[
    Casts a projectile from the origin following the direction with the given raycast parameters and modifier.
    The actor with the least amount of tasks will be used to cast the projectile.
    @param origin -- The origin of the projectile
    @param direction -- The direction of the projectile
    @param raycastParams -- The `RaycastParams` to use for the projectile
    @param modifier -- The `Simulation.Modifier` to apply to the projectile
]=]
function ProjectileCaster.Cast(origin: Vector3, direction: Vector3, raycastParams: RaycastParams, modifier: Modifier)
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
