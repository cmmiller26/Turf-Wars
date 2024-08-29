--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)

local LoadHammerConfig = require(ReplicatedStorage.Config.LoadHammerConfig)

export type HammerController = {
	Instance: Model,

	Equipped: boolean,

	Destroy: (self: HammerController) -> (),

	Equip: (self: HammerController) -> (),
	Unequip: (self: HammerController) -> (),
}
type self = HammerController & {
	_trove: Trove.Trove,

	_config: LoadHammerConfig.Config,

	_animTracks: AnimationTracks,

	_init: (self: self, character: Model) -> (),
}

type AnimationTracks = {
	Idle: AnimationTrack,
	Equip: AnimationTrack,
}

local HammerController = {}
HammerController.__index = HammerController

function HammerController.new(instance: Model, character: Model): HammerController
	local self = setmetatable({} :: self, HammerController)

	self.Instance = instance

	self.Equipped = false

	self:_init(character)

	return self
end
function HammerController.Destroy(self: self)
	self._trove:Clean()
end

function HammerController.Equip(self: self)
	if self.Equipped then
		return
	end
	self.Equipped = true

	self._animTracks.Idle:Play()
	self._animTracks.Equip:Play(0)
end
function HammerController.Unequip(self: self)
	if not self.Equipped then
		return
	end
	self.Equipped = false

	for _, animTrack in pairs(self._animTracks) do
		animTrack:Stop()
	end
end

function HammerController._init(self: self, character: Model)
	self._trove = Trove.new()

	local configuration = self.Instance:FindFirstChildOfClass("Configuration")
	if not configuration then
		error("Configuration not found in hammer", 2)
	end
	self._config = LoadHammerConfig(configuration)

	do
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
		local animator = humanoid:FindFirstChildOfClass("Animator") :: Animator

		local animations = self.Instance:FindFirstChild("Animations")
		if not (animations and animations:IsA("Folder")) then
			error("'Animations' Folder not found in hammer", 2)
		end

		local idleAnim = animations:FindFirstChild("Idle")
		if not (idleAnim and idleAnim:IsA("Animation")) then
			error("'Idle' Animation not found in hammer animations", 2)
		end
		local equipAnim = animations:FindFirstChild("Equip")
		if not (equipAnim and equipAnim:IsA("Animation")) then
			error("'Equip' Animation not found in hammer animations", 2)
		end

		self._animTracks = {
			Idle = self._trove:Add(animator:LoadAnimation(idleAnim)),
			Equip = self._trove:Add(animator:LoadAnimation(equipAnim)),
		}
	end
end

return HammerController
