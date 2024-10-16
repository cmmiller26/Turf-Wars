--!strict

-- Services
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

-- External dependencies
local Packages = ReplicatedStorage.Packages
local Trove = require(Packages.Trove)
local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

-- Client modules
local Types = require(ReplicatedFirst.Client.Types)

type GameInputHandler = Types.GameInputHandler
type GIHInternal = GameInputHandler & {
	_trove: Trove.Trove,

	_controller: Types.GameCharacterController,

	_init: (self: GIHInternal, controller: Types.GameCharacterController) -> (),

	_onPostSimulation: (self: GIHInternal) -> (),
}

-- Constants
local DEFAULT_MOUSE_ICON = "rbxasset://SystemCursors/Arrow"

-- Player-related references
local ChatInputBarConfiguration = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")

--[=[
    A GameInputHandler is responsible for managing user input for a GameCharacterController.
    It handles tool equipping, block placing, and firing projectiles based on user input.
]=]
local GameInputHandler = {}

local GIHPublicMethods = {}
local GIHPrivateMethods = {}

--[=[
	Constructs a GameInputHandler for the given GameCharacterController.
	@param controller The GameCharacterController to handle input for.
	@return GameInputHandler
]=]
function GameInputHandler.new(controller: Types.GameCharacterController): GameInputHandler
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

function GIHPrivateMethods._init(self: GIHInternal, controller: Types.GameCharacterController): ()
	self._trove = Trove.new()

	self._controller = controller

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
			local tool = self._controller:GetCurrentTool()
			if not tool then
				return -- Return if no tool is equipped
			end

			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				-- Start deleting blocks or firing projectiles
				if tool:IsA("HammerController") then
					(tool :: Types.HammerController):DeleteBlock(true)
				elseif tool:IsA("SlingshotController") then
					(tool :: Types.SlingshotController):FireProjectile(true)
				end
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				-- Start placing blocks
				if tool:IsA("HammerController") then
					(tool :: Types.HammerController):PlaceBlock(true)
				end
			end
		end
	end)

	-- Handle input release actions (stop deleting blocks or firing projectiles)
	self._trove:Connect(UserInputService.InputEnded, function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		local tool = self._controller:GetCurrentTool()
		if not tool then
			return -- Return if no tool is equipped
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- Stop deleting blocks or firing projectiles
			if tool:IsA("HammerController") then
				(tool :: Types.HammerController):DeleteBlock(false)
			elseif tool:IsA("SlingshotController") then
				(tool :: Types.SlingshotController):FireProjectile(false)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			-- Stop placing blocks
			if tool:IsA("HammerController") then
				(tool :: Types.HammerController):PlaceBlock(false)
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
		local tool = self._controller:GetCurrentTool()
		UserInputService.MouseIcon = tool and tool.MouseIcon or DEFAULT_MOUSE_ICON
	end
end

return GameInputHandler
