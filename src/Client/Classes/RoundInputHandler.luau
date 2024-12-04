--!strict

-- Services
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

-- External dependencies
local Trove = require(ReplicatedStorage.Packages.Trove)
local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

-- Client modules
local Types = require(ReplicatedFirst.Client.Types)

type RoundInputHandler = Types.RoundInputHandler
type RIHInternal = RoundInputHandler & {
	_trove: Trove.Trove,

	_controller: Types.RoundCharacterController,

	_curTool: Types.ToolController?,

	_init: (self: RIHInternal, controller: Types.RoundCharacterController) -> (),

	_onPostSimulation: (self: RIHInternal) -> (),
}

-- Constants
local DEFAULT_MOUSE_ICON = "rbxasset://SystemCursors/Arrow"

-- Player-related variables
local ChatInputBarConfiguration = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")

--[=[
	Resets the mouse to its default state.
]=]
local function ResetMouse()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIcon = DEFAULT_MOUSE_ICON
	UserInputService.MouseIconEnabled = true
end

--[=[
	RoundInputHandler manages player inputs during a round, providing dynamic control for tool usage and tool switching.

	This class integrates with `RoundCharacterController` to handle primary and secondary tool actions, mouse behavior, and keyboard shortcuts for switching tools. It ensures clean state transitions and input handling throughout the round.

	Responsibilities:
	- Manage tool usage (e.g., firing projectiles or placing blocks) via mouse inputs.
	- Allow switching between tools using keyboard shortcuts.
	- Dynamically update mouse behavior and icons based on game state.
	- Clean up all input-related connections and states when destroyed.

	Notes:
	- Depends on `RoundCharacterController` for tool management.
	- Integrates with `Trove` for resource management.
]=]
local RoundInputHandler = {}

local RIHPublicMethods = {}
local RIHPrivateMethods = {}

--[=[
	Constructs a round input handler for the given round character controller.
	@param controller -- The round character controller to manage input for.
	@return RoundInputHandler -- The new round input handler instance.
]=]
function RoundInputHandler.new(controller: Types.RoundCharacterController): RoundInputHandler
	local self = setmetatable({} :: RIHInternal, { __index = CreateMultiIndex(RIHPublicMethods, RIHPrivateMethods) })

	self:_init(controller)

	return self
end

--[=[
	Destroy the round input handler, cleaning up all connections and resources used by it.
]=]
function RIHPublicMethods.Destroy(self: RIHInternal): ()
	self._trove:Clean()
end

function RIHPrivateMethods._init(self: RIHInternal, controller: Types.RoundCharacterController): ()
	self._trove = Trove.new()

	self._controller = controller

	self._trove:Add(self._controller.ToolEquipped:Connect(function(tool: Types.ToolController)
		self._curTool = tool
	end))
	self._trove:Add(self._controller.ToolUnequipped:Connect(function()
		self._curTool = nil
	end))

	-- Connect user input events for tool usage and tool switching
	self._trove:Connect(UserInputService.InputBegan, function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.One then
				self._controller:EquipTool("Slingshot")
			elseif input.KeyCode == Enum.KeyCode.Two then
				self._controller:EquipTool("Hammer")
			end
		else
			if not self._curTool then
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				self._curTool:ActivatePrimary(true)
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				self._curTool:ActivateSecondary(true)
			end
		end
	end)

	-- Handle input release actions (stop deleting blocks or firing projectiles)
	self._trove:Connect(UserInputService.InputEnded, function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end
		if not self._curTool then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self._curTool:ActivatePrimary(false)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			self._curTool:ActivateSecondary(false)
		end
	end)

	self._trove:Connect(RunService.PostSimulation, function()
		self:_onPostSimulation()
	end)

	-- When the input handler is destroyed, reset the mouse icon
	self._trove:Add(ResetMouse)
end

function RIHPrivateMethods._onPostSimulation(self: RIHInternal): ()
	if ChatInputBarConfiguration.IsFocused then
		ResetMouse()
	end

	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	-- If a tool is equipped, show the tool's cursor
	if self._curTool then
		UserInputService.MouseIcon = self._curTool.MouseIcon
		UserInputService.MouseIconEnabled = true
	else
		UserInputService.MouseIconEnabled = false
	end
end

return RoundInputHandler
