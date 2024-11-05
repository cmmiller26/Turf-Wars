--!strict

-- Services
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- External dependencies
local Grid = require(ReplicatedStorage.Grid)
local GetHammerConfig = require(ReplicatedStorage.Config.GetHammerConfig)
local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

-- Client modules
local Types = require(ReplicatedFirst.Client.Types)

-- Superclass
local ToolController = require(script.Parent)

type HammerController = Types.ToolController
type HCInternal = HammerController & ToolController.TCInherited & {
	_config: GetHammerConfig.Config,

	_toDelete: boolean,
	_toPlace: boolean,

	_placePos: Vector3?,
	_targetBlock: BasePart?,
	_preview: BasePart,

	_init: (self: HCInternal) -> (),

	_deleteBlock: (self: HCInternal, toDelete: boolean) -> (),
	_placeBlock: (self: HCInternal, toPlace: boolean) -> (),

	_onPreRender: (self: HCInternal) -> (),
}

-- Workspace references
local Camera = Workspace.CurrentCamera
local Baseplate = Workspace:WaitForChild("Baseplate")
local Blocks = Workspace:WaitForChild("Blocks")

-- ReplicatedStorage references
local Effects = ReplicatedStorage.Effects.Hammer
local Remotes = ReplicatedStorage.Remotes.Tool.Hammer

--[=[
	A HammerController inherits ToolController to use the hammer tool.
	It adds the ability to place and delete blocks.
]=]
local HammerController = {}

local HCPublicMethods = {}
local HCPrivateMethods = {}

--[=[
	Constructs a HammerController for the given hammer instance and character.
	@param instance Model -- The hammer model.
	@param character Model -- The player's character model.
	@return HammerController
]=]
function HammerController.new(instance: Model, character: Model): HammerController
	local self = setmetatable(
		ToolController.new(instance, character) :: HCInternal,
		{ __index = CreateMultiIndex(HCPublicMethods, ToolController.InheritedMethods, HCPrivateMethods) }
	)

	self:_init()

	return self
end

--[=[
	Deletes the block, if any, where the player's cursor is pointing.
	@param toActivate boolean -- Whether to start or stop deleting
]=]
-- @Override
function HCPublicMethods.ActivatePrimary(self: HammerController, toActivate: boolean): ()
	(self :: HCInternal):_deleteBlock(toActivate)
end

--[=[
	Places a block where the player's cursor is pointing.
	@param toActivate boolean -- Whether to start or stop placing
]=]
-- @Override
function HCPublicMethods.ActivateSecondary(self: HammerController, toActivate: boolean): ()
	(self :: HCInternal):_placeBlock(toActivate)
end

function HCPrivateMethods._init(self: HCInternal): ()
	self._className = "HammerController"

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

	-- Connect to the PreRender event to update block preview
	self._trove:Connect(RunService.PreRender, function()
		self:_onPreRender()
	end)
end

function HCPrivateMethods._deleteBlock(self: HCInternal, toDelete: boolean): ()
	self._toDelete = toDelete
	-- Ensure the hammer is equipped, set to delete, and not currently active
	if not self.Equipped or self.IsActive or not self._toDelete then
		return
	end

	self.IsActive = true

	-- Loop to continuously delete blocks while the button is held
	while self.Equipped and self._toDelete do
		if self._targetBlock then
			-- Send block deletion request to the server
			Remotes.DeleteBlock:FireServer(self._targetBlock)
		end
		-- Control deletion rate using the configured RPM
		task.wait(60 / self._config.DeleteRPM)
	end

	self.IsActive = false

	-- If the player is trying to place, start placing again
	if self._toPlace then
		self:_placeBlock(true)
	end
end

function HCPrivateMethods._placeBlock(self: HCInternal, toPlace: boolean): ()
	self._toPlace = toPlace
	-- Ensure the hammer is equipped, set to place, and not currently active
	if not self.Equipped or self.IsActive or not self._toPlace then
		return
	end

	self.IsActive = true

	-- Loop to continuously place blocks while the button is held
	while self.Equipped and self._toPlace do
		if self._placePos then
			-- Check if the area is free of blocks before placing
			local overlapSize = Vector3.new(Grid.SIZE, Grid.SIZE, Grid.SIZE) / 2
			if #Workspace:GetPartBoundsInBox(CFrame.new(self._placePos), overlapSize) == 0 then
				-- Send block placement request to the server
				Remotes.PlaceBlock:FireServer(self._placePos)
			end
		end
		-- Control place rate using the configured RPM
		task.wait(60 / self._config.PlaceRPM)
	end

	self.IsActive = false

	-- If the player is trying to delete, start deleting again
	if self._toDelete then
		self:_deleteBlock(true)
	end
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
