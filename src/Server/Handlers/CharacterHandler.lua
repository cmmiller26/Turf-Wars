--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IsCharacterAlive = require(ReplicatedStorage.Utility.IsCharacterAlive)

local Remotes = ReplicatedStorage.Remotes.Character

local CharacterHandler = {}

function CharacterHandler.OnEquipTool(player: Player, tool: Model): ()
	assert(
		typeof(tool) == "Instance" and tool:IsA("Model"),
		"CharacterHandler.OnEquipTool(): Expected Model for argument #2, got " .. typeof(tool)
	)

	local backpack = player:FindFirstChildOfClass("Backpack")
	assert(backpack, "CharacterHandler.OnEquipTool(): Could not find " .. player.Name .. "'s Backpack")

	if tool.Parent ~= backpack then
		warn(
			"CharacterHandler.OnEquipTool(): "
				.. player.Name
				.. " attempted to equip a tool that is not in their backpack"
		)
		return
	end

	local character = player.Character
	if not (character and IsCharacterAlive(character)) then
		warn("CharacterHandler.OnEquipTool(): " .. player.Name .. " attempted to equip a tool while dead")
		return
	end

	local torso = character:FindFirstChild("Torso")
	if not torso then
		warn("CharacterHandler.OnEquipTool(): Could not find a 'Torso' Part in " .. player.Name .. "'s character")
		return
	end

	local toolJoint = torso:FindFirstChild("ToolJoint") :: Motor6D
	if not toolJoint then
		warn("CharacterHandler.OnEquipTool(): Could not find a 'ToolJoint' Motor6D in " .. player.Name .. "'s Torso")
		return
	end

	local otherTool = toolJoint.Part1 and toolJoint.Part1.Parent
	if otherTool then
		otherTool.Parent = backpack
	end

	toolJoint.Part1 = tool.PrimaryPart
	tool.Parent = character
end
function CharacterHandler.OnUnequip(player: Player): ()
	local backpack = player:FindFirstChildOfClass("Backpack")
	assert(backpack, "CharacterHandler.OnUnequip(): Could not find " .. player.Name .. "'s Backpack")

	local character = player.Character
	if not character then
		return
	end

	local torso = character:FindFirstChild("Torso")
	if not torso then
		return
	end

	local toolJoint = torso:FindFirstChild("ToolJoint") :: Motor6D
	if not toolJoint then
		return
	end

	local tool = toolJoint.Part1 and toolJoint.Part1.Parent
	if not tool then
		warn("CharacterHandler.OnUnequip(): " .. player.Name .. " attempted to unequip while not holding a tool")
		return
	end

	toolJoint.Part1 = nil
	tool.Parent = backpack
end

function CharacterHandler.OnTilt(player: Player, angle: number): ()
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
