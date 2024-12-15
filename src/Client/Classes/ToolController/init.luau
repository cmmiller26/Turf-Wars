--!strict

-- Services
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- External dependencies
local SharedTypes = require(ReplicatedStorage.SharedTypes)
local Trove = require(ReplicatedStorage.Packages.Trove)

-- Client modules
local ClientTypes = require(ReplicatedFirst.Client.ClientTypes)

type ToolController = ClientTypes.ToolController
export type TCProtected = {
	_toolType: SharedTypes.ToolType,

	_trove: Trove.Trove,

	_roundCharController: ClientTypes.RoundCharacterController,

	_animTracks: { [string]: AnimationTrack },

	_init: (self: TCInternal, instance: Model, roundCharController: ClientTypes.RoundCharacterController) -> (),
}
type TCInternal = ToolController & TCProtected

--[=[
	The tool [Model] controlled by the tool controller.
	@prop Instance Model
	@within ToolController
]=]
--[=[
	Whether the tool controller is currently equipped.
	@prop Equipped boolean
	@within ToolController
]=]
--[=[
	Whether the tool controller is currently performing an action.
	@prop IsActive boolean
	@within ToolController
]=]
--[=[
	The asset id of the mouse icon to display while the tool controller is equipped.
	@prop MouseIcon string
	@within ToolController
]=]

--[=[
	The [ToolType] of the tool controller.
	@prop _toolType ToolType
	@private
	@within ToolController
]=]
--[=[
	The [Trove] used to manage the tool controller's connections and resources.
	@prop _trove Trove
	@private
	@within ToolController
]=]
--[=[
	The [RoundCharacterController] instance that the tool controller is attached to.
	@prop _roundCharController RoundCharacterController
	@private
	@within ToolController
]=]
--[=[
	A dictionary of [AnimationTrack] instances used by the tool controller.
	@prop _animTracks { [string]: AnimationTrack }
	@private
	@within ToolController
]=]

--[=[
	ToolController is an abstract base class for managing a tool's behavior while in a round.
	Its provides core functionality for equipping, unequipping, and handling animations, while allowing subclasses to implement specific tool behaviors.
	It leverages dependency injection to interact with the [RoundCharacterController]'s actions and state.
	This class cannot be instantiated directly and is intended to be extended by subclasses.
	@class ToolController
	@client
	@tag Abstract
]=]
local ToolController = {}

local TCPublicMethods = {}
local TCPrivateMethods = {}

ToolController.PublicMethods = TCPublicMethods
ToolController.PrivateMethods = TCPrivateMethods

--[=[
	Cleans up all connections and resources used by the tool controller.
	@method Destroy
	@within ToolController
]=]
function TCPublicMethods.Destroy(self: TCInternal): ()
	self._trove:Clean()
end

--[=[
	Returns whether the tool controller is of the given [ToolType].
	@method IsA
	@param toolType ToolType
	@return boolean
	@within ToolController
]=]
function TCPublicMethods.IsA(self: TCInternal, toolType: SharedTypes.ToolType): boolean
	return self._toolType == toolType
end

--[=[
	Equips the tool controller, playing the equip animation.
	@method Equip
	@within ToolController
]=]
function TCPublicMethods.Equip(self: TCInternal): ()
	if self.Equipped then
		return
	end
	self.Equipped = true

	self._animTracks.Idle:Play() -- The idle animation always plays while no other animations are playing
	self._animTracks.Equip:Play(0)
end

--[=[
	Unequips the tool controller, stopping all animations.
	@method Unequip
	@within ToolController
]=]
function TCPublicMethods.Unequip(self: TCInternal): ()
	if not self.Equipped then
		return
	end
	self.Equipped = false

	for _, animTrack in pairs(self._animTracks) do
		animTrack:Stop()
	end
end

--[=[
	Activates the primary action of the tool controller.
	This method should be overridden by subclasses.
	@method ActivatePrimary
	@param toActivate boolean
	@within ToolController
]=]
function TCPublicMethods.ActivatePrimary(): () end

--[=[
	Activates the secondary action of the tool controller.
	This method should be overridden by subclasses.
	@method ActivateSecondary
	@param toActivate boolean
	@within ToolController
]=]
function TCPublicMethods.ActivateSecondary(): () end

--[=[
	Initializes the tool controller with the given tool [Model] and [RoundCharacterController], loading its [AnimationTrack] instances.
	@method _init
	@param instance Model
	@param roundCharController RoundCharacterController
	@private
	@within ToolController
]=]
function TCPrivateMethods._init(
	self: TCInternal,
	instance: Model,
	roundCharController: ClientTypes.RoundCharacterController
): ()
	self._trove = Trove.new()
	self._trove:Add(function() -- Stop all actions when the tool is destroyed
		self:ActivatePrimary(false)
		self:ActivateSecondary(false)
	end)

	self.Instance = instance

	self.Equipped = false
	self.IsActive = false

	self.MouseIcon = "rbxasset://SystemCursors/Arrow"

	self._roundCharController = roundCharController

	local humanoid = roundCharController.Instance:FindFirstChildOfClass("Humanoid") :: Humanoid
	local animator = humanoid:FindFirstChildOfClass("Animator") :: Animator

	local animations = self.Instance:FindFirstChild("Animations")
	if not animations then
		error("[ToolController:_init]: Animations not found in Instance", 2)
	end

	local idleAnim = animations:FindFirstChild("Idle")
	if not (idleAnim and idleAnim:IsA("Animation")) then
		error("[ToolController:_init]: Idle Animation not found in Animations", 2)
	end
	local equipAnim = animations:FindFirstChild("Equip")
	if not (equipAnim and equipAnim:IsA("Animation")) then
		error("[ToolController:_init]: Equip Animation not found in Animations", 2)
	end
	self._animTracks = {
		Idle = self._trove:Add(animator:LoadAnimation(idleAnim)),
		Equip = self._trove:Add(animator:LoadAnimation(equipAnim)),
	}
end

return ToolController
