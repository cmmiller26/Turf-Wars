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
    The `ToolController` module serves as a base class for managing tools within the game.
	It provides core functionality for equipping, unequipping, and handling animations, while allowing subclasses to implement specific tool behaviors.

    This class is designed to integrate seamlessly with the `RoundCharacterController` and leverages dependency injection to interact with the character's state and actions.

    **Responsibilities:**
    - **Tool State Management:** Handles tool states such as equipping, unequipping, and activation.
    - **Animation Handling:** Manages tool-related animations, including idle and equip animations.
    - **Behavior Extension:** Provides abstract methods (`ActivatePrimary` and `ActivateSecondary`) for subclasses to define custom behaviors.
    - **Character Integration:** Coordinates with the `RoundCharacterController` for smooth gameplay interactions.

    **Key Features:**
    - **Reusable Architecture:** Acts as a base class that can be extended for specialized tool behaviors (e.g., weapons or utility tools).
    - **Dynamic Animation System:** Loads and plays animations dynamically from the tool’s instance.
    - **Safe Resource Management:** Utilizes `Trove` to ensure proper cleanup of animations and connections.
    - **Flexible Input Handling:** Supports primary and secondary actions, which can be overridden by subclasses.

    **Public Methods:**
    - `Destroy(self: TCInternal): ()`: Cleans up all resources and connections used by the tool controller.
    - `IsA(self: TCInternal, className: string): boolean`: Checks if the tool controller is an instance of a specific class.
    - `Equip(self: TCInternal): ()`: Equips the tool and plays the equip animation.
    - `Unequip(self: TCInternal): ()`: Unequips the tool and stops all animations.
    - `ActivatePrimary(self: TCInternal): ()`: Placeholder for the primary action, intended to be overridden.
    - `ActivateSecondary(self: TCInternal): ()`: Placeholder for the secondary action, intended to be overridden.

    **Notes:**
    - This class should not be instantiated directly. Subclasses must define their specific behaviors by overriding `ActivatePrimary` and `ActivateSecondary`.
    - Assumes that the tool model contains an `Animations` folder with `Idle` and `Equip` animations.
    - Properly stops ongoing animations and actions when destroyed.
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
]=]
function TCPublicMethods.ActivatePrimary(): () end

--[=[
	Activates the secondary ability of the tool.

	This method is a placeholder and should be overridden in subclasses to define specific behavior.
]=]
function TCPublicMethods.ActivateSecondary(): () end

function TCProtectedMethods._init(
	self: TCInternal,
	instance: Model,
	roundCharController: Types.RoundCharacterController
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
		error("[ToolController._init]: Animations not found in Instance", 2)
	end

	local idleAnim = animations:FindFirstChild("Idle")
	if not (idleAnim and idleAnim:IsA("Animation")) then
		error("[ToolController._init]: Idle Animation not found in Animations", 2)
	end
	local equipAnim = animations:FindFirstChild("Equip")
	if not (equipAnim and equipAnim:IsA("Animation")) then
		error("[ToolController._init]: Equip Animation not found in Animations", 2)
	end
	self._animTracks = {
		Idle = self._trove:Add(animator:LoadAnimation(idleAnim)),
		Equip = self._trove:Add(animator:LoadAnimation(equipAnim)),
	}
end

return ToolController
