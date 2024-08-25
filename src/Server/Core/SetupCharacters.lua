--!strict

local Players = game:GetService("Players")

local SetupCharacters = {}

function SetupCharacters.OnCharacterAdded(character: Model)
	character.PrimaryPart = character:FindFirstChild("HumanoidRootPart") :: BasePart

	local toolJoint = Instance.new("Motor6D")
	toolJoint.Name = "ToolJoint"
	toolJoint.Part0 = character:FindFirstChild("Torso") :: BasePart
	toolJoint.Parent = toolJoint.Part0

	character.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Accessory") then
			(child:FindFirstChild("Handle") :: BasePart).CanQuery = false
		end
	end)
end

do
	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(SetupCharacters.OnCharacterAdded)
	end)
end

return SetupCharacters
