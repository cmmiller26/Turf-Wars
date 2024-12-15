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
	ProjectileCaster manages the simulation and casting of projectiles using parallel luau threads for optimized performance.
	This module draws inspiration from [Secure-Cast by 1Axen](https://github.com/1Axen/Secure-Cast).
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
