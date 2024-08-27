--!strict

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LoadSlingshotConfig = require(ReplicatedStorage.Config.LoadSlingshotConfig)

local IsCharacterAlive = require(ReplicatedStorage.Utility.IsCharacterAlive)

local ProjectileCaster = require(ReplicatedFirst.Client.Modules.ProjectileCaster)

local TiltCharacter = require(script.TiltCharacter)

local LocalPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage.Remotes

local TILT_SEND_RATE = Remotes.Character.Tilt.SendRate.Value

local Replicator = {}

local tiltCharacters: { [number]: TiltCharacter.TiltCharacter }

function Replicator.OnCharacterTilt(player: Player, angle: number)
	if player == LocalPlayer then
		return
	end

	local tiltCharacter = tiltCharacters[player.UserId]
	if not tiltCharacter then
		local character = player.Character
		assert(character and IsCharacterAlive(character), "Replicator.OnCharacterTilt(): Character is not alive")

		tiltCharacter = TiltCharacter.new(character, TILT_SEND_RATE)
		tiltCharacters[player.UserId] = tiltCharacter

		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			tiltCharacters[player.UserId] = nil
		end)
	end

	tiltCharacter:Update(angle)
end

function Replicator.OnSlingshotFire(slingshot: Model, origin: Vector3, direction: Vector3, speed: number)
	local character = slingshot.Parent
	if not character or character == LocalPlayer.Character then
		return
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local configuration = slingshot:FindFirstChildOfClass("Configuration")
	assert(
		configuration,
		"Replicator.OnSlingshotFire(): Could not find Configuration in " .. character.Name .. "'s Slingshot"
	)

	local config = LoadSlingshotConfig(configuration)
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
