--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Simulation = require(script.Simulation)

export type Modifier = Simulation.Modifier
export type Projectile = Simulation.Projectile

local THREAD_COUNT = 8

local ProjectileCaster = {}

local actors: { Actor } = {}

function ProjectileCaster.Cast(origin: Vector3, direction: Vector3, raycastParams: RaycastParams, modifier: Modifier)
	table.sort(actors, function(a, b)
		return a:GetAttribute("Tasks") < b:GetAttribute("Tasks")
	end)
	actors[1]:SendMessage("Cast", origin, direction, raycastParams, modifier)
end

do
	local actorFolder = Instance.new("Folder")
	actorFolder.Name = "PROJECTILE_CASTER_ACTORS"
	actorFolder.Parent = ReplicatedFirst

	local visualFolder = Instance.new("Folder")
	visualFolder.Name = "PROJECTILE_CASTER_VISUALS"
	visualFolder.Parent = Workspace

	for _ = 1, THREAD_COUNT do
		local actor = Instance.new("Actor")
		actor:SetAttribute("Tasks", 0)
		actor.Parent = actorFolder

		local controller = script.Controller:Clone()
		controller.Enabled = true
		controller.Parent = actor

		table.insert(actors, actor)
	end

	RunService.PostSimulation:Wait()

	for _, actor in ipairs(actors) do
		actor:SendMessage("Initialize", script.Simulation)
	end
end

return ProjectileCaster
