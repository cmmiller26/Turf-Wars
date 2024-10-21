--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameCharacterController = require(ReplicatedFirst.Client.Classes.GameCharacterController)

local Remotes = ReplicatedStorage.Remotes

local Main = {}

local function onSpawn(controllerType: string, character: Model)
	if controllerType == "GameCharacter" then
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid

		local controller = GameCharacterController.new(character)
		humanoid.Died:Connect(function()
			controller:Destroy()
		end)
	end
end

Remotes.Spawn.OnClientEvent:Connect(onSpawn)

return Main
