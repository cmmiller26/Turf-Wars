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

    This implementation leverages `Actor` instances and multithreading to efficiently handle a large number of projectiles in real-time.
	By distributing simulation tasks across multiple threads, the system minimizes performance bottlenecks and ensures smooth gameplay, even in demanding scenarios.

    This module draws inspiration from [Secure-Cast by 1Axen](https://github.com/1Axen/Secure-Cast), a highly efficient and scalable projectile simulation system. 

    **Responsibilities:**
    - **Projectile Casting:** Handles initialization, direction, and simulation of projectiles.
    - **Task Distribution:** Balances workload across `THREAD_COUNT` actors to maximize parallel processing efficiency.
    - **Lifecycle Management:** Manages the initialization, simulation, and cleanup of projectiles.

    **Features:**
    - **Multithreaded Simulation:** Uses Luau's `Actor` instances to spread simulation tasks across threads.
    - **Load Balancing:** Dynamically assigns tasks to the actor with the fewest current tasks.
    - **Configurable Projectiles:** Supports customizable modifiers (e.g., gravity, lifetime) for precise control over projectile behavior.

    **Public Methods:**
    - `Cast(origin: Vector3, direction: Vector3, raycastParams: RaycastParams, modifier: Modifier): ()`
      - Simulates a projectile cast from the given origin and direction, applying specified raycast parameters and modifiers.

    **Constants:**
    - `THREAD_COUNT`: Specifies the number of `Actor` instances for multithreaded simulation.

    **Notes:**
    - Requires a `Simulation` module to define the physics and behavior of projectiles.
    - Actors are initialized automatically on startup and assigned controllers for task handling.
    - Projectiles are dynamically assigned to the least-loaded actor for optimal performance.

    **How It Works:**
    1. **Initialization:**
        - Creates a folder for actors (`PROJECTILE_CASTER_ACTORS`) and a folder for visual debugging (`PROJECTILE_CASTER_VISUALS`).
        - Initializes `THREAD_COUNT` actors, each with a cloned controller script.
    2. **Casting Projectiles:**
        - Determines the actor with the fewest tasks and assigns the projectile to it.
        - Sends a `Cast` message to the selected actor, which processes the projectile.
    3. **Load Balancing:**
        - Continuously monitors actor task loads and dynamically assigns new tasks to the least-loaded actor.

    This module is designed for scalability and smooth real-time performance, making it suitable for games with intensive projectile mechanics.
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
