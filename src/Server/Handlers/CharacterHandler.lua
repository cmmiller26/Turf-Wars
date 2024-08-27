--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IsCharacterAlive = require(ReplicatedStorage.Utility.IsCharacterAlive)

local Remotes = ReplicatedStorage.Remotes.Character

local CharacterHandler = {}

function CharacterHandler.OnEquipTool(player: Player, tool: Model)
	assert(
		typeof(tool) == "Instance" and tool:IsA("Model"),
		"CharacterHandler.OnEquipTool(): Expected Model for argument #2, got " .. typeof(tool)
	)

	local backpack = player.Backpack
	assert(
		tool.Parent == backpack,
		"CharacterHandler.OnEquipTool(): "
			.. player.Name
			.. " attempted to equip "
			.. tool.Name
			.. " which is not in their Backpack"
	)

	local character = player.Character
	assert(
		character and IsCharacterAlive(character),
		"CharacterHandler.OnEquipTool(): " .. player.Name .. " attempted to equip " .. tool.Name .. " while dead"
	)

	local torso = character:FindFirstChild("Torso")
	assert(torso, "CharacterHandler.OnEquipTool(): Could not find 'Torso' in " .. player.Name .. "'s Character")
	local toolJoint = torso:FindFirstChild("ToolJoint") :: Motor6D
	assert(
		typeof(toolJoint) == "Instance" and toolJoint:IsA("Motor6D"),
		"CharacterHandler.OnEquipTool(): Could not find 'ToolJoint' Motor6D in " .. player.Name .. "'s Character.Torso"
	)

	local otherTool = toolJoint.Part1 and toolJoint.Part1.Parent
	if otherTool then
		otherTool.Parent = backpack
	end

	toolJoint.Part1 = tool.PrimaryPart
	tool.Parent = character
end
function CharacterHandler.OnUnequip(player: Player)
	local character = player.Character
	if not character then
		return
	end

	local torso = character:FindFirstChild("Torso")
	if not torso then
		return
	end

	local toolJoint = torso:FindFirstChild("ToolJoint")
	if not toolJoint then
		return
	end
	assert(
		toolJoint:IsA("Motor6D"),
		"CharacterHandler.OnUnequip(): Could not find 'ToolJoint' Motor6D in " .. player.Name .. "'s Character.Torso"
	)

	local tool = toolJoint.Part1 and toolJoint.Part1.Parent
	assert(tool, "CharacterHandler.OnUnequip(): " .. player.Name .. " attempted to unequip without a tool to unequip")

	toolJoint.Part1 = nil
	tool.Parent = player.Backpack
end

function CharacterHandler.OnTilt(player: Player, angle: number)
	assert(
		typeof(angle) == "number",
		"CharacterHandler.OnTilt(): Expected number for argument #2, got " .. typeof(angle)
	)
	Remotes.Tilt:FireAllClients(player, angle)
end

do
	Remotes.EquipTool.OnServerEvent:Connect(CharacterHandler.OnEquipTool)
	Remotes.Unequip.OnServerEvent:Connect(CharacterHandler.OnUnequip)
	Remotes.Tilt.OnServerEvent:Connect(CharacterHandler.OnTilt)
end

return CharacterHandler
