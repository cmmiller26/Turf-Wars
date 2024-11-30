--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- External dependencies
local GetSlingshotConfig = require(ReplicatedStorage.Config.GetSlingshotConfig)

-- Client modules
local Client = ReplicatedFirst.Client
local Types = require(Client.Types)

local TiltCharacter = require(Client.Classes.TiltCharacter)

local ProjectileCaster = require(Client.Services.ProjectileCaster)

-- Player-related variables
local LocalPlayer = Players.LocalPlayer

-- Remote events folder
local Remotes = ReplicatedStorage.Remotes

local Replicator = {}

local tiltCharacters: { [number]: Types.TiltCharacter } = {}

local function onTilt(player: Player, angle: number?)
	if player == LocalPlayer then
		return
	end

	-- Create a new tilt character if one doesn't exist
	if not tiltCharacters[player.UserId] then
		local character = player.Character
		if not character then
			warn(string.format("Player %s has no character", player.Name))
			return
		end

		local tiltCharacter = TiltCharacter.new(character, Remotes.Character.Tilt.SendRate.Value)
		tiltCharacters[player.UserId] = tiltCharacter

		-- Remove the tilt character from the table when it is destroyed
		tiltCharacter.Destroying:Connect(function()
			tiltCharacters[player.UserId] = nil
		end)
	end
	-- Update the tilt character with the new angle
	tiltCharacters[player.UserId]:Update(angle)
end

local function onFireProjectile(
	player: Player,
	origin: Vector3,
	direction: Vector3,
	speed: number,
	config: GetSlingshotConfig.Config
)
	if player == LocalPlayer then
		return
	end

	local raycastParams = RaycastParams.new()
	if player.Character then -- Exclude the player's character from the raycast, if it exists
		raycastParams.FilterDescendantsInstances = { player.Character }
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	end

	local projectileModifier: ProjectileCaster.Modifier = {
		Speed = speed,
		Gravity = config.Projectile.Gravity,

		Lifetime = config.Projectile.Lifetime,

		PVInstance = config.Projectile.PVInstance,
		Color = player.TeamColor.Color,
	}
	ProjectileCaster.Cast(origin, direction, raycastParams, projectileModifier)
end

Remotes.Character.Tilt.OnClientEvent:Connect(onTilt)

Remotes.Tool.Slingshot.FireProjectile.OnClientEvent:Connect(onFireProjectile)

return Replicator
