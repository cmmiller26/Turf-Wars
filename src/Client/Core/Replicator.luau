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

-- Player reference
local LocalPlayer = Players.LocalPlayer

-- Remote folder reference
local Remotes = ReplicatedStorage.Remotes

local Replicator = {}

local tiltCharacters: { [number]: Types.TiltCharacter } = {}

local function onTilt(player: Player, angle: number?)
	if player == LocalPlayer then
		return
	end

	-- Create a new TiltCharacter if one doesn't exist
	if not tiltCharacters[player.UserId] then
		local character = player.Character
		if not character then
			return
		end

		local tiltCharacter = TiltCharacter.new(character, Remotes.Character.Tilt.SendRate.Value)
		tiltCharacters[player.UserId] = tiltCharacter

		-- Remove the TiltCharacter from the table when it is destroyed
		tiltCharacter.Destroying:Connect(function()
			tiltCharacters[player.UserId] = nil
		end)
	end
	-- Update the TiltCharacter with the new angle
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

	-- Create a raycast filter to exclude the player's character
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { player.Character :: Model }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	-- Create a projectile modifier using the given config
	local projectileModifier: ProjectileCaster.Modifier = {
		Speed = speed,
		Gravity = config.Projectile.Gravity,

		Lifetime = config.Projectile.Lifetime,

		PVInstance = config.Projectile.PVInstance,
		Color = player.TeamColor.Color,
	}
	-- Cast the projectile
	ProjectileCaster.Cast(origin, direction, raycastParams, projectileModifier)
end

-- Connect the Remotes
Remotes.Character.Tilt.OnClientEvent:Connect(onTilt)

Remotes.Tool.Slingshot.FireProjectile.OnClientEvent:Connect(onFireProjectile)

return Replicator
