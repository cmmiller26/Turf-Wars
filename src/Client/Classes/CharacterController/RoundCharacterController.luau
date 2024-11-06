--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- External dependencies
local Signal = require(ReplicatedStorage.Packages.Signal)

local Utility = ReplicatedStorage.Utility
local FindFirstChildWithTag = require(Utility.FindFirstChildWithTag)
local CreateMultiIndex = require(Utility.CreateMultiIndex)

-- Client modules
local Client = ReplicatedFirst.Client
local Types = require(Client.Types)

local CharacterController = require(script.Parent)

local Classes = Client.Classes
local RoundInputHandler = require(Classes.RoundInputHandler)
local Viewmodel = require(Classes.Viewmodel)

local ToolController = Classes.ToolController
local HammerController = require(ToolController.HammerController)
local SlingshotController = require(ToolController.SlingshotController)

type RoundCharacterController = Types.RoundCharacterController
type RCCInternal = RoundCharacterController & CharacterController.CCInherited & {
	_backpack: Backpack,

	_toolJoint: Motor6D,

	_tools: { [string]: Types.ToolController },
	_curTool: Types.ToolController?,

	_init: (self: RCCInternal) -> (),

	_onPreRender: (self: RCCInternal) -> (),
}

-- Constants
local FIELD_OF_VIEW = 90

-- Player-related references
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Remote folder reference
local Remotes = ReplicatedStorage.Remotes.Character

--[=[
	A RoundCharacterController inherits CharacterController and is responsible for managing the player's character when in-game.
	It handles equipping and unequipping tools, as well as sending tilt data to the server.
]=]
local RoundCharacterController = {}

local RCCPublicMethods = {}
local RCCPrivateMethods = {}

--[=[
	Constructs a RoundCharacterController for the given character.
	@param instance Model -- The player's character model
	@return RoundCharacterController
]=]
function RoundCharacterController.new(instance: Model): RoundCharacterController
	local self = setmetatable(
		CharacterController.new(instance) :: RCCInternal,
		{ __index = CreateMultiIndex(RCCPublicMethods, RCCPrivateMethods, CharacterController.InheritedMethods) }
	)

	self.ToolEquipped = Signal.new()
	self.ToolUnequipped = Signal.new()

	self:_init()

	return self
end

--[=[
	Equips the tool of the given type.
	@param toolType string -- The type of tool to equip
]=]
function RCCPublicMethods.EquipTool(self: RoundCharacterController, toolType: string): ()
	local internal = self :: RCCInternal

	-- Validate that the character has the specified tool
	local tool = internal._tools[toolType]
	if not tool then
		warn(string.format("%s is not a valid tool", toolType))
		return
	end

	local prevTool = internal._curTool -- Store reference to the currently equipped tool

	-- If unequipping fails (e.g., the tool is active), do not proceed with equipping the new tool
	if not self:Unequip() then
		return
	end

	-- If the tool is already equipped, fire the Unequip remote event and stop further execution
	if prevTool == tool then
		Remotes.Unequip:FireServer()
		return
	end

	-- Set the new tool as the currently equipped tool and trigger equip logic
	internal._curTool = tool
	tool:Equip()

	--[[
		Ensure the tool is attached to the character after the equip animation starts
		This prevents the tool from appearing too early
	]]
	task.spawn(function()
		RunService.PreAnimation:Wait()
		internal._toolJoint.Part1 = tool.Instance.PrimaryPart
		tool.Instance.Parent = self.Instance
	end)

	-- Notify listeners and the server that a tool has been equipped
	self.ToolEquipped:Fire(tool)
	Remotes.EquipTool:FireServer(toolType)
end

--[=[
	Unequips the currently equipped tool.
	@return boolean -- Returns true if unequipping was successful, false otherwise
]=]
function RCCPublicMethods.Unequip(self: RoundCharacterController): boolean
	local internal = self :: RCCInternal
	local tool = internal._curTool

	-- No tool equipped, so consider the unequip successful
	if not tool then
		return true
	end

	-- If the tool is active (e.g., being fired or used), we cannot unequip it
	if tool.IsActive then
		return false
	end

	-- Reset the currently equipped tool and trigger the unequip logic
	internal._curTool = nil
	tool:Unequip()

	-- Detach the tool from the character and move it to the backpack
	internal._toolJoint.Part1 = nil
	tool.Instance.Parent = internal._backpack

	-- Notify listeners that a tool has been unequipped
	self.ToolUnequipped:Fire(tool)

	return true -- Unequip was successful
end

--[=[
	Returns the currently equipped tool, if any.
	@return ToolController? -- The currently equipped tool, or nil if no tool is equipped
]=]
function RCCPublicMethods.GetCurrentTool(self: RoundCharacterController): Types.ToolController?
	return (self :: RCCInternal)._curTool
end

function RCCPrivateMethods._init(self: RCCInternal): ()
	self._className = "RoundCharacterController"

	-- Set the camera to first person
	Camera.FieldOfView = FIELD_OF_VIEW
	LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson

	self._trove:Add(self, "Unequip")

	self._backpack = LocalPlayer:FindFirstChildOfClass("Backpack")

	-- Find the tool joint in the character model
	local toolJoint = (self.Instance:FindFirstChild("Torso") :: Instance):FindFirstChild("ToolJoint")
	if not (toolJoint and toolJoint:IsA("Motor6D")) then
		error("'ToolJoint' Motor6D not found in Instance", 2)
	end
	self._toolJoint = toolJoint

	-- Initialize the hammer and slingshot controllers
	local hammer = FindFirstChildWithTag(self._backpack, "Hammer")
	if not (hammer and hammer:IsA("Model")) then
		error("Hammer not found in Backpack", 2)
	end
	local slingshot = FindFirstChildWithTag(self._backpack, "Slingshot")
	if not (slingshot and slingshot:IsA("Model")) then
		error("Slingshot not found in Backpack", 2)
	end
	self._tools = {
		Hammer = HammerController.new(hammer, self.Instance),
		Slingshot = SlingshotController.new(slingshot, self.Instance),
	}

	self._trove:Construct(Viewmodel, self.Instance) -- Initialize the viewmodel
	self._trove:Construct(RoundInputHandler, self) -- Initialize the input handler

	self._trove:Connect(RunService.PreRender, function()
		self:_onPreRender()
	end)

	self:EquipTool("Slingshot") -- Equip the slingshot by default
end

function RCCPrivateMethods._onPreRender(self: RCCInternal): ()
	if not self._curTool then
		return
	end

	--[[
		The tool joint's C0 is set by the server to replicate tilt
		So we need to reset it locally to keep it fixed to the viewmodel
	]]
	self._toolJoint.C0 = CFrame.new()

	-- Hide the tool's shadow and make sure it's visible
	for _, part in ipairs(self._curTool.Instance:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CastShadow = false
			part.LocalTransparencyModifier = 0
		end
	end
end

return RoundCharacterController
