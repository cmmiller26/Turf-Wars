--!strict

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TiltCharacter = require(ReplicatedFirst.Client.Classes.TiltCharacter)

local LocalPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage.Remotes

local Replicator = {}

do
	local tiltCharacters: { [number]: TiltCharacter.TiltCharacter } = {}

	local function OnTilt(player: Player, angle: number?)
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

	Remotes.Tilt.OnClientEvent:Connect(OnTilt)
end

return Replicator
