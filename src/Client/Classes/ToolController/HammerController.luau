--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- External dependencies
local Grid = require(ReplicatedStorage.Grid)
local GetHammerConfig = require(ReplicatedStorage.Config.GetHammerConfig)
local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

-- Superclass
local ToolController = require(script.Parent)

export type HammerController = ToolController.ToolController & {
	PlaceBlock: (self: HammerController, toPlace: boolean) -> (),
	DeleteBlock: (self: HammerController, toDelete: boolean) -> (),
}
type HCInternal = HammerController & ToolController.TCInherited & {
	_config: GetHammerConfig.Config,

	_toPlace: boolean,
	_toDelete: boolean,

	_placePos: Vector3?,
	_targetBlock: BasePart?,
	_preview: BasePart,

	_init: (self: HCInternal) -> (),

	_onPreRender: (self: HCInternal) -> (),
}

-- Workspace references
local Camera = Workspace.CurrentCamera
local Baseplate = Workspace:WaitForChild("Baseplate")
local Blocks = Workspace:WaitForChild("Blocks")

-- ReplicatedStorage references
local Effects = ReplicatedStorage.Effects.Hammer
local Remotes = ReplicatedStorage.Remotes.Hammer

--[=[
	A HammerController is a subclass of ToolController for using the hammer tool.
	It inherits all the basic tool functionality such as equipping and unequipping.
	It adds the ability to place and delete blocks.
]=]
local HammerController = {}

local HCPublicMethods = {}
local HCPrivateMethods = {}

--[=[
	Constructs a HammerController for the given hammer instance and character.
	@param instance The hammer model.
	@param character The player's character model.
	@return HammerController
]=]
function HammerController.new(instance: Model, character: Model): HammerController
	local self = setmetatable(
		ToolController.new(instance, character) :: HCInternal,
		{ __index = CreateMultiIndex(ToolController.InheritedMethods, HCPublicMethods, HCPrivateMethods) }
	)

	self:_init()

	return self
end

--[=[
	Places a block where the player's cursor is pointing.
	@param toPlace boolean -- Whether to start or stop placing
]=]
function HCPublicMethods.PlaceBlock(self: HammerController, toPlace: boolean): ()
	local internal = self :: HCInternal

	internal._toPlace = toPlace
	-- Ensure the hammer is equipped, set to place, and not currently active
	if not self.Equipped or self.IsActive or not internal._toPlace then
		return
	end

	self.IsActive = true

	-- Loop to continuously place blocks while the button is held
	while self.Equipped and internal._toPlace do
		if internal._placePos then
			-- Check if the area is free of blocks before placing
			local overlapSize = Vector3.new(Grid.SIZE, Grid.SIZE, Grid.SIZE) / 2
			if #Workspace:GetPartBoundsInBox(CFrame.new(internal._placePos), overlapSize) == 0 then
				-- Send block placement request to the server
				Remotes.PlaceBlock:FireServer(internal._placePos)
			end
		end
		-- Control place rate using the configured RPM
		task.wait(60 / internal._config.PlaceRPM)
	end

	self.IsActive = false
end

--[=[
	Deletes the block, if any, where the player's cursor is pointing.
	@param toDelete boolean -- Whether to start or stop deleting
]=]
function HCPublicMethods.DeleteBlock(self: HammerController, toDelete: boolean): ()
	local internal = self :: HCInternal

	internal._toDelete = toDelete
	-- Ensure the hammer is equipped, set to delete, and not currently active
	if not self.Equipped or self.IsActive or not internal._toDelete then
		return
	end

	self.IsActive = true

	-- Loop to continuously delete blocks while the button is held
	while self.Equipped and internal._toDelete do
		if internal._targetBlock then
			-- Send block deletion request to the server
			Remotes.DeleteBlock:FireServer(internal._targetBlock)
		end
		-- Control deletion rate using the configured RPM
		task.wait(60 / internal._config.DeleteRPM)
	end

	self.IsActive = false
end

function HCPrivateMethods._init(self: HCInternal): ()
	self._classType = "HammerController"

	-- Load the hammer configuration
	local configuration = self.Instance:FindFirstChildOfClass("Configuration")
	if not configuration then
		error("Configuration not found in Instance", 2)
	end
	self._config = GetHammerConfig(configuration)

	self._toPlace = false
	self._toDelete = false

	-- Create a preview to show which block the player is targeting
	self._preview = self._trove:Clone(Effects.Preview)

	-- Connect user input for placing and deleting blocks
	self._trove:Connect(UserInputService.InputBegan, function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- Start deleting blocks when left mouse button is pressed
			self:DeleteBlock(true)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			-- Start placing blocks when right mouse button is pressed
			self:PlaceBlock(true)
		end
	end)
	self._trove:Connect(UserInputService.InputEnded, function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- Stop deleting blocks when left mouse button is released
			self:DeleteBlock(false)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			-- Stop placing blocks when right mouse button is released
			self:PlaceBlock(false)
		end
	end)

	-- Connect to the PreRender event to update block preview
	self._trove:Connect(RunService.PreRender, function()
		self:_onPreRender()
	end)
end

function HCPrivateMethods._onPreRender(self: HCInternal): ()
	-- Clear the preview every frame
	self._placePos = nil
	self._targetBlock = nil
	self._preview.Parent = nil

	-- Ensure the hammer is equipped
	if not self.Equipped then
		return
	end

	-- Perform a raycast from the camera to determine what the player is targeting
	local origin = Camera.CFrame.Position
	local direction = Camera.CFrame.LookVector * self._config.MaxDistance

	local raycastParams = RaycastParams.new()
	-- Filter to only target the baseplate and blocks
	raycastParams.FilterDescendantsInstances = { Baseplate, Blocks }
	raycastParams.FilterType = Enum.RaycastFilterType.Include

	local raycastResult = Workspace:Raycast(origin, direction, raycastParams)
	if not raycastResult then
		return -- The player is not targeting anything
	end

	local target = raycastResult.Instance
	if target == Baseplate then
		-- Snap the place position to the grid on the baseplate
		local position = Grid.SnapPosition(raycastResult.Position)
		self._placePos = position
		-- Adjust the preview position to display inside the baseplate
		self._preview.Position = position + Vector3.new(0, -Grid.SIZE, 0)
	elseif target.Parent == Blocks then
		-- Calculate place position relative to the target block
		self._placePos = target.Position + raycastResult.Normal * Grid.SIZE
		self._targetBlock = target
		-- Place the preview at the target block's position
		self._preview.Position = target.Position
	else
		return
	end

	-- Show the preview in the workspace
	self._preview.Parent = Workspace
end

return HammerController
