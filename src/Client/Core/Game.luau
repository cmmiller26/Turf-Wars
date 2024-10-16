--!strict

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local GameCharacterController = require(ReplicatedFirst.Client.Classes.GameCharacterController)

local LocalPlayer = Players.LocalPlayer

local Game = {}

local function onCharacterAdded(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid

	local controller = GameCharacterController.new(character)
	humanoid.Died:Connect(function()
		controller:Destroy()
	end)
end

if LocalPlayer.Character then
	onCharacterAdded(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

return Game
