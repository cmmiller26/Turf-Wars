--!strict

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local Classes = ReplicatedFirst.Client.Classes
local GameCharacterController = require(Classes.Game.GameCharacterController)

local LocalPlayer = Players.LocalPlayer

local ControllerManager = {}

do
	local function OnCharacterAdded(character: Model)
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid

		local characterController = GameCharacterController.new(character)
		humanoid.Died:Connect(function()
			characterController:Destroy()
		end)
	end

	if LocalPlayer.Character then
		OnCharacterAdded(LocalPlayer.Character)
	end
	LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)
end

return ControllerManager
