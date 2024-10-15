--!strict

-- Services
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

-- External dependencies
local Packages = ReplicatedStorage.Packages
local Signal = require(Packages.Signal)
local Trove = require(Packages.Trove)
local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

-- Classes
local Classes = ReplicatedFirst.Client.Classes.Game
local ToolController = require(Classes.ToolController)
local HammerController = require(Classes.ToolController.HammerController)
local SlingshotController = require(Classes.ToolController.SlingshotController)

--[=[
    A GameInputHandler is responsible for managing user input for a GameCharacterController.
    It handles tool equipping, block placing, and firing projectiles based on user input.
]=]
export type GameInputHandler = {
	Destroy: (self: GameInputHandler) -> (),
}
type GIHInternal = GameInputHandler & {
	_trove: Trove.Trove,

	_controller: GameCharacterController,

	_curTool: ToolController.ToolController?,

	_init: (self: GIHInternal, controller: GameCharacterController) -> (),

	_onPostSimulation: (self: GIHInternal) -> (),
}

-- The GameCharacterController type is defined here to avoid circular dependencies
export type GameCharacterController = {
	Instance: Model, -- The character model

	ToolEquipped: Signal.Signal<ToolController.ToolController?>, -- Signal for when a tool is equipped

	Destroy: (self: GameCharacterController) -> (),

	EquipTool: (self: GameCharacterController, string) -> (),
	Unequip: (self: GameCharacterController) -> boolean,
}

-- Constants
local DEFAULT_MOUSE_ICON = "rbxasset://SystemCursors/Arrow"

-- Player-related references
local ChatInputBarConfiguration = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")

local GameInputHandler = {}

local GIHPublicMethods = {}
local GIHPrivateMethods = {}

--[=[
	Constructs a GameInputHandler for the given GameCharacterController.
	@param controller The GameCharacterController to handle input for.
	@return GameInputHandler
]=]
function GameInputHandler.new(controller: GameCharacterController): GameInputHandler
	local self = setmetatable({} :: GIHInternal, { __index = CreateMultiIndex(GIHPublicMethods, GIHPrivateMethods) })

	self:_init(controller)

	return self
end

--[=[
	Destroys the GameInputHandler, cleaning up all connections.
]=]
function GIHPublicMethods.Destroy(self: GameInputHandler): ()
	(self :: GIHInternal)._trove:Clean()
end

function GIHPrivateMethods._init(self: GIHInternal, controller: GameCharacterController): ()
	self._trove = Trove.new()

	self._controller = controller

	-- Connect to the tool equipped signal to track the currently equipped tool
	self._trove:Add(self._controller.ToolEquipped:Connect(function(tool: ToolController.ToolController?)
		self._curTool = tool
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
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and self._curTool then
			-- Handle left-click tool actions (delete blocks or fire projectiles)
			if self._curTool:IsA("HammerController") then
				(self._curTool :: HammerController.HammerController):DeleteBlock(true)
			elseif self._curTool:IsA("SlingshotController") then
				(self._curTool :: SlingshotController.SlingshotController):FireProjectile(true)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 and self._curTool then
			-- Handle right-click tool actions (place blocks)
			if self._curTool:IsA("HammerController") then
				(self._curTool :: HammerController.HammerController):PlaceBlock(true)
			end
		end
	end)

	-- Handle input release actions (stop deleting blocks or firing projectiles)
	self._trove:Connect(UserInputService.InputEnded, function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 and self._curTool then
			if self._curTool:IsA("HammerController") then
				(self._curTool :: HammerController.HammerController):DeleteBlock(false)
			elseif self._curTool:IsA("SlingshotController") then
				(self._curTool :: SlingshotController.SlingshotController):FireProjectile(false)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 and self._curTool then
			if self._curTool:IsA("HammerController") then
				(self._curTool :: HammerController.HammerController):PlaceBlock(false)
			end
		end
	end)

	-- Connect post-simulation behavior (managing cursor and mouse behavior)
	self._trove:Connect(RunService.PostSimulation, function()
		self:_onPostSimulation()
	end)
end

function GIHPrivateMethods._onPostSimulation(self: GIHInternal): ()
	-- Unlock/lock the mouse based on whether the chat input bar is focused
	if ChatInputBarConfiguration.IsFocused then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIcon = DEFAULT_MOUSE_ICON
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		-- If a tool is equipped, show the gun cursor
		UserInputService.MouseIcon = self._curTool and self._curTool.MouseIcon or DEFAULT_MOUSE_ICON
	end
end

return GameInputHandler
