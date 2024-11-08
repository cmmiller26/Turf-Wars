--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- External dependencies
local Packages = ReplicatedStorage.Packages
local Trove = require(Packages.Trove)

local Utility = ReplicatedStorage.Utility
local FindFirstChildWithTag = require(Utility.FindFirstChildWithTag)
local CreateMultiIndex = require(Utility.CreateMultiIndex)

-- Client modules
local Client = ReplicatedFirst.Client
local Types = require(Client.Types)

local Classes = Client.Classes
local GameInputHandler = require(Classes.GameInputHandler)
local Viewmodel = require(Classes.Viewmodel)

local ToolController = Classes.ToolController
local HammerController = require(ToolController.HammerController)
local SlingshotController = require(ToolController.SlingshotController)

type GameCharacterController = Types.GameCharacterController
type GCCInternal = GameCharacterController & {
	_trove: Trove.Trove,

	_backpack: Backpack,

	_toolJoint: Motor6D,

	_tools: { [string]: Types.ToolController },
	_curTool: Types.ToolController?,

	_tiltAccumulator: number,
	_tiltSendRate: number,
	_prevTiltAngle: number,

	_init: (self: GCCInternal) -> (),

	_onPreRender: (self: GCCInternal) -> (),
	_onPostSimulation: (self: GCCInternal, deltaTime: number) -> (),
}

-- Constants
local FIELD_OF_VIEW = 90

-- Player-related references
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Remote folder reference
local Remotes = ReplicatedStorage.Remotes.GameCharacter

--[=[
	A GameCharacterController is responsible for managing the player's character when in-game.
	It handles equipping and unequipping tools, as well as sending tilt data to the server.
]=]
local GameCharacterController = {}

local GCCPublicMethods = {}
local GCCPrivateMethods = {}

--[=[
	Constructs a GameCharacterController for the given character.
	@param instance Model -- The player's character model
	@return GameCharacterController
]=]
function GameCharacterController.new(instance: Model): GameCharacterController
	local self = setmetatable({} :: GCCInternal, { __index = CreateMultiIndex(GCCPublicMethods, GCCPrivateMethods) })

	self.Instance = instance

	self:_init()

	return self
end

--[=[
	Destroys the GameCharacterController, cleaning up any resources, but does not destroy the character instance.
]=]
function GCCPublicMethods.Destroy(self: GameCharacterController): ()
	(self :: GCCInternal)._trove:Clean()
end

--[=[
	Equips the tool of the given type.
	@param toolType string -- The type of tool to equip
]=]
function GCCPublicMethods.EquipTool(self: GameCharacterController, toolType: string): ()
	local internal = self :: GCCInternal

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

	-- Notify the server that a tool has been equipped
	Remotes.EquipTool:FireServer(toolType)
end

--[=[
	Unequips the currently equipped tool.
	@return boolean -- Returns true if unequipping was successful, false otherwise
]=]
function GCCPublicMethods.Unequip(self: GameCharacterController): boolean
	local internal = self :: GCCInternal
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

	return true -- Unequip was successful
end

--[=[
	Returns the currently equipped tool, if any.
	@return ToolController? -- The currently equipped tool, or nil if no tool is equipped
]=]
function GCCPublicMethods.GetCurrentTool(self: GameCharacterController): Types.ToolController?
	return (self :: GCCInternal)._curTool
end

function GCCPrivateMethods._init(self: GCCInternal): ()
	-- Set the camera to first person
	Camera.FieldOfView = FIELD_OF_VIEW
	LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson

	self._trove = Trove.new()
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

	self._tiltAccumulator = 0
	self._tiltSendRate = Remotes.Tilt.SendRate.Value
	self._prevTiltAngle = 0

	self._trove:Construct(Viewmodel, self.Instance) -- Initialize the viewmodel
	self._trove:Construct(GameInputHandler, self) -- Initialize the input handler

	self._trove:Connect(RunService.PreRender, function()
		self:_onPreRender()
	end)
	self._trove:Connect(RunService.PostSimulation, function(deltaTime: number)
		self:_onPostSimulation(deltaTime)
	end)

	self:EquipTool("Slingshot") -- Equip the slingshot by default
end

function GCCPrivateMethods._onPreRender(self: GCCInternal): ()
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

function GCCPrivateMethods._onPostSimulation(self: GCCInternal, deltaTime: number): ()
	-- Send tilt data to the server at the fixed send rate
	self._tiltAccumulator += deltaTime
	while self._tiltAccumulator >= self._tiltSendRate do
		self._tiltAccumulator -= self._tiltSendRate

		local tiltAngle = math.asin(Camera.CFrame.LookVector.Y)
		if tiltAngle ~= self._prevTiltAngle then
			Remotes.Tilt:FireServer(tiltAngle)
			self._prevTiltAngle = tiltAngle
		end
	end
end

return GameCharacterController
