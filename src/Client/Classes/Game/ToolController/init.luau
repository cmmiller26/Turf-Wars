--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- External modules
local Trove = require(ReplicatedStorage.Packages.Trove)

export type ToolController = {
	Instance: Model,
	Equipped: boolean,

	Destroy: (self: ToolController) -> (),

	Equip: (self: ToolController) -> (),
	Unequip: (self: ToolController) -> (),
}
export type self = ToolController & {
	_trove: Trove.Trove,

	_animTracks: { [string]: AnimationTrack },

	_init: (self: self, character: Model) -> (),
}

--[[
    A ToolController is a superclass for all the tools a GameCharacterController uses.
    It handles the animations for equipping and unequipping the tool.
]]
local ToolController = {}
ToolController.__index = ToolController

--[[
    Constructs a new ToolController for the given tool and character instances.
    @param instance Model -- The tool model
    @param character Model -- The player's character model
    @return ToolController
]]
function ToolController.new(instance: Model, character: Model): ToolController
	local self = setmetatable({} :: self, ToolController)

	self.Instance = instance
	self:_init(character)

	return self
end

--[[
    Destroys the ToolController cleaning up any resources, but does not destroy the tool instance.
]]
function ToolController.Destroy(self: self)
	self._trove:Clean()
end

--[[
    Equips the tool, playing the equip and idle animations.
]]
function ToolController.Equip(self: self)
	if self.Equipped then
		return
	end
	self.Equipped = true

	self._animTracks.Idle:Play()
	self._animTracks.Equip:Play(0)
end

--[[
    Unequips the tool, stopping all animations.
]]
function ToolController.Unequip(self: self)
	if not self.Equipped then
		return
	end
	self.Equipped = false

	for _, animTrack in pairs(self._animTracks) do
		animTrack:Stop()
	end
end

function ToolController._init(self: self, character: Model)
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
