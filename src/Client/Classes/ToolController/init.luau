--!strict

-- Services
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- External dependencies
local Trove = require(ReplicatedStorage.Packages.Trove)
local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

-- Client modules
local Types = require(ReplicatedFirst.Client.Types)

type ToolController = Types.ToolController
type TCInternal = ToolController & TCInherited & {
	_init: (self: TCInternal, character: Model) -> (),
}
export type TCInherited = {
	_className: string,

	_trove: Trove.Trove,

	_animTracks: { [string]: AnimationTrack },
}

--[[
    A ToolController is an abstract class for controlling a tool a CharacterController can use.
    The base class handles the animations for equipping and unequipping the tool.
]]
local ToolController = {}

local TCPublicMethods = {}
local TCPrivateMethods = {}

ToolController.InheritedMethods = TCPublicMethods

--[=[
	Constructs a ToolController for the given tool instance and character.
]=]
function ToolController.new(instance: Model, character: Model): ToolController
	local self = setmetatable({} :: TCInternal, { __index = CreateMultiIndex(TCPublicMethods, TCPrivateMethods) })

	self.Instance = instance

	self.Equipped = false
	self.IsActive = false

	self.MouseIcon = "rbxasset://SystemCursors/Arrow"

	self:_init(character)

	return self
end

--[=[
	Destroys the ToolController, cleaning up any resources, but does not destroy the tool instance.
]=]
function TCPublicMethods.Destroy(self: ToolController): ()
	(self :: TCInternal)._trove:Clean()
end

--[=[
	Returns whether the tool is the given class.
	@param className string -- The class name to check
	@return boolean -- Whether the tool is the given class
]=]
function TCPublicMethods.IsA(self: ToolController, className: string): boolean
	return (self :: TCInternal)._className == className
end

--[=[
	Equips the tool, playing the equip animation.
]=]
function TCPublicMethods.Equip(self: ToolController): ()
	if self.Equipped then
		return
	end
	self.Equipped = true

	local privSelf = self :: TCInternal
	privSelf._animTracks.Idle:Play() -- The idle animation will keep playing after the equip animation
	privSelf._animTracks.Equip:Play(0)
end

--[=[
	Unequips the tool, stopping all animations.
]=]
function TCPublicMethods.Unequip(self: ToolController): ()
	if not self.Equipped then
		return
	end
	self.Equipped = false

	for _, animTrack in pairs((self :: TCInternal)._animTracks) do
		animTrack:Stop()
	end
end

-- Should be overridden by subclasses
function TCPublicMethods.ActivatePrimary(_: ToolController, _: boolean): () end
function TCPublicMethods.ActivateSecondary(_: ToolController, _: boolean): () end

function TCPrivateMethods._init(self: TCInternal, character: Model): ()
	self._trove = Trove.new()

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
