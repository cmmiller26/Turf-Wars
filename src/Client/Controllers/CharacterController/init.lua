--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Trove = require(ReplicatedStorage.Packages.Trove)

local FindFirstChildWithTag = require(ReplicatedStorage.Utility.FindFirstChildWithTag)

local HammerController = require(script.HammerController)
local SlingshotController = require(script.SlingshotController)

type ToolController = {
	Instance: Model,
	Destroy: (self: ToolController) -> (),

	Equip: (self: ToolController) -> (),
	Unequip: (self: ToolController) -> (),
}

export type CharacterController = {
	Instance: Model,
	Destroy: (self: self) -> (),

	EquipTool: (self: self, toolName: "Hammer" | "Slingshot") -> (),
}
type self = CharacterController & {
	_trove: Trove.Trove,

	_tools: {
		Hammer: HammerController.HammerController,
		Slingshot: SlingshotController.SlingshotController,
	},
	_curTool: ToolController?,

	_toolJoint: Motor6D,

	_init: (self: self) -> (),

	_unequipCurTool: (self: self) -> ToolController?,
	_updateCurTool: (self: self) -> (),
}

local LocalPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage.Remotes

local CharacterController = {}
CharacterController.__index = CharacterController

function CharacterController.new(instance: Model): CharacterController
	assert(
		typeof(instance) == "Instance" and instance:IsA("Model"),
		"CharacterController.new() expected a Model for argument #1, got " .. typeof(instance)
	)

	local self = setmetatable({} :: self, CharacterController)

	self.Instance = instance
	self:_init()

	return self
end
function CharacterController.Destroy(self: self): ()
	self._trove:Clean()
end

function CharacterController.EquipTool(self: self, toolName: "Hammer" | "Slingshot"): ()
	local tool = self._tools[toolName] :: ToolController
	assert(tool, "CharacterController:EquipTool() expected 'Slingshot' or 'Hammer' for argument #1, got " .. toolName)

	local prevTool = self:_unequipCurTool()
	if prevTool == tool then
		return
	end
	self._curTool = tool

	tool:Equip()

	--[[
		Wait until the next animation frame before attaching the tool to the character
		This prevents a bug where the tool shows up in the wrong position
	]]
	task.spawn(function()
		RunService.PreAnimation:Wait()

		self._toolJoint.Part1 = tool.Instance.PrimaryPart
		tool.Instance.Parent = self.Instance
	end)

	Remotes.EquipTool:FireServer(tool.Instance)
end

function CharacterController._init(self: self): ()
	self._trove = Trove.new()
	self._trove:Add(self, "_unequipCurTool")

	do -- Initialize tools
		local hammer = FindFirstChildWithTag(LocalPlayer.Backpack, "Hammer")
		assert(
			typeof(hammer) == "Instance" and hammer:IsA("Model"),
			"CharacterController:_init() expected a 'Hammer' Model in LocalPlayer.Backpack, got " .. typeof(hammer)
		)
		local slingshot = FindFirstChildWithTag(LocalPlayer.Backpack, "Slingshot")
		assert(
			typeof(slingshot) == "Instance" and slingshot:IsA("Model"),
			"CharacterController:_init() expected a 'Slingshot' Model in LocalPlayer.Backpack, got "
				.. typeof(slingshot)
		)
		self._tools = {
			Hammer = self._trove:Construct(HammerController, hammer),
			Slingshot = self._trove:Construct(SlingshotController, slingshot),
		}
	end

	do -- Find tool joint
		local torso = self.Instance:FindFirstChild("Torso")
		assert(
			typeof(torso) == "Instance" and torso:IsA("Part"),
			"CharacterController:_init() expected a 'Torso' Part in self.Instance, got " .. typeof(torso)
		)
		local toolJoint = torso:FindFirstChild("ToolJoint")
		assert(
			typeof(toolJoint) == "Instance" and toolJoint:IsA("Motor6D"),
			"CharacterController:_init() expected a 'ToolJoint' Motor6D in self.Instance.Torso, got "
				.. typeof(toolJoint)
		)
		self._toolJoint = toolJoint
	end

	self._trove:Connect(RunService.PreRender, function()
		self:_updateCurTool()
	end)

	self:EquipTool("Slingshot")
end

function CharacterController._unequipCurTool(self: self): ToolController?
	if not self._curTool then
		return
	end

	local tool = self._curTool
	self._curTool = nil

	tool:Unequip()

	self._toolJoint.Part1 = nil
	tool.Instance.Parent = LocalPlayer.Backpack

	return tool
end
function CharacterController._updateCurTool(self: self): ()
	if not self._curTool then
		return
	end

	self._toolJoint.C0 = CFrame.new()

	for _, part in ipairs(self._curTool.Instance:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CastShadow = false
			part.LocalTransparencyModifier = 0
		end
	end
end
