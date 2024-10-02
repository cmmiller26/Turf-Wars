--!strict

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = ReplicatedFirst.Client
local TiltCharacter = require(Client.Classes.TiltCharacter)
local ProjectileService = require(Client.Services.ProjectileService)

local GetSlingshotConfig = require(ReplicatedStorage.Config.GetSlingshotConfig)

local LocalPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage.Remotes

local Replicator = {}

do
	local tiltCharacters: { [number]: TiltCharacter.TiltCharacter } = {}

	local function onTilt(player: Player, angle: number?)
		if player == LocalPlayer then
			return
		end

		local tiltCharacter = tiltCharacters[player.UserId]
		if not tiltCharacter then
			local character = player.Character
			if not character then
				return
			end

			tiltCharacter = TiltCharacter.new(character, Remotes.Tilt.SendRate.Value)
			tiltCharacters[player.UserId] = tiltCharacter

			local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
			humanoid.Died:Connect(function()
				tiltCharacters[player.UserId] = nil
			end)
		end
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

		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = { player.Character :: Model }
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude

		local projectileModifier: ProjectileService.Modifier = {
			Speed = speed,
			Gravity = config.Projectile.Gravity,

			Lifetime = config.Projectile.Lifetime,

			PVInstance = config.Projectile.PVInstance,
			Color = player.TeamColor.Color,
		}
		ProjectileService.Cast(origin, direction, raycastParams, projectileModifier)
	end

	Remotes.Tilt.OnClientEvent:Connect(onTilt)

	Remotes.Slingshot.FireProjectile.OnClientEvent:Connect(onFireProjectile)
end

return Replicator
