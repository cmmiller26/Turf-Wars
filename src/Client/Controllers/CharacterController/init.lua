--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage.Packages.Trove)

local Utility = ReplicatedStorage.Utility
local FindFirstChildWithTag = require(Utility.FindFirstChildWithTag)
local IsCharacterAlive = require(Utility.IsCharacterAlive)

local HammerController = require(script.HammerController)
local SlingshotController = require(script.SlingshotController)

local Viewmodel = require(script.Viewmodel)

local ReplicateTilt = require(script.ReplicateTilt)

type ToolController = {
	Instance: Model,
	Destroy: (self: ToolController) -> (),

	Equip: (self: ToolController) -> (),
	Unequip: (self: ToolController) -> (),
}

export type CharacterController = {
	Instance: Model,
	Destroy: (self: CharacterController) -> (),

	EquipTool: (self: CharacterController, toolName: string) -> (),
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

	_unequip: (self: self) -> ToolController?,

	_onPreRender: (self: self) -> (),
}

local FIELD_OF_VIEW = 90

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Remotes = ReplicatedStorage.Remotes.Character

local CharacterController = {}
CharacterController.__index = CharacterController

function CharacterController.new(instance: Model): CharacterController
	local self = setmetatable({} :: self, CharacterController)

	self.Instance = instance
	self:_init()

	return self
end
function CharacterController.Destroy(self: self)
	self._trove:Clean()
end

function CharacterController.EquipTool(self: self, toolName: string)
	local tool = self._tools[toolName] :: ToolController
	assert(tool, "CharacterController.EquipTool(): Expected 'Slingshot' or 'Hammer' for argument #1, got " .. toolName)

	local prevTool = self:_unequip()
	if prevTool == tool then
		Remotes.Unequip:FireServer()
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

function CharacterController._init(self: self)
	assert(IsCharacterAlive(self.Instance), "CharacterController.new(): Instance must be alive")

	LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	Camera.FieldOfView = FIELD_OF_VIEW

	self._trove = Trove.new()
	self._trove:Add(self, "_unequip")

	do
		local hammer = FindFirstChildWithTag(LocalPlayer.Backpack, "Hammer")
		assert(
			typeof(hammer) == "Instance" and hammer:IsA("Model"),
			"CharacterController._init(): Expected Model tagged 'Hammer' in LocalPlayer.Backpack, got "
				.. typeof(hammer)
		)
		local slingshot = FindFirstChildWithTag(LocalPlayer.Backpack, "Slingshot")
		assert(
			typeof(slingshot) == "Instance" and slingshot:IsA("Model"),
			"CharacterController._init(): Expected Model tagged 'Slingshot' in LocalPlayer.Backpack, got "
				.. typeof(slingshot)
		)
		self._tools = {
			Hammer = self._trove:Construct(HammerController, hammer, self.Instance),
			Slingshot = self._trove:Construct(SlingshotController, slingshot, self.Instance),
		}
		print("Created CharacterController ToolControllers")
	end

	do
		local torso = self.Instance:FindFirstChild("Torso")
		assert(torso, "CharacterController._init(): Expected 'Torso' in Instance")

		local toolJoint = torso:FindFirstChild("ToolJoint")
		assert(
			typeof(toolJoint) == "Instance" and toolJoint:IsA("Motor6D"),
			"CharacterController._init(): Expected 'ToolJoint' Motor6D in Instance.Torso, got " .. typeof(toolJoint)
		)
		self._toolJoint = toolJoint
	end

	self._trove:Construct(Viewmodel, self.Instance)

	self._trove:Add(ReplicateTilt(Remotes.Tilt, Remotes.Tilt.SendRate.Value))

	do
		self._trove:Connect(UserInputService.InputBegan, function(input: InputObject, gameProcessedEvent: boolean)
			if gameProcessedEvent then
				return
			end

			if input.UserInputType == Enum.UserInputType.Keyboard then
				if input.KeyCode == Enum.KeyCode.One then
					self:EquipTool("Slingshot")
				elseif input.KeyCode == Enum.KeyCode.Two then
					self:EquipTool("Hammer")
				end
			end
		end)

		self._trove:Connect(RunService.PreRender, function()
			self:_onPreRender()
		end)
	end

	self:EquipTool("Slingshot")
end

function CharacterController._unequip(self: self): ToolController?
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

function CharacterController._onPreRender(self: self)
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

return CharacterController
