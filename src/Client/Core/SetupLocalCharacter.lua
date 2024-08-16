--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")

local CharacterController = require(ReplicatedFirst.Client.Controllers.CharacterController)

local LocalPlayer = Players.LocalPlayer

local SetupLocalCharacter = {}

function SetupLocalCharacter.onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	local controller = CharacterController.new(character)
	humanoid.Died:Connect(function()
		controller:Destroy()
	end)
end

do
	if LocalPlayer.Character then
		SetupLocalCharacter.onCharacterAdded(LocalPlayer.Character)
	end
	LocalPlayer.CharacterAdded:Connect(SetupLocalCharacter.onCharacterAdded)
end

return SetupLocalCharacter
