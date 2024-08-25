--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)

type AnimTracks = {
	Idle: AnimationTrack,
	Equip: AnimationTrack,
}

export type HammerController = {
	Instance: Model,
	Destroy: (self: HammerController) -> (),

	Equip: (self: HammerController) -> (),
	Unequip: (self: HammerController) -> (),
}
type self = HammerController & {
	_trove: Trove.Trove,

	_equipped: boolean,

	_animTracks: AnimTracks,

	_init: (self: self, character: Model) -> (),
}

local HammerController = {}
HammerController.__index = HammerController

function HammerController.new(instance: Model, character: Model): HammerController
	assert(
		typeof(instance) == "Instance" and instance:IsA("Model"),
		"HammerController.new(): Expected Model for argument #1, got " .. typeof(instance)
	)
	assert(
		typeof(character) == "Instance" and character:IsA("Model"),
		"HammerController.new(): Expected Model for argument #2, got " .. typeof(character)
	)

	local self = setmetatable({} :: self, HammerController)

	self.Instance = instance
	self:_init(character)

	return self
end
function HammerController.Destroy(self: self)
	self._trove:Clean()
end

function HammerController.Equip(self: self)
	if self._equipped then
		return
	end
	self._equipped = true

	self._animTracks.Idle:Play()
	self._animTracks.Equip:Play(0)
end
function HammerController.Unequip(self: self)
	if not self._equipped then
		return
	end
	self._equipped = false

	for _, animTrack in pairs(self._animTracks) do
		animTrack:Stop()
	end
end

function HammerController._init(self: self, character: Model)
	self._trove = Trove.new()

	self._equipped = false

	do
		local animator = (character:FindFirstChild("Humanoid") :: Instance):FindFirstChild("Animator") :: Animator

		local animations = self.Instance:FindFirstChild("Animations")
		assert(
			typeof(animations) == "Instance" and animations:IsA("Folder"),
			"HammerController._init(): Expected a 'Animations' Folder in self.Instance, got " .. typeof(animations)
		)

		local idleAnim = animations:FindFirstChild("Idle")
		assert(
			typeof(idleAnim) == "Instance" and idleAnim:IsA("Animation"),
			"HammerController._init(): Expected an 'Idle' Animation in self.Instance.Animations, got "
				.. typeof(idleAnim)
		)
		local equipAnim = animations:FindFirstChild("Equip")
		assert(
			typeof(equipAnim) == "Instance" and equipAnim:IsA("Animation"),
			"HammerController._init(): Expected an 'Equip' Animation in self.Instance.Animations, got "
				.. typeof(equipAnim)
		)

		self._animTracks = {
			Idle = animator:LoadAnimation(idleAnim),
			Equip = animator:LoadAnimation(equipAnim),
		}
	end
end

return HammerController
