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

type ToolController = {
	Instance: Model,

	Destroy: (self: ToolController) -> (),

	Equip: (self: ToolController) -> (),
	Unequip: (self: ToolController) -> (),
}

local FIELD_OF_VIEW = 90

local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage.Remotes

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
	if not tool then
		error("Tool not found", 2)
	end

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
	if not IsCharacterAlive(self.Instance) then
		error("Character is not alive", 2)
	end

	Camera.FieldOfView = FIELD_OF_VIEW
	LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson

	self._trove = Trove.new()

	do
		local hammer = FindFirstChildWithTag(LocalPlayer.Backpack, "Hammer")
		if not (hammer and hammer:IsA("Model")) then
			error("'Hammer' Model not found in backpack", 2)
		end

		local slingshot = FindFirstChildWithTag(LocalPlayer.Backpack, "Slingshot")
		if not (slingshot and slingshot:IsA("Model")) then
			error("'Slingshot' Model not found in backpack", 2)
		end

		self._tools = {
			Hammer = self._trove:Construct(HammerController, hammer, self.Instance),
			Slingshot = self._trove:Construct(SlingshotController, slingshot, self.Instance),
		}
	end

	local toolJoint = (self.Instance:FindFirstChild("Torso") :: Instance):FindFirstChild("ToolJoint")
	if not (toolJoint and toolJoint:IsA("Motor6D")) then
		error("'ToolJoint' Motor6D not found in torso", 2)
	end
	self._toolJoint = toolJoint

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
