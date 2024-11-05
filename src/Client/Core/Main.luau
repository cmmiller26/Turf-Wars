--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterController = ReplicatedFirst.Client.Classes.CharacterController
local RoundCharacterController = require(CharacterController.RoundCharacterController)

local Remotes = ReplicatedStorage.Remotes

local Main = {}

local function onSpawn(controllerType: string, character: Model)
	if controllerType == "RoundCharacter" then
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid

		local controller = RoundCharacterController.new(character)
		humanoid.Died:Connect(function()
			controller:Destroy()
		end)
	end
end

Remotes.Spawn.OnClientEvent:Connect(onSpawn)

return Main
