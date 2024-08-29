--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utility = ReplicatedStorage.Utility
local IsCharacterAlive = require(Utility.IsCharacterAlive)
local FindFirstChildWithTag = require(Utility.FindFirstChildWithTag)

local Remotes = ReplicatedStorage.Remotes.Character

local HandleCharacters = {}

function HandleCharacters.OnCharacterAdded(character: Model)
	character.PrimaryPart = character:FindFirstChild("HumanoidRootPart") :: BasePart

	local toolJoint = Instance.new("Motor6D")
	toolJoint.Name = "ToolJoint"
	toolJoint.Part0 = character:FindFirstChild("Torso") :: BasePart
	toolJoint.Parent = toolJoint.Part0
end
function HandleCharacters.OnCharacterAppearanceLoaded(character: Model)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") then
			(child:FindFirstChild("Handle") :: BasePart).CanQuery = false
		end
	end
end

function HandleCharacters.OnEquipTool(player: Player, toolName: string)
	if typeof(toolName) ~= "string" then
		warn("Invalid argument #2")
		return
	end

	local character = player.Character
	if not (character and IsCharacterAlive(character)) then
		warn(string.format("%s's character not found or not alive", player.Name))
		return
	end

	local tool = FindFirstChildWithTag(player.Backpack, toolName)
	if not (tool and tool:IsA("Model")) then
		warn(string.format("%s not found in %s's backpack", toolName, player.Name))
		return
	end

	local torso = character:FindFirstChild("Torso") :: Instance
	local toolJoint = torso:FindFirstChild("ToolJoint")
	if not (toolJoint and toolJoint:IsA("Motor6D")) then
		warn(string.format("'ToolJoint' Motor6D not found in %s's torso", player.Name))
		return
	end

	local prevTool = toolJoint.Part1 and toolJoint.Part1.Parent
	if prevTool then
		prevTool.Parent = player.Backpack
	end

	toolJoint.Part1 = tool.PrimaryPart
	tool.Parent = character
end
function HandleCharacters.OnUnequip(player: Player)
	local character = player.Character
	if not character then
		return
	end

	local torso = character:FindFirstChild("Torso") :: Instance
	local toolJoint = torso:FindFirstChild("ToolJoint")
	if not (toolJoint and toolJoint:IsA("Motor6D")) then
		return
	end

	local tool = toolJoint.Part1 and toolJoint.Part1.Parent
	if not tool then
		return
	end

	toolJoint.Part1 = nil
	tool.Parent = player.Backpack
end

function HandleCharacters.OnTilt(player: Player, angle: number)
	if typeof(angle) ~= "number" then
		warn("Invalid argument #2")
		return
	end

	Remotes.Tilt:FireAllClients(player, angle)
end

do
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(HandleCharacters.OnCharacterAdded)
		player.CharacterAppearanceLoaded:Connect(HandleCharacters.OnCharacterAppearanceLoaded)
	end)

	Remotes.Tilt.OnServerEvent:Connect(HandleCharacters.OnTilt)
end

return HandleCharacters
