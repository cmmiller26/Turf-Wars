--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IsCharacterAlive = require(ReplicatedStorage.Utility.IsCharacterAlive)

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

do
	tiltCharacters = {}
	Remotes.Character.Tilt.OnClientEvent:Connect(Replicator.OnCharacterTilt)
end

return Replicator
