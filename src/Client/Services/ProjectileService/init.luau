--!strict

-- Services
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Simulation = require(script.Simulation)

-- Export simulation types
export type Modifier = Simulation.Modifier
export type Projectile = Simulation.Projectile

local THREAD_COUNT = 8 -- Number of threads to use for projectile casting

--[=[
    The ProjectileService is responsible for casting projectiles utilizing parallel luau threads.
]=]
local ProjectileService = {}

local actors: { Actor } = {} -- List of actors to cast projectiles

--[=[
    Cast a projectile from the origin in the direction with the given raycast parameters and modifier.
    The actor with the least amount of tasks will be used to cast the projectile.
    @param origin The origin of the projectile
    @param direction The direction of the projectile
    @param raycastParams The raycast parameters to use
    @param modifier The modifier to apply to the projectile
]=]
function ProjectileService.Cast(origin: Vector3, direction: Vector3, raycastParams: RaycastParams, modifier: Modifier)
	table.sort(actors, function(a, b)
		return a:GetAttribute("Tasks") < b:GetAttribute("Tasks")
	end)
	actors[1]:SendMessage("Cast", origin, direction, raycastParams, modifier)
end

-- Create the folder for the actors
local actorFolder = Instance.new("Folder")
actorFolder.Name = "PROJECTILE_CASTER_ACTORS"
actorFolder.Parent = ReplicatedFirst

-- Create the folder for the projectile instances
local visualFolder = Instance.new("Folder")
visualFolder.Name = "PROJECTILE_CASTER_VISUALS"
visualFolder.Parent = Workspace

-- Create the actors
for _ = 1, THREAD_COUNT do
	local actor = Instance.new("Actor")
	actor:SetAttribute("Tasks", 0)
	actor.Parent = actorFolder

	local controller = script.Controller:Clone()
	controller.Enabled = true
	controller.Parent = actor

	table.insert(actors, actor)
end

-- Wait until the actors' controllers are enabled
RunService.PostSimulation:Wait()

-- Initialize the actors
for _, actor in ipairs(actors) do
	actor:SendMessage("Initialize", script.Simulation)
end

return ProjectileService
