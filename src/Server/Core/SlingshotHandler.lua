--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utility = ReplicatedStorage.Utility
local IsCharacterAlive = require(Utility.IsCharacterAlive)
local FindFirstChildWithTag = require(Utility.FindFirstChildWithTag)
local Physics = require(Utility.Physics)

local LoadSlingshotConfig = require(ReplicatedStorage.Config.LoadSlingshotConfig)

type FireData = {
	Origin: Vector3,
	Direction: Vector3,
	Speed: number,

	Config: LoadSlingshotConfig.Config,
}

local HEAD_OFFSET = Vector3.new(0, 1.5, 0)
local MAX_ORIGIN_ERROR = 10

local Remotes = ReplicatedStorage.Remotes.Slingshot

local SlingshotHandler = {}

local playerFireData: { [number]: { [number]: FireData } } = {}

function SlingshotHandler.OnFire(player: Player, origin: Vector3, direction: Vector3, speed: number, timeStamp: number)
	if typeof(origin) ~= "Vector3" then
		warn("Invalid argument #2")
		return
	end
	if typeof(direction) ~= "Vector3" then
		warn("Invalid argument #3")
		return
	end
	if typeof(speed) ~= "number" then
		warn("Invalid argument #4")
		return
	end
	if typeof(timeStamp) ~= "number" then
		warn("Invalid argument #5")
		return
	end

	local character = player.Character
	if not (character and IsCharacterAlive(character)) then
		warn(string.format("%s's character not found or not alive", player.Name))
		return
	end

	local slingshot = FindFirstChildWithTag(character, "Slingshot")
	if not (slingshot and slingshot:IsA("Model")) then
		warn(string.format("Slingshot not found in %s's character", player.Name))
		return
	end

	local configuration = slingshot:FindFirstChildOfClass("Configuration")
	if not configuration then
		warn(string.format("Configuration not found in %s's slingshot", player.Name))
		return
	end
	local config = LoadSlingshotConfig(configuration)
	if speed > config.MaxSpeed then
		warn(string.format("Kick %s for firing a slingshot at an illegal speed", player.Name))
		player:Kick("You were kicked for firing a slingshot at an illegal speed")
		return
	end

	local serverOrigin = character:GetPivot().Position + HEAD_OFFSET
	if (serverOrigin - origin).Magnitude > MAX_ORIGIN_ERROR then
		warn(string.format("%s fired a slingshot from an invalid origin", player.Name))
		return
	end

	playerFireData[player.UserId][timeStamp] = {
		Origin = origin,
		Direction = direction,
		Speed = speed,

		Config = config,
	}
	task.delay(config.Lifetime, function()
		playerFireData[player.UserId][timeStamp] = nil
	end)

	Remotes.Fire:FireAllClients(player, origin, direction, speed, config)
end
function SlingshotHandler.OnRegisterHit(player: Player, hitPart: BasePart, hitTimeStamp: number, fireTimeStamp: number)
	if not (typeof(hitPart) == "Instance" and hitPart:IsA("BasePart")) then
		warn("Invalid argument #2")
		return
	end
	if typeof(hitTimeStamp) ~= "number" then
		warn("Invalid argument #3")
		return
	end
	if typeof(fireTimeStamp) ~= "number" then
		warn("Invalid argument #4")
		return
	end

	local fireData = playerFireData[player.UserId][fireTimeStamp]
	if not fireData then
		warn(string.format("%s's FireData not found", player.Name))
		return
	end

	local character = hitPart.Parent
	if not (character and character:IsA("Model") and IsCharacterAlive(character)) then
		warn(string.format("%s's HitPart character not found or not alive", player.Name))
		return
	end

	local position = Physics.CalculatePosition(
		fireData.Origin,
		fireData.Direction * fireData.Speed,
		Vector3.new(0, -fireData.Config.Gravity, 0),
		hitTimeStamp - fireTimeStamp
	)
	local maxPositionError = 0.5 * math.max(hitPart.Size.X, hitPart.Size.Y, hitPart.Size.Z) + MAX_ORIGIN_ERROR
	if (position - hitPart.Position).Magnitude > maxPositionError then
		warn(string.format("%s's HitPart position is too far from the calculated position", player.Name))
		return
	end

	local damage = fireData.Config.Damage + fireData.Speed * fireData.Config.SpeedMultiplier
	if hitPart.Name == "Head" then
		damage *= fireData.Config.HeadshotMultiplier
	end
	(character:FindFirstChildOfClass("Humanoid") :: Humanoid):TakeDamage(damage)

	print(string.format("%s hit %s for %d damage", player.Name, character.Name, damage))
end

do
	Players.PlayerAdded:Connect(function(player: Player)
		playerFireData[player.UserId] = {}
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		playerFireData[player.UserId] = nil
	end)

	Remotes.Fire.OnServerEvent:Connect(SlingshotHandler.OnFire)
	Remotes.RegisterHit.OnServerEvent:Connect(SlingshotHandler.OnRegisterHit)
end

return SlingshotHandler
