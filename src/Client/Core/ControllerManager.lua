--!strict

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local CharacterController = require(ReplicatedFirst.Client.Controllers.CharacterController)

local LocalPlayer = Players.LocalPlayer

local ControllerManager = {}

function ControllerManager.OnCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	local controller = CharacterController.new(character)
	humanoid.Died:Connect(function()
		controller:Destroy()
	end)
end

do
	LocalPlayer.CharacterAdded:Connect(ControllerManager.OnCharacterAdded)
end

return ControllerManager
