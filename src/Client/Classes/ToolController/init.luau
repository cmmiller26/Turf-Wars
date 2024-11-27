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

	_animTracks: { [string]: AnimationTrack },

	_init: (self: TCInternal, instance: Model, character: Model) -> (),
}

--[[
    A ToolController is an abstract class for controlling a tool a CharacterController can use.
    It handles the animations for equipping and unequipping the tool.
]]
local ToolController = {}

local TCPublicMethods = {}
local TCProtectedMethods = {}

ToolController.PublicMethods = TCPublicMethods
ToolController.ProtectedMethods = TCProtectedMethods

--[=[
    Destroys the ToolController, cleaning up any resources, but does not destroy the tool instance.
]=]
function TCPublicMethods.Destroy(self: TCInternal): ()
	self._trove:Clean()
end

--[=[
    Returns whether the ToolController is an instance of the given class name.
    @param className string -- The class name to check.
    @return boolean -- Whether the ToolController is an instance of the given class name.
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

	self._animTracks.Idle:Play() -- The idle animation will keep playing after the equip animation
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

-- Should be overridden by subclasses
function TCPublicMethods.ActivatePrimary(): () end
function TCPublicMethods.ActivateSecondary(): () end

function TCProtectedMethods._init(self: TCInternal, instance: Model, character: Model): ()
	self._trove = Trove.new()

	self.Instance = instance

	self.Equipped = false
	self.IsActive = false

	self.MouseIcon = "rbxasset://SystemCursors/Arrow"

	-- Assume the humanoid and animator exist
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	local animator = humanoid:FindFirstChildOfClass("Animator") :: Animator

	-- Check for the animations folder and the animations
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

	-- Create the animation tracks
	self._animTracks = {
		Idle = self._trove:Add(animator:LoadAnimation(idleAnim)),
		Equip = self._trove:Add(animator:LoadAnimation(equipAnim)),
	}
end

return ToolController
