--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- External dependencies
local SharedTypes = require(ReplicatedStorage.SharedTypes)
local Signal = require(ReplicatedStorage.Packages.Signal)

local Utility = ReplicatedStorage.Utility
local FindFirstChildWithTag = require(Utility.FindFirstChildWithTag)
local CreateMultiIndex = require(Utility.CreateMultiIndex)

-- Client modules
local Client = ReplicatedFirst.Client
local ClientTypes = require(Client.ClientTypes)

local Classes = Client.Classes
local RoundInputHandler = require(Classes.RoundInputHandler)
local Viewmodel = require(Classes.Viewmodel)

local ToolController = Classes.ToolController
local HammerController = require(ToolController.HammerController)
local SlingshotController = require(ToolController.SlingshotController)

-- Superclass
local CharacterController = require(script.Parent)

type RoundCharacterController = ClientTypes.RoundCharacterController
type RCCInternal = RoundCharacterController & CharacterController.CCProtected & {
	_backpack: Backpack,

	_combatEnabled: boolean,

	_toolJoint: Motor6D,

	_tools: { [SharedTypes.ToolType]: ClientTypes.ToolController },
	_curTool: ClientTypes.ToolController?,

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
	Fired when a tool is equipped.
	@prop ToolEquipped Signal<ToolController>
	@within RoundCharacterController
]=]
--[=[
	Fired when a tool is unequipped.
	@prop ToolUnequipped Signal<ToolController>
	@within RoundCharacterController
]=]

--[=[
	The player's backpack.
	@prop _backpack Backpack
	@private
	@within RoundCharacterController
]=]
--[=[
	Whether combat is enabled for the character.
	@prop _combatEnabled boolean
	@private
	@within RoundCharacterController
]=]
--[=[
	The tool joint used to attach tools to the character.
	@prop _toolJoint Motor6D
	@private
	@within RoundCharacterController
]=]
--[=[
	The tools the character controller manages.
	@prop _tools { [ToolType]: ToolController }
	@private
	@within RoundCharacterController
]=]
--[=[
	The currently equipped tool.
	@prop _curTool ToolController?
	@private
	@within RoundCharacterController
]=]

--[=[
	RoundCharacterController extends [CharacterController] to manage the player's character during gameplay rounds. 
	It handles equipping and unequipping tools, enabling or disabling combat, and synchronizing tools with the character's 
	animations and viewmodel. The class also integrates with [ToolController] instances, such as the Slingshot and Hammer, 
	to provide seamless tool functionality.

	### Features:
	- **Tool Management**: Equips and unequips tools dynamically based on gameplay actions, ensuring that tools are 
	  properly attached to the character and interactable.
	- **Combat State Handling**: Manages whether the character can engage in combat.
	- **Viewmodel Synchronization**: Ensures that tools visually align with the character's view in first-person mode.
	- **Event Signals**: Fires signals when tools are equipped or unequipped for additional client-side processing.
	
	### Server Interaction:
	- The `EquipTool` method fires the `EquipTool` [RemoteEvent] to notify the server about the tool being equipped.
	- The `Unequip` method fires the `Unequip` [RemoteEvent] to notify the server about the tool being unequipped.
	- These remotes are handled by the [RoundPlayerHandler], ensuring consistent state management across the server and clients.

	This class is specifically designed for managing characters in active gameplay scenarios, providing a robust foundation 
	for tool and combat interactions during rounds.
	
	@class RoundCharacterController
	@tag CharacterController
]=]
local RoundCharacterController = {}

local RCCPublicMethods = {}
local RCCPrivateMethods = {}

--[=[
	Constructs a new `RoundCharacterController` for the given character [Model].
	@param instance Model
	@return RoundCharacterController
	@within RoundCharacterController
]=]
function RoundCharacterController.new(instance: Model): RoundCharacterController
	local self = setmetatable({} :: RCCInternal, {
		__index = CreateMultiIndex(
			RCCPublicMethods,
			RCCPrivateMethods,
			CharacterController.PublicMethods,
			CharacterController.PrivateMethods
		),
	})

	self:_init(instance)

	return self
end

--[=[
	Equips the tool of the given type.
	@method EquipTool
	@param toolType ToolType
	@within RoundCharacterController
]=]
function RCCPublicMethods.EquipTool(self: RCCInternal, toolType: SharedTypes.ToolType): ()
	if not self._isAlive then
		return
	end

	local tool = self._tools[toolType]
	if not tool then
		warn(string.format("[RoundCharacterController:EquipTool]: Tool of type %s not found", toolType))
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

	print(string.format("[RoundCharacterController:EquipTool]: Equipped %s", toolType))
end

--[=[
	Unequips the current tool.
	@method Unequip
	@return boolean -- Whether the tool was successfully unequipped.
	@within RoundCharacterController
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
	Returns the currently equipped tool.
	@method GetCurrentTool
	@return ToolController?
	@within RoundCharacterController
]=]
function RCCPublicMethods.GetCurrentTool(self: RCCInternal): ClientTypes.ToolController?
	return self._curTool
end

--[=[
	Returns whether combat is enabled for the character.
	@method GetCombatEnabled
	@return boolean
	@within RoundCharacterController
]=]
function RCCPublicMethods.GetCombatEnabled(self: RCCInternal): boolean
	return self._combatEnabled
end

--[=[
	Sets whether combat is enabled for the character.
	@method SetCombatEnabled
	@param enabled boolean
	@within RoundCharacterController
]=]
function RCCPublicMethods.SetCombatEnabled(self: RCCInternal, enabled: boolean): ()
	self._combatEnabled = enabled
end

--[=[
	Overrides [CharacterController:_init] to construct its [ToolController] instances, [Viewmodel], and [RoundInputHandler].
	@method _init
	@param instance Model
	@private
	@tag Override
	@within RoundCharacterController
]=]
function RCCPrivateMethods._init(self: RCCInternal, instance: Model): ()
	print("[RoundCharacterController:_init]: Initializing...")

	self._characterType = "RoundCharacter"

	CharacterController.PrivateMethods._init(self, instance)

	self.ToolEquipped = self._trove:Construct(Signal)
	self.ToolUnequipped = self._trove:Construct(Signal)

	self._backpack = LocalPlayer:FindFirstChildOfClass("Backpack")

	self._combatEnabled = false

	local toolJoint = (self.Instance:FindFirstChild("Torso") :: Instance):FindFirstChild("ToolJoint")
	if not (toolJoint and toolJoint:IsA("Motor6D")) then
		error("[RoundCharacterController:_init]: ToolJoint not found in Instance", 2)
	end
	self._toolJoint = toolJoint

	local hammer = FindFirstChildWithTag(self._backpack, "Hammer")
	if not (hammer and hammer:IsA("Model")) then
		error("[RoundCharacterController:_init]: Hammer not found in Backpack", 2)
	end
	local slingshot = FindFirstChildWithTag(self._backpack, "Slingshot")
	if not (slingshot and slingshot:IsA("Model")) then
		error("[RoundCharacterController:_init]: Slingshot not found in Backpack", 2)
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

	self:EquipTool("Slingshot") -- Equip the slingshot by default

	print("[RoundCharacterController:_init]: Initialized")
end

--[=[
	Processes pre-render updates, such as resetting the tool joint's C0 and hiding the tool's shadow.
	@method _onPreRender
	@private
	@within RoundCharacterController
]=]
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
