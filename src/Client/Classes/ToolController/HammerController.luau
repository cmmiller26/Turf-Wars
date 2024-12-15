--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- External dependencies
local SharedTypes = require(ReplicatedStorage.SharedTypes)
local GetHammerConfig = require(ReplicatedStorage.Config.GetHammerConfig)

local Utility = ReplicatedStorage.Utility
local CreateMultiIndex = require(Utility.CreateMultiIndex)
local Grid = require(Utility.Grid)

-- Client modules
local Client = ReplicatedFirst.Client
local ClientTypes = require(Client.ClientTypes)

local TurfTracker = require(Client.Services.TurfTracker)

-- Superclass
local ToolController = require(script.Parent)

type HammerController = ClientTypes.ToolController
type HCInternal = HammerController & ToolController.TCProtected & {
	_config: SharedTypes.HammerConfig,

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

--[[
	Attempts to place a block at the given position, if it is within the player's turf and free of obstructions.
	@param placePos Vector3
]]
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

	Remotes.PlaceBlock:InvokeServer(placePos) -- Yield until the server responds

	--[[
		Regardless of whether the server successfully places its own block, the local block should be removed:
		- If the server succeeds, its block will replace the local one, making it unnecessary to keep
		- If the server fails, the block should not exist locally as the placement was invalid
	]]
	block:Destroy()
end

--[=[
	The [HammerConfig] generated from the [Configuration] found in the hammer controller's `Instance`.
	@prop _config HammerConfig
	@private
	@within HammerController
]=]
--[=[
	Whether the player is currently trying to delete blocks.
	@prop _toDelete boolean
	@private
	@within HammerController
]=]
--[=[
	Whether the player is currently trying to place blocks.
	@prop _toPlace boolean
	@private
	@within HammerController
]=]
--[=[
	The position where the player is trying to place a block.
	@prop _placePos Vector3?
	@private
	@within HammerController
]=]
--[=[
	The [BasePart] block the player is currently targeting for deletion.
	@prop _targetBlock BasePart?
	@private
	@within HammerController
]=]
--[=[
	A non-collidable, transparent [BasePart] the `_selectionBox` is adorned to.
	@prop _preview BasePart
	@private
	@within HammerController
]=]
--[=[
	The [SelectionBox] used to visualize the player's target on the grid.
	@prop _selectionBox SelectionBox
	@private
	@within HammerController
]=]

--[=[
	HammerController extends [ToolController] to manage the functionality of a hammer tool within the game. 
	It allows players to place and delete blocks in a grid-based environment while providing real-time visual 
	feedback with a [SelectionBox]. The class integrates tightly with the grid system to ensure accurate placement and 
	deletion of blocks, while also enforcing gameplay rules such as team-based block restrictions and distance limits.

	### Core Features:
	- **Block Placement**: Enables players to place blocks at specified grid-aligned positions, ensuring the placement is 
	  valid and free of obstructions.
	- **Block Deletion**: Allows players to target and delete blocks within their grid-aligned area of interaction.
	- **Real-Time Feedback**: Displays a [SelectionBox] to indicate the player's target position and interaction area.
	- **Grid Integration**: Utilizes the grid system to align placement and deletion actions to the game environment's structure.
	- **Turf Restrictions**: Ensures actions respect team turf boundaries, preventing block placement or deletion outside the player's 
	  allowed area.
	
	### Server Interaction:
	- The `_placeBlock` method fires the `PlaceBlock` [RemoteFunction] to request block placement validation and synchronization.
	- The `_deleteBlock` method fires the `DeleteBlock` [RemoteEvent] to notify the server about a block deletion request.
	- These remotes are handled by the [RoundPlayerHandler], which:
	  - Validates all actions to ensure compliance with gameplay rules, such as grid alignment, turf ownership, and obstruction checks.
	  - Updates the server-side game state and synchronizes changes with other clients.

	### Highlights:
	- Implements the `ActivatePrimary` and `ActivateSecondary` methods to manage block deletion and placement, respectively.
	- Uses [RunService.PreRender] updates to provide responsive and accurate targeting feedback based on the player's camera and position.
	- Leverages dependency injection for integration with the associated [RoundCharacterController].
	- Ensures all client actions are validated server-side to maintain game integrity and fairness.

	### Implementation Notes:
	- The `Blocks` and `Lines` folders in the [Workspace] must be correctly structured for the class to function as expected.

	@class HammerController
	@tag ToolController
]=]
local HammerController = {}

local HCPublicMethods = {}
local HCPrivateMethods = {}

--[=[
	Constructs a new `HammerController` for the given tool [Model] and [RoundCharacterController]
	@param instance Model
	@param roundCharController RoundCharacterController
	@return HammerController
	@within HammerController
]=]
function HammerController.new(
	instance: Model,
	roundCharController: ClientTypes.RoundCharacterController
): HammerController
	local self = setmetatable({} :: HCInternal, {
		__index = CreateMultiIndex(
			HCPublicMethods,
			HCPrivateMethods,
			ToolController.PublicMethods,
			ToolController.PrivateMethods
		),
	})

	self:_init(instance, roundCharController)

	return self
end

--[=[
	Overrides [ToolController:Unequip] to reset the hammer controller's block-related variables.
	@method Unequip
	@private
	@tag Override
	@within HammerController
]=]
function HCPublicMethods.Unequip(self: HCInternal): ()
	ToolController.PublicMethods.Unequip(self)

	self._placePos = nil
	self._targetBlock = nil
	self._selectionBox.Visible = false
end

--[=[
	Overrides [ToolController:ActivatePrimary] to delete the block the player is pointing at.
	If 'toActivate' is true, the hammer will continuously delete blocks until the method is called again with 'toActivate' set to false.
	@method ActivatePrimary
	@param toActivate boolean
	@tag Override
	@within HammerController
]=]
function HCPublicMethods.ActivatePrimary(self: HCInternal, toActivate: boolean): ()
	self:_deleteBlock(toActivate)
end

--[=[
	Overrides [ToolController:ActivateSecondary] to place a block at the position the player is pointing at.
	If 'toActivate' is true, the hammer will continuously place blocks until the method is called again with 'toActivate' set to false.
	@method ActivateSecondary
	@param toActivate boolean
	@tag Override
	@within HammerController
]=]
function HCPublicMethods.ActivateSecondary(self: HCInternal, toActivate: boolean): ()
	self:_placeBlock(toActivate)
end

--[=[
	Overrides [ToolController:_init] to generate the [HammerConfig] and create the `_preview' [BasePart].
	@method _init
	@param instance Model
	@param roundCharController RoundCharacterController
	@private
	@tag Override
	@within HammerController
]=]
function HCPrivateMethods._init(
	self: HCInternal,
	instance: Model,
	roundCharController: ClientTypes.RoundCharacterController
): ()
	self._toolType = "Hammer"

	ToolController.PrivateMethods._init(self, instance, roundCharController)

	local configuration = self.Instance:FindFirstChildOfClass("Configuration")
	if not configuration then
		error("[HammerController:_init]: Configuration not found in Instance", 2)
	end
	self._config = GetHammerConfig(configuration)

	self._toPlace = false
	self._toDelete = false

	local previewPrefab = Effects:FindFirstChild("Preview")
	if not previewPrefab then
		error("[HammerController:_init]: Preview block not found in Effects", 2)
	end
	-- Create a preview block to show what the player is pointing at
	self._preview = self._trove:Clone(previewPrefab)
	self._preview.Parent = self.Instance

	local selectionBox = self._preview:FindFirstChildOfClass("SelectionBox")
	if not selectionBox then
		error("[HammerController:_init]: SelectionBox not found in Preview", 2)
	end
	self._selectionBox = selectionBox

	self._trove:Connect(RunService.PreRender, function()
		self:_onPreRender()
	end)
end

--[=[
	If `toDelete` is true, the hammer will continuously delete any `_targetBlock` until the method is called again with `toDelete` set to false.
	@method _deleteBlock
	@param toDelete boolean
	@private
	@within HammerController
]=]
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

--[=[
	If `toPlace` is true, the hammer will continuously place blocks at the `_placePos` until the method is called again with `toPlace` set to false.
	@method _placeBlock
	@param toPlace boolean
	@private
	@within HammerController
]=]
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

--[=[
	Processes pre-render updates, casting a ray to determine the player's target block and place position according to the grid.
	@method _onPreRender
	@private
	@within HammerController
]=]
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
