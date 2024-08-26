--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utility = ReplicatedStorage.Utility
local FindFirstChildWithTag = require(Utility.FindFirstChildWithTag)
local IsCharacterAlive = require(Utility.IsCharacterAlive)
local Physics = require(Utility.Physics)

local LoadSlingshotConfig = require(ReplicatedStorage.Config.LoadSlingshotConfig)

local MAX_ORIGIN_ERROR = 10

local HEAD_OFFSET = Vector3.new(0, 1.5, 0)

type FireData = {
	Position: Vector3,
	Velocity: Vector3,
	Acceleration: Vector3,

	Config: LoadSlingshotConfig.Config,
}

local Remotes = ReplicatedStorage.Remotes.Slingshot

local SlingshotHandler = {}

local fireData: { [number]: { [number]: FireData } }

function SlingshotHandler.OnFire(player: Player, origin: Vector3, direction: Vector3, speed: number, timeStamp: number)
	assert(
		typeof(origin) == "Vector3",
		"SlingshotHandler.OnFire(): Expected Vector3 for argument #2, got " .. typeof(origin)
	)
	assert(
		typeof(direction) == "Vector3",
		"SlingshotHandler.OnFire(): Expected Vector3 for argument #3, got " .. typeof(direction)
	)
	assert(
		typeof(speed) == "number",
		"SlingshotHandler.OnFire(): Expected number for argument #4, got " .. typeof(speed)
	)
	assert(
		typeof(timeStamp) == "number",
		"SlingshotHandler.OnFire(): Expected number for argument #5, got " .. typeof(timeStamp)
	)

	local character = player.Character
	if not (character and IsCharacterAlive(character)) then
		warn("SlingshotHandler.OnFire(): " .. player.Name .. " attempted to fire a slingshot while dead")
		return
	end

	if ((character:GetPivot().Position + HEAD_OFFSET) - origin).Magnitude > MAX_ORIGIN_ERROR then
		warn("SlingshotHandler.OnFire(): " .. player.Name .. " attempted to fire a slingshot from an invalid origin")
		return
	end

	local slingshot = FindFirstChildWithTag(character, "Slingshot")
	if not slingshot then
		warn("SlingshotHandler.OnFire(): Could not find " .. player.Name .. "'s Slingshot")
		return
	end

	local configuration = slingshot:FindFirstChildOfClass("Configuration")
	assert(configuration, "SlingshotHandler.OnFire(): Could not find " .. player.Name .. "'s Slingshot Configuration")

	local config = LoadSlingshotConfig(configuration)

	if speed > config.MaxSpeed then
		player:Kick("You were kicked for firing a slingshot at a speed greater than the maximum speed")
		return
	end

	fireData[player.UserId][timeStamp] = {
		Position = origin,
		Velocity = direction * speed,
		Acceleration = Vector3.new(0, -config.Gravity, 0),

		Config = config,
	}
	task.delay(config.Lifetime, function()
		fireData[player.UserId][timeStamp] = nil
	end)

	Remotes.Fire:FireAllClients(player, slingshot, origin, direction, speed)
end

function SlingshotHandler.OnHitCharacter(player: Player, hitPart: BasePart, hitTimeStamp: number, fireTimeStamp: number)
	assert(
		typeof(hitPart) == "Instance" and hitPart:IsA("BasePart"),
		"SlingshotHandler.OnHitCharacter(): Expected BasePart for argument #2, got " .. typeof(hitPart)
	)
	assert(
		typeof(hitTimeStamp) == "number",
		"SlingshotHandler.OnHitCharacter(): Expected number for argument #3, got " .. typeof(hitTimeStamp)
	)
	assert(
		typeof(fireTimeStamp) == "number",
		"SlingshotHandler.OnHitCharacter(): Expected number for argument #4, got " .. typeof(fireTimeStamp)
	)

	local fireData = fireData[player.UserId][fireTimeStamp]
	if not fireData then
		warn(
			"SlingshotHandler.OnHitCharacter(): Could not find FireData for "
				.. player.Name
				.. " at t="
				.. fireTimeStamp
		)
		return
	end

	local character = hitPart.Parent
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local position = Physics.CalculatePosition(
		fireData.Position,
		fireData.Velocity,
		fireData.Acceleration,
		hitTimeStamp - fireTimeStamp
	)
	local maxPositionError = MAX_ORIGIN_ERROR + 0.5 * math.max(hitPart.Size.X, hitPart.Size.Y, hitPart.Size.Z)
	if (hitPart.Position - position).Magnitude > maxPositionError then
		warn("SlingshotHandler.OnHitCharacter(): " .. player.Name .. " tried to register a hit at an invalid position")
		return
	end

	local damage = fireData.Config.Damage + fireData.Velocity.Magnitude * fireData.Config.SpeedMultiplier
	if hitPart.Name == "Head" then
		damage *= fireData.Config.HeadshotMultiplier
	end
	humanoid:TakeDamage(damage)

	print(player.Name .. " dealt " .. damage .. " damage to " .. character.Name)
end

do
	fireData = {}
	Players.PlayerAdded:Connect(function(player: Player)
		fireData[player.UserId] = {}
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		fireData[player.UserId] = nil
	end)

	Remotes.Fire.OnServerEvent:Connect(SlingshotHandler.OnFire)
	Remotes.HitCharacter.OnServerEvent:Connect(SlingshotHandler.OnHitCharacter)
end

return SlingshotHandler
