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
    The `RoundInputHandler` module manages player inputs during a game round, providing seamless integration with tools and character controls.
	It dynamically handles mouse and keyboard inputs to allow tool usage, tool switching, and smooth interaction with the game environment.

    This module works in conjunction with the `RoundCharacterController` to ensure proper tool management and gameplay responsiveness.

    **Responsibilities:**
    - **Tool Management:** Enables equipping, unequipping, and using tools (primary and secondary actions).
    - **Input Handling:** Captures and processes mouse and keyboard inputs to control tool usage and tool switching.
    - **Mouse Behavior:** Dynamically updates the mouse behavior and cursor based on the current game state and equipped tool.
    - **State Cleanup:** Cleans up all input-related connections and resets mouse behavior when destroyed.

    **Key Features:**
    - **Keyboard Shortcuts:** Supports switching tools via keyboard shortcuts (e.g., `1` for Slingshot, `2` for Hammer).
    - **Mouse Control:** Handles mouse button actions for tool usage (e.g., firing projectiles or placing blocks).
    - **Dynamic Mouse Icon Updates:** Updates the mouse icon based on the equipped tool or resets it when no tool is equipped.
    - **Integrated Cleanup:** Leverages `Trove` to manage connections and ensure proper cleanup on destruction.

    **Public Methods:**
    - `new(controller: Types.RoundCharacterController): RoundInputHandler`: Creates a new `RoundInputHandler` for the specified character controller.
    - `Destroy(self: RIHInternal): ()`: Cleans up all connections and resets the mouse state.

    **Notes:**
    - Depends on `RoundCharacterController` for tool management and state synchronization.
    - Designed for dynamic and responsive gameplay, allowing smooth tool interactions and state transitions.
    - Automatically disables mouse controls when the chat input bar is focused to avoid input conflicts.
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
		return
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
