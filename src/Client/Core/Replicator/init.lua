--!strict

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IsCharacterAlive = require(ReplicatedStorage.Utility.IsCharacterAlive)

local LoadSlingshotConfig = require(ReplicatedStorage.Config.LoadSlingshotConfig)

local ProjectileCaster = require(ReplicatedFirst.Client.Modules.ProjectileCaster)

local TiltCharacter = require(script.TiltCharacter)

local LocalPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage.Remotes

local Replicator = {}

local tiltCharacters: { [number]: TiltCharacter.TiltCharacter }

function Replicator.OnCharacterTilt(player: Player, angle: number)
	if player == LocalPlayer then
		return
	end

	local tiltCharacter = tiltCharacters[player.UserId]
	if not tiltCharacter then
		local character = player.Character
		if not (character and IsCharacterAlive(character)) then
			warn(string.format("%s's character not found or not alive", player.Name))
			return
		end

		tiltCharacter = TiltCharacter.new(character, Remotes.Character.Tilt.SendRate.Value)
		tiltCharacters[player.UserId] = tiltCharacter

		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			tiltCharacters[player.UserId] = nil
		end)
	end

	tiltCharacter:Update(angle)
end

function Replicator.OnSlingshotFire(
	player: Player,
	origin: Vector3,
	direction: Vector3,
	speed: number,
	config: LoadSlingshotConfig.Config
)
	if player == LocalPlayer then
		return
	end

	local character = player.Character
	if not character then
		warn(string.format("%s's character not found", player.Name))
		return
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local projectileModifier: ProjectileCaster.Modifier = {
		Speed = speed,
		Gravity = config.Gravity,

		Lifetime = config.Lifetime,

		PVInstance = config.Projectile,
	}
	ProjectileCaster.Cast(origin, direction, raycastParams, projectileModifier)
end

do
	tiltCharacters = {}

	Remotes.Character.Tilt.OnClientEvent:Connect(Replicator.OnCharacterTilt)

	Remotes.Slingshot.Fire.OnClientEvent:Connect(Replicator.OnSlingshotFire)
end

return Replicator
