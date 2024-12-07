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

local Classes = Client.Classes
local RoundInputHandler = require(Classes.RoundInputHandler)
local Viewmodel = require(Classes.Viewmodel)

local ToolController = Classes.ToolController
local HammerController = require(ToolController.HammerController)
local SlingshotController = require(ToolController.SlingshotController)

-- Superclass
local CharacterController = require(script.Parent)

type RoundCharacterController = Types.RoundCharacterController
type RCCInternal = RoundCharacterController & CharacterController.CCProtected & {
	_backpack: Backpack,

	_combatEnabled: boolean,

	_toolJoint: Motor6D,

	_tools: { [string]: Types.ToolController },
	_curTool: Types.ToolController?,

	_onPreRender: (self: RCCInternal) -> (),
}

-- Constants
local FIELD_OF_VIEW = 90

-- Player-related variables
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Remote events folder
local Remotes = ReplicatedStorage.Remotes.Character

--[=[
	RoundCharacterController is a specialized extension of CharacterController designed for managing player characters during a game round.

	This class adds support for:
	- Equipping and unequipping tools dynamically.
	- Handling first-person camera settings and tool attachments.
	- Managing interactions with tools such as hammers and slingshots.
	- Synchronizing tool states and actions with the server.

	Responsibilities:
	- Maintain and update the currently equipped tool.
	- Interact with server events for tool-related actions.
	- Provide seamless integration with animations and character behavior.

	Notes:
	- This class depends on tool controllers (`HammerController`, `SlingshotController`) and assumes specific tools are available in the player's backpack.
	- This class should not be instantiated directly outside the game round context.
]=]
local RoundCharacterController = {}

local RCCPublicMethods = {}
local RCCPrivateMethods = {}

--[=[
	Constructs a round character controller for the given character model.
	@param instance -- The character `Model` to control.
	@return RoundCharacterController -- The round character controller instance.
]=]
function RoundCharacterController.new(instance: Model): RoundCharacterController
	local self = setmetatable({} :: RCCInternal, {
		__index = CreateMultiIndex(
			RCCPublicMethods,
			RCCPrivateMethods,
			CharacterController.PublicMethods,
			CharacterController.ProtectedMethods
		),
	})

	self:_init(instance)

	return self
end

--[=[
	Equips the tool of the given type.
	@param toolType -- The `ToolType` of the tool to equip.
]=]
function RCCPublicMethods.EquipTool(self: RCCInternal, toolType: Types.ToolType): ()
	if not self._isAlive then
		return
	end

	local tool = self._tools[toolType]
	if not tool then
		warn(string.format("[RoundCharacterController.EquipTool]: Tool of type %s not found", toolType))
		return
	end

	local prevTool = self._curTool

	-- If unequipping the current tool fails, stop further execution
	if not self:Unequip() then
		return
	end

	-- If the tool is already equipped, fire the Unequip remote event and stop further execution
	if prevTool == tool then
		Remotes.Unequip:FireServer()
		return
	end

	self._curTool = tool
	tool:Equip()

	--[[
		Ensure the tool is attached to the character after the equip animation starts
		This prevents the tool from appearing too early
	]]
	task.spawn(function()
		RunService.PreAnimation:Wait()
		self._toolJoint.Part1 = tool.Instance.PrimaryPart
		tool.Instance.Parent = self.Instance
	end)

	self.ToolEquipped:Fire(tool)
	Remotes.EquipTool:FireServer(toolType)
end

--[=[
	Unequips the currently equipped tool.
	@return boolean -- True if the current tool was successfully unequipped, false otherwise.
]=]
function RCCPublicMethods.Unequip(self: RCCInternal): boolean
	local tool = self._curTool
	if not tool then
		return true
	end

	if tool.IsActive then
		return false
	end

	self._curTool = nil
	tool:Unequip()

	self._toolJoint.Part1 = nil
	tool.Instance.Parent = self._backpack

	self.ToolUnequipped:Fire(tool)

	return true
end

--[=[
	Returns the currently equipped tool, if any.
	@return ToolController? -- The currently equipped tool, or nil if no tool is equipped.
]=]
function RCCPublicMethods.GetCurrentTool(self: RCCInternal): Types.ToolController?
	return self._curTool
end

--[=[
	Returns whether combat is enabled for the character controller.
	@return boolean -- Whether combat is enabled.
]=]
function RCCPublicMethods.GetCombatEnabled(self: RCCInternal): boolean
	return self._combatEnabled
end

--[=[
	Sets whether combat is enabled for the character controller.
	@param enabled -- Whether combat is enabled.
]=]
function RCCPublicMethods.SetCombatEnabled(self: RCCInternal, enabled: boolean): ()
	self._combatEnabled = enabled
end

-- @Override
function RCCPrivateMethods._init(self: RCCInternal, instance: Model): ()
	self._className = "RoundCharacterController"

	print("[RoundCharacterController._init]: Initializing...")

	CharacterController.ProtectedMethods._init(self, instance)

	self.ToolEquipped = self._trove:Construct(Signal)
	self.ToolUnequipped = self._trove:Construct(Signal)

	self._backpack = LocalPlayer:FindFirstChildOfClass("Backpack")

	self._combatEnabled = false

	local toolJoint = (self.Instance:FindFirstChild("Torso") :: Instance):FindFirstChild("ToolJoint")
	if not (toolJoint and toolJoint:IsA("Motor6D")) then
		error("[RoundCharacterController._init]: ToolJoint not found in Instance", 2)
	end
	self._toolJoint = toolJoint

	local hammer = FindFirstChildWithTag(self._backpack, "Hammer")
	if not (hammer and hammer:IsA("Model")) then
		error("[RoundCharacterController._init]: Hammer not found in Backpack", 2)
	end
	local slingshot = FindFirstChildWithTag(self._backpack, "Slingshot")
	if not (slingshot and slingshot:IsA("Model")) then
		error("[RoundCharacterController._init]: Slingshot not found in Backpack", 2)
	end
	self._tools = {
		Hammer = self._trove:Construct(HammerController, hammer, self),
		Slingshot = self._trove:Construct(SlingshotController, slingshot, self),
	}

	self._trove:Construct(Viewmodel, self.Instance)
	self._trove:Construct(RoundInputHandler, self)

	self._trove:Connect(RunService.PreRender, function()
		self:_onPreRender()
	end)

	Camera.FieldOfView = FIELD_OF_VIEW
	LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson

	print("[RoundCharacterController._init]: Initialized")

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
