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

local ProjectileService = require(Client.Services.ProjectileService)

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

	local tiltCharacter = tiltCharacters[player.UserId]
	-- Create a new TiltCharacter if one doesn't exist
	if not tiltCharacter then
		local character = player.Character
		if not character then
			return
		end

		tiltCharacter = TiltCharacter.new(character, Remotes.Tilt.SendRate.Value)
		tiltCharacters[player.UserId] = tiltCharacter

		-- Remove the TiltCharacter when the humanoid dies
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			tiltCharacters[player.UserId] = nil
		end)
	end
	-- Update the TiltCharacter with the new angle
	tiltCharacter:Update(angle)
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
	local projectileModifier: ProjectileService.Modifier = {
		Speed = speed,
		Gravity = config.Projectile.Gravity,

		Lifetime = config.Projectile.Lifetime,

		PVInstance = config.Projectile.PVInstance,
		Color = player.TeamColor.Color,
	}
	-- Cast the projectile
	ProjectileService.Cast(origin, direction, raycastParams, projectileModifier)
end

-- Connect the Remotes
Remotes.GameCharacter.Tilt.OnClientEvent:Connect(onTilt)

Remotes.Slingshot.FireProjectile.OnClientEvent:Connect(onFireProjectile)

return Replicator
