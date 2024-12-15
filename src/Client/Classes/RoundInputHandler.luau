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
local ClientTypes = require(ReplicatedFirst.Client.ClientTypes)

type RoundInputHandler = ClientTypes.RoundInputHandler
type RIHInternal = RoundInputHandler & {
	_trove: Trove.Trove,

	_controller: ClientTypes.RoundCharacterController,

	_curTool: ClientTypes.ToolController?,

	_init: (self: RIHInternal, controller: ClientTypes.RoundCharacterController) -> (),

	_onPostSimulation: (self: RIHInternal) -> (),
}

-- Constants
local DEFAULT_MOUSE_ICON = "rbxasset://SystemCursors/Arrow"

-- Player-related variables
local ChatInputBarConfiguration = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")

--[[
	Resets the mouse to its default behavior and icon.
]]
local function ResetMouse()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIcon = DEFAULT_MOUSE_ICON
	UserInputService.MouseIconEnabled = true
end

--[=[
	The [Trove] used to manage the round input handler's connections.
	@prop _trove Trove
	@private
	@within RoundInputHandler
]=]
--[=[
	The [RoundCharacterController] the input handler handles input for.
	@prop _controller RoundCharacterController
	@private
	@within RoundInputHandler
]=]
--[=[
	The currently equipped [ToolController].
	@prop _curTool ToolController?
	@private
	@within RoundInputHandler
]=]

--[=[
	RoundInputHandler manages the user input for a [RoundCharacterController] by connecting it to [UserInputService] events.
	It handles the input for tool usage and switching, and controls the mouse's behavior and icon.
	@class RoundInputHandler
	@client
]=]
local RoundInputHandler = {}

local RIHPublicMethods = {}
local RIHPrivateMethods = {}

--[=[
	Constructs a new `RoundInputHandler` for the given [RoundCharacterController].
	@param controller RoundCharacterController
	@return RoundInputHandler
	@within RoundInputHandler
]=]
function RoundInputHandler.new(controller: ClientTypes.RoundCharacterController): RoundInputHandler
	local self = setmetatable({} :: RIHInternal, { __index = CreateMultiIndex(RIHPublicMethods, RIHPrivateMethods) })

	self:_init(controller)

	return self
end

--[=[
	Cleans up all connections used by the input handler.
	@method Destroy
	@within RoundInputHandler
]=]
function RIHPublicMethods.Destroy(self: RIHInternal): ()
	self._trove:Clean()
end

--[=[
	Initializes the input handler with the given [RoundCharacterController], connecting it to [UserInputService] events.
	@method _init
	@private
	@within RoundInputHandler
]=]
function RIHPrivateMethods._init(self: RIHInternal, controller: ClientTypes.RoundCharacterController): ()
	self._trove = Trove.new()

	self._controller = controller

	self._trove:Add(self._controller.ToolEquipped:Connect(function(tool: ClientTypes.ToolController)
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

--[=[
	Processes post-simulation updates, setting the mouse icon and behavior based on the current state of the input handler.
	If a tool is equipped, the tool's [ToolController.MouseIcon] is shown.
	@method _onPostSimulation
	@private
	@within RoundInputHandler
]=]
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
