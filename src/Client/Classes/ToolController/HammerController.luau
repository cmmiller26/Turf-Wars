--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- External dependencies
local GetHammerConfig = require(ReplicatedStorage.Config.GetHammerConfig)

local Utility = ReplicatedStorage.Utility
local CreateMultiIndex = require(Utility.CreateMultiIndex)
local Grid = require(Utility.Grid)

-- Client modules
local Client = ReplicatedFirst.Client
local Types = require(Client.Types)

local TurfTracker = require(Client.Services.TurfTracker)

-- Superclass
local ToolController = require(script.Parent)

type HammerController = Types.ToolController
type HCInternal = HammerController & ToolController.TCProtected & {
	_config: GetHammerConfig.Config,

	_toDelete: boolean,
	_toPlace: boolean,

	_placePos: Vector3?,
	_targetBlock: BasePart?,

	_preview: BasePart,
	_selectionBox: SelectionBox,

	_deleteBlock: (self: HCInternal, toDelete: boolean) -> (),
	_placeBlock: (self: HCInternal, toPlace: boolean) -> (),

	_onPreRender: (self: HCInternal) -> (),
}

-- Player-related variables
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Workspace variables
local Blocks = Workspace:WaitForChild("Blocks")
local Lines = Workspace:WaitForChild("Lines")

-- Replicated storage variables
local Effects = ReplicatedStorage.Effects.Hammer
local Remotes = ReplicatedStorage.Remotes.Tool.Hammer

--[=[
	Attempts to place a block at the given position, if it is within the player's turf and free of obstructions.
	@param placePos -- The position to place the block at.
]=]
local function TryPlaceBlock(placePos: Vector3): ()
	if not TurfTracker:IsPositionOnTurf(LocalPlayer.Team, placePos) then
		return
	end

	-- Check if the area is free of blocks before placing
	local overlapSize = Vector3.new(Grid.SIZE, Grid.SIZE, Grid.SIZE) / 2
	if #Workspace:GetPartBoundsInBox(CFrame.new(placePos), overlapSize) > 0 then
		return
	end

	-- Place a block locally and then replicate the action to the server
	local block: BasePart = Effects.Block:Clone()
	block.BrickColor = LocalPlayer.TeamColor
	block.Position = placePos
	block.Parent = Blocks

	Remotes.PlaceBlock:InvokeServer(placePos)

	block:Destroy() -- Destroy the local block after server confirmation
end

--[=[
	HammerController manages the functionality of a hammer tool, allowing players to place and delete blocks within a grid-based game environment.

	This class extends `ToolController` and depends on `RoundCharacterController` for integration with the player’s state during a game round.
	It provides interactive mechanics for block manipulation, real-time visual feedback using a `Preview` block and `SelectionBox`, and server synchronization.

	Responsibilities:
	- Place blocks aligned to a grid and ensure valid placement using collision checks.
	- Delete targeted blocks based on player actions.
	- Provide real-time visual feedback using a dynamic preview block and `SelectionBox`.
	- Synchronize actions with the server via remotes.

	Notes:
	- Requires a valid configuration to define behaviors like `MaxDistance`, `DeleteRPM`, and `PlaceRPM`.
	- Uses a `Grid` module for snapping positions and normals.
	- Designed specifically for grid-based gameplay within a round context.
]=]
local HammerController = {}

local HCPublicMethods = {}
local HCPrivateMethods = {}

--[=[
	Constructs a hammer controller for the given hammer model and round character controller using it.
	@param instance -- The hammer `Model` to control.
	@param roundCharController -- The `RoundCharacterController` using the hammer.
	@return HammerController -- The hammer controller instance.
]=]
function HammerController.new(instance: Model, roundCharController: Types.RoundCharacterController): HammerController
	local self = setmetatable({} :: HCInternal, {
		__index = CreateMultiIndex(
			HCPublicMethods,
			HCPrivateMethods,
			ToolController.PublicMethods,
			ToolController.ProtectedMethods
		),
	})

	self:_init(instance, roundCharController)

	return self
end

--[=[
	Overrides the base method to reset block-related variables.
]=]
-- @Override
function HCPublicMethods.Unequip(self: HCInternal): ()
	ToolController.PublicMethods.Unequip(self)

	self._placePos = nil
	self._targetBlock = nil
	self._selectionBox.Visible = false
end

--[=[
	Deletes the block, if any, that the player's cursor is pointing at.
	@param toActivate -- Whether to start or stop deleting
]=]
-- @Override
function HCPublicMethods.ActivatePrimary(self: HCInternal, toActivate: boolean): ()
	self:_deleteBlock(toActivate)
end

--[=[
	Places a block at where the player's cursor is pointing.
	@param toActivate -- Whether to start or stop placing
]=]
-- @Override
function HCPublicMethods.ActivateSecondary(self: HCInternal, toActivate: boolean): ()
	self:_placeBlock(toActivate)
end

-- @Override
function HCPrivateMethods._init(
	self: HCInternal,
	instance: Model,
	roundCharController: Types.RoundCharacterController
): ()
	self._className = "HammerController"

	ToolController.ProtectedMethods._init(self, instance, roundCharController)

	local configuration = self.Instance:FindFirstChildOfClass("Configuration")
	if not configuration then
		error("[HammerController._init]: Configuration not found in Instance", 2)
	end
	self._config = GetHammerConfig(configuration)

	self._toPlace = false
	self._toDelete = false

	local previewPrefab = Effects:FindFirstChild("Preview")
	if not previewPrefab then
		error("[HammerController._init]: Preview block not found in Effects", 2)
	end
	-- Create a preview block to show what the player is pointing at
	self._preview = self._trove:Clone(previewPrefab)
	self._preview.Parent = self.Instance

	local selectionBox = self._preview:FindFirstChildOfClass("SelectionBox")
	if not selectionBox then
		error("[HammerController._init]: SelectionBox not found in Preview", 2)
	end
	self._selectionBox = selectionBox

	self._trove:Connect(RunService.PreRender, function()
		self:_onPreRender()
	end)
end

function HCPrivateMethods._deleteBlock(self: HCInternal, toDelete: boolean): ()
	self._toDelete = toDelete
	if not self.Equipped or self.IsActive or not self._toDelete then
		return
	end

	self.IsActive = true

	-- Loop to continuously delete blocks while the button is held
	while self.Equipped and self._toDelete do
		if self._targetBlock then
			Remotes.DeleteBlock:FireServer(self._targetBlock)
		end
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
	if not self.Equipped or self.IsActive or not self._toPlace then
		return
	end

	self.IsActive = true

	-- Loop to continuously place blocks while the button is held
	while self.Equipped and self._toPlace do
		if self._placePos then
			TryPlaceBlock(self._placePos)
		end

		task.wait(60 / self._config.PlaceRPM)
	end

	self.IsActive = false

	-- If the player is trying to delete, start deleting again
	if self._toDelete then
		self:_deleteBlock(true)
	end
end

function HCPrivateMethods._onPreRender(self: HCInternal): ()
	if not self.Equipped then
		return
	end

	-- Perform a raycast from the camera to determine what the player is targeting
	local origin = Camera.CFrame.Position
	local direction = Camera.CFrame.LookVector * self._config.MaxDistance

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { Blocks, Lines, Workspace:FindFirstChild("Map") }
	raycastParams.FilterType = Enum.RaycastFilterType.Include

	local raycastResult = Workspace:Raycast(origin, direction, raycastParams)
	if not raycastResult then
		self._placePos = nil
		self._targetBlock = nil
		self._selectionBox.Visible = false
		return
	end

	local target = raycastResult.Instance
	-- Store the target block, if any, for deletion
	if target:IsA("BasePart") and target.Parent == Blocks and target.BrickColor == LocalPlayer.TeamColor then
		self._targetBlock = target
	else
		self._targetBlock = nil
	end

	-- Calculate place position relative to the normal of the raycast
	local normal = Grid.SnapNormal(raycastResult.Normal)
	local position = Grid.SnapPosition(raycastResult.Position + normal)
	self._placePos = position
	self._preview.Position = position - normal * Grid.SIZE -- Place the preview inside the raycast target

	self._selectionBox.Visible = true
end

return HammerController
