--!native
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Queue = require(ReplicatedStorage.Classes.Queue)
local Physics = require(ReplicatedStorage.Utility.Physics)

export type Modifier = {
	Speed: number, -- The speed to cast the projectile at
	Gravity: number, -- The gravity to apply to the projectile

	Lifetime: number, -- The lifetime of the projectile

	PVInstance: PVInstance?, -- The PVInstance to represent the projectile
	Color: Color3?, -- The color of the PVInstance

	Timestamp: number?, -- Server time when the projectile was cast

	OnImpact: BindableEvent?, -- The event to fire when the projectile impacts
}

export type Projectile = {
	Position: Vector3, -- The current position of the projectile
	Velocity: Vector3, -- The current velocity of the projectile
	Acceleration: Vector3, -- The acceleration of the projectile

	RaycastParams: RaycastParams, -- The RaycastParams to use when casting the projectile

	Lifetime: number, -- The lifetime of the projectile
	StartTick: number, -- The tick the projectile was cast
	LastTick: number, -- The last tick the projectile was updated

	PVInstance: PVInstance?, -- The PVInstance to represent the projectile

	Timestamp: number?, -- Server time when the projectile was cast

	OnImpact: BindableEvent?, -- The event to fire when the projectile impacts
}

local FIXED_DELTA_TIME = 1 / 60 -- Physics timestep
local REMAINING_FRAME_TIME_RATIO = 0.5 -- The ratio of the frame time to use for the simulation

local Simulation = {}

local Actor: Actor
local Folder: Folder

local queue: Queue.Queue<Projectile>

local frameStartTick: number

--[=[
	Increment the number of tasks the actor is currently performing by the given value.
]=]
local function IncrementTasks(value: number)
	Actor:SetAttribute("Tasks", (Actor:GetAttribute("Tasks") :: number) + value)
end

--[=[
	Called before the simulation starts for the current frame.
	Captures the start time of the frame to calculate remaining frame time during simulation.
]=]
local function onPreSimulation()
	frameStartTick = os.clock()
end

--[=[
	Handles projectile processing after the physics simulation for each frame.
	Each projectile is dequeued, processed, and re-enqueued unless destroyed.
	The queue ensures that if some projectiles aren’t processed in one frame due to time constraints, 
	they’ll be processed in the next, distributing workload across frames.
]=]
local function onPostSimulation()
	local startTick = os.clock()
	-- The maximum amount of time the actor can use for simulation
	local maxSimulationTime = (FIXED_DELTA_TIME - (startTick - frameStartTick)) * REMAINING_FRAME_TIME_RATIO

	local impacted: { [Projectile]: RaycastResult } = {}
	local destroyed: { Projectile } = {}

	-- Process projectiles in the queue
	for _ = 1, queue:Size() do
		local tick = os.clock()
		-- If the actor has used all of its allocated simulation time, stop processing projectiles
		if (tick - startTick) > maxSimulationTime then
			warn("ProjectileCaster Simulation OnPostSimulation(): Actor has used all of its allocated simulation time")
			break
		end

		local projectile = queue:Dequeue() -- Get the next projectile in the queue

		local dt = tick - projectile.LastTick
		local curPos = projectile.Position
		-- Calculate the next position of the projectile
		local nextPos = Physics.CalculatePosition(curPos, projectile.Velocity, projectile.Acceleration, dt)

		-- Raycast from the current position to the next position
		local raycastResult = Workspace:Raycast(curPos, nextPos - curPos, projectile.RaycastParams)
		-- If the raycast hit something, store the projectile and the raycast result
		if raycastResult then
			impacted[projectile] = raycastResult
			table.insert(destroyed, projectile)
			continue
		end

		-- If the projectile has exceeded its lifetime, store the projectile to be destroyed
		if tick - projectile.StartTick > projectile.Lifetime then
			table.insert(destroyed, projectile)
			continue
		end

		-- Update the projectile's position, velocity, and last tick
		projectile.Position = nextPos
		projectile.Velocity = Physics.CalculateVelocity(projectile.Velocity, projectile.Acceleration, dt)
		projectile.LastTick = tick

		queue:Enqueue(projectile) -- Add the projectile back to the queue
	end

	task.synchronize() -- Wait for all tasks to complete

	-- Fire the OnImpact event for projectiles that have impacted
	for projectile, raycastResult in pairs(impacted) do
		if projectile.OnImpact then
			projectile.OnImpact:Fire(projectile, raycastResult)
		end
	end

	-- Destroy the PVInstance for projectiles that have been destroyed
	for _, projectile in ipairs(destroyed) do
		if projectile.PVInstance then
			projectile.PVInstance:Destroy()
		end
		IncrementTasks(-1) -- Update the number of tasks the actor is currently performing
	end
end

--[=[
	Updates the position of projectile instances (PVInstances) before rendering.
	Moves the projectile's model to match its calculated position and direction.
]=]
local function onPreRender()
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}

	-- Get the positions of the projectiles in the queue
	for _ = 1, queue:Size() do
		local projectile = queue:Dequeue()
		queue:Enqueue(projectile)

		local pvInstance = projectile.PVInstance
		if not pvInstance then
			continue
		end

		local cframe = CFrame.lookAt(projectile.Position, projectile.Position + projectile.Velocity)
		if pvInstance:IsA("BasePart") then
			table.insert(parts, pvInstance)
			table.insert(cframes, cframe)
		else
			pvInstance:PivotTo(cframe) -- If the PVInstance is not a BasePart, move it now
		end
	end

	task.synchronize() -- Wait for all tasks to complete

	-- Bulk move the BaseParts to their new positions
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

--[=[
	Creates and casts a projectile with the specified origin, direction, raycast parameters, and modifier.
	The projectile is added to the queue for simulation and impacts are handled asynchronously.
	@param origin -- The starting position of the projectile.
	@param direction -- The direction and initial velocity of the projectile.
	@param raycastParams -- The `RaycastParams` for raycasting during projectile travel.
	@param modifier -- The `Modifier` to apply to the projectile.
]=]
function Simulation.Cast(origin: Vector3, direction: Vector3, raycastParams: RaycastParams, modifier: Modifier)
	-- Create a new projectile with the given origin, direction, raycast params, and modifier
	local projectile: Projectile = {
		Position = origin,
		Velocity = direction * modifier.Speed,
		Acceleration = Vector3.new(0, -modifier.Gravity, 0),

		RaycastParams = raycastParams,

		Lifetime = modifier.Lifetime,
		StartTick = os.clock(),
		LastTick = os.clock(),

		Timestamp = modifier.Timestamp,

		OnImpact = modifier.OnImpact,
	}

	-- Clone the PVInstance and set its color if the modifier has a PVInstance and color
	local pvInstance = modifier.PVInstance
	if pvInstance then
		local clone = pvInstance:Clone()
		if clone:IsA("BasePart") and modifier.Color then
			clone.Color = modifier.Color
		end
		clone.Parent = Folder
		projectile.PVInstance = clone
	end

	queue:Enqueue(projectile) -- Add the projectile to the queue

	IncrementTasks(1) -- Update the number of tasks the actor is currently performing
end

--[=[
	Initializes the simulation actor and binds the `Cast` function for projectile processing.
	Connects simulation functions to the appropriate RunService events for parallel processing.
	@param actor -- The `Actor` responsible for handling the projectile simulation.
]=]
function Simulation.Initialize(actor: Actor)
	-- Initialize the Simulation service with the given actor
	Actor = actor
	Actor:BindToMessage("Cast", Simulation.Cast)

	Folder = Workspace:FindFirstChild("PROJECTILE_CASTER_VISUALS")

	queue = Queue.new()

	-- Connect RunService events to the simulation functions
	RunService.PreSimulation:Connect(onPreSimulation)
	RunService.PostSimulation:ConnectParallel(onPostSimulation)
	RunService.PreRender:ConnectParallel(onPreRender)
end

return Simulation
