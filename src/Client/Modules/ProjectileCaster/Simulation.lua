--!strict
--!native

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Queue = require(ReplicatedStorage.Modules.Queue)
local Physics = require(ReplicatedStorage.Utility.Physics)

export type Modifier = {
	Speed: number?,
	Gravity: number?,

	Lifetime: number?,

	TimeStamp: number?,
	PVInstance: PVInstance?,

	OnImpact: BindableEvent?,
}

type Projectile = {
	Position: Vector3,
	Velocity: Vector3,
	Acceleration: Vector3,

	RaycastParams: RaycastParams,

	Lifetime: number,
	StartTick: number,
	LastTick: number,

	TimeStamp: number?,

	PVInstance: PVInstance?,

	OnImpact: BindableEvent?,
}

local FIXED_DELTA_TIME = 1 / 60
local REMAINING_FRAME_TIME_RATIO = 0.5

local Simulation = {}

local Actor: Actor
local Folder: Folder

local queue: Queue.Queue<Projectile>

local frameStartTick: number

local function IncrementTasks(value: number)
	Actor:SetAttribute("Tasks", (Actor:GetAttribute("Tasks") :: number) + value)
end

local function OnPreSimulation()
	frameStartTick = os.clock()
end
local function OnPostSimulation()
	local startTick = os.clock()
	local maxSimulationTime = (FIXED_DELTA_TIME - (startTick - frameStartTick)) * REMAINING_FRAME_TIME_RATIO

	local impacted: { [Projectile]: RaycastResult } = {}
	local destroyed: { Projectile } = {}

	for _ = 1, queue:Size() do
		local tick = os.clock()
		if (tick - startTick) > maxSimulationTime then
			warn("ProjectileCaster Simulation OnPostSimulation(): Actor has used all of its allocated simulation time")
			break
		end

		local projectile = queue:Dequeue()

		local dt = tick - projectile.LastTick
		local curPos = projectile.Position
		local nextPos = Physics.CalculatePosition(curPos, projectile.Velocity, projectile.Acceleration, dt)

		local raycastResult = Workspace:Raycast(curPos, nextPos - curPos, projectile.RaycastParams)
		if raycastResult then
			impacted[projectile] = raycastResult
			table.insert(destroyed, projectile)
			continue
		end

		if tick - projectile.StartTick > projectile.Lifetime then
			table.insert(destroyed, projectile)
			continue
		end

		projectile.Position = nextPos
		projectile.Velocity = Physics.CalculateVelocity(projectile.Velocity, projectile.Acceleration, dt)
		projectile.LastTick = tick

		queue:Enqueue(projectile)
	end

	task.synchronize()

	for projectile, raycastResult in pairs(impacted) do
		if projectile.OnImpact then
			projectile.OnImpact:Fire(raycastResult)
		end
	end

	for _, projectile in ipairs(destroyed) do
		if projectile.PVInstance then
			projectile.PVInstance:Destroy()
		end
		IncrementTasks(-1)
	end
end

local function OnPreRender()
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}

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
			pvInstance:PivotTo(cframe)
		end
	end

	task.synchronize()

	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function Simulation.Cast(origin: Vector3, direction: Vector3, raycastParams: RaycastParams?, modifier: Modifier?)
	local projectile: Projectile = {
		Position = origin,
		Velocity = direction * (modifier and modifier.Speed or 100),
		Acceleration = Vector3.new(0, -(modifier and modifier.Gravity or Workspace.Gravity), 0),

		RaycastParams = raycastParams or RaycastParams.new(),

		Lifetime = modifier and modifier.Lifetime or 10,
		StartTick = os.clock(),
		LastTick = os.clock(),

		TimeStamp = modifier and modifier.TimeStamp,

		OnImpact = modifier and modifier.OnImpact,
	}

	local pvInstance = modifier and modifier.PVInstance
	if pvInstance then
		local clone = pvInstance:Clone()
		clone.Parent = Folder
		projectile.PVInstance = clone
	end

	queue:Enqueue(projectile)

	IncrementTasks(1)
end

function Simulation.Initialize(actor: Actor)
	Actor = actor
	Actor:BindToMessage("Cast", Simulation.Cast)

	Folder = Workspace:WaitForChild("PROJECTILE_CASTER_VISUALS")

	queue = Queue.new()

	RunService.PreSimulation:Connect(OnPreSimulation)
	RunService.PostSimulation:ConnectParallel(OnPostSimulation)
	RunService.PreRender:ConnectParallel(OnPreRender)
end

return Simulation
