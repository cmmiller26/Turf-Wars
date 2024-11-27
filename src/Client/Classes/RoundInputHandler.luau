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

-- Player-related references
local ChatInputBarConfiguration = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")

--[=[
    A RoundInputHandler is responsible for managing user input for a RoundCharacterController.
    It handles tool equipping, block placing, and firing projectiles based on user input.
]=]
local RoundInputHandler = {}

local RIHPublicMethods = {}
local RIHPrivateMethods = {}

--[=[
	Constructs a RoundInputHandler for the given RoundCharacterController instance.
	@param controller RoundCharacterController -- The controller to handle input for.
	@return RoundInputHandler -- The RoundInputHandler instance.
]=]
function RoundInputHandler.new(controller: Types.RoundCharacterController): RoundInputHandler
	local self = setmetatable({} :: RIHInternal, { __index = CreateMultiIndex(RIHPublicMethods, RIHPrivateMethods) })

	self:_init(controller)

	return self
end

--[=[
	Destroys the RoundInputHandler, cleaning up all connections.
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

		-- Handle tool switching via keyboard input
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.One then
				self._controller:EquipTool("Slingshot") -- Equip the slingshot
			elseif input.KeyCode == Enum.KeyCode.Two then
				self._controller:EquipTool("Hammer") -- Equip the hammer
			end
		else
			if not self._curTool then
				return -- No tool equipped
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
			return -- No tool equipped
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self._curTool:ActivatePrimary(false)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			self._curTool:ActivateSecondary(false)
		end
	end)

	-- Connect post-simulation behavior (managing cursor and mouse behavior)
	self._trove:Connect(RunService.PostSimulation, function()
		self:_onPostSimulation()
	end)

	-- When the input handler is destroyed, reset the mouse icon
	self._trove:Add(function()
		UserInputService.MouseIcon = DEFAULT_MOUSE_ICON
	end)
end

function RIHPrivateMethods._onPostSimulation(self: RIHInternal): ()
	-- Unlock/lock the mouse based on whether the chat input bar is focused
	if ChatInputBarConfiguration.IsFocused then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIcon = DEFAULT_MOUSE_ICON
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		-- If a tool is equipped, show the tool's cursor
		if self._curTool then
			UserInputService.MouseIcon = self._curTool.MouseIcon
			UserInputService.MouseIconEnabled = true
		else
			UserInputService.MouseIconEnabled = false
		end
	end
end

return RoundInputHandler
