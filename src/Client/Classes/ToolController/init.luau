--!strict

-- Services
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- External dependencies
local Trove = require(ReplicatedStorage.Packages.Trove)

-- Client modules
local Types = require(ReplicatedFirst.Client.Types)

type ToolController = Types.ToolController
type TCInternal = ToolController & TCProtected
export type TCProtected = {
	_className: string,

	_trove: Trove.Trove,

	_roundCharController: Types.RoundCharacterController,

	_animTracks: { [string]: AnimationTrack },

	_init: (self: TCInternal, instance: Model, roundCharController: Types.RoundCharacterController) -> (),
}

--[=[
	ToolController serves as a base class for managing tools in the game.

	This class provides core functionality for equipping, unequipping, and handling tool-specific animations. 
	It is designed to be extended by subclasses that define specific tool behaviors, such as firing a weapon or interacting with the environment.

	ToolController uses dependency injection to interact with the `RoundCharacterController`, allowing it to integrate seamlessly with the character's state and behaviors.

	Responsibilities:
	- Manage tool states, including whether it is equipped or active.
	- Handle animations for equipping and idle states.
	- Provide abstract methods (`ActivatePrimary` and `ActivateSecondary`) for subclass-specific actions.
	- Coordinate with the `RoundCharacterController` for character-related interactions.

	Notes:
	- This class should not be instantiated directly.
	- Subclasses must override `ActivatePrimary` and `ActivateSecondary` to implement tool-specific functionality.
]=]
local ToolController = {}

local TCPublicMethods = {}
local TCProtectedMethods = {}

ToolController.PublicMethods = TCPublicMethods
ToolController.ProtectedMethods = TCProtectedMethods

--[=[
	Destroys the tool controller, cleaning up all connections and resources used by it.
]=]
function TCPublicMethods.Destroy(self: TCInternal): ()
	self._trove:Clean()
end

--[=[
	Checks if the tool controller is an instance of the given class name.
	@param className -- The class name to check against.
	@return boolean -- True if the instance is of the given class name, false otherwise.
]=]
function TCPublicMethods.IsA(self: TCInternal, className: string): boolean
	return self._className == className
end

--[=[
	Equips the tool, playing the equip animation.
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
    Unequips the tool, stopping all animations.
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
	Activates the primary ability of the tool.

	This method is a placeholder and should be overridden in subclasses to define specific behavior.
	If called without being overridden, it will raise a warning.
]=]
function TCPublicMethods.ActivatePrimary(): ()
	warn("ActivatePrimary is not implemented for this tool")
end

--[=[
	Activates the secondary ability of the tool.

	This method is a placeholder and should be overridden in subclasses to define specific behavior.
	If called without being overridden, it will raise a warning.
]=]
function TCPublicMethods.ActivateSecondary(): ()
	warn("ActivateSecondary is not implemented for this tool")
end

function TCProtectedMethods._init(
	self: TCInternal,
	instance: Model,
	roundCharController: Types.RoundCharacterController
): ()
	self._trove = Trove.new()

	self.Instance = instance

	self.Equipped = false
	self.IsActive = false

	self.MouseIcon = "rbxasset://SystemCursors/Arrow"

	self._roundCharController = roundCharController

	local humanoid = roundCharController.Instance:FindFirstChildOfClass("Humanoid") :: Humanoid
	local animator = humanoid:FindFirstChildOfClass("Animator") :: Animator

	local animations = self.Instance:FindFirstChild("Animations")
	if not animations then
		error("Animations not found in Instance", 2)
	end

	local idleAnim = animations:FindFirstChild("Idle")
	if not (idleAnim and idleAnim:IsA("Animation")) then
		error("Idle Animation not found in Animations", 2)
	end
	local equipAnim = animations:FindFirstChild("Equip")
	if not (equipAnim and equipAnim:IsA("Animation")) then
		error("Equip Animation not found in Animations", 2)
	end
	self._animTracks = {
		Idle = self._trove:Add(animator:LoadAnimation(idleAnim)),
		Equip = self._trove:Add(animator:LoadAnimation(equipAnim)),
	}
end

return ToolController
