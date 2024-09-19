--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)

local GetSlingshotConfig = require(ReplicatedStorage.Config.GetSlingshotConfig)

export type SlingshotController = {
	Instance: Model,

	Equipped: boolean,

	Destroy: (self: SlingshotController) -> (),

	Equip: (self: SlingshotController) -> (),
	Unequip: (self: SlingshotController) -> (),
}
type self = SlingshotController & {
	_trove: Trove.Trove,

	_config: GetSlingshotConfig.Config,

	_animTracks: AnimationTracks,

	_init: (self: self, character: Model) -> (),
}

type AnimationTracks = {
	Idle: AnimationTrack,
	Equip: AnimationTrack,
}

local SlingshotController = {}
SlingshotController.__index = SlingshotController

function SlingshotController.new(instance: Model, character: Model): SlingshotController
	local self = setmetatable({} :: self, SlingshotController)

	self.Instance = instance

	self:_init(character)

	return self
end
function SlingshotController.Destroy(self: self)
	self._trove:Clean()
end

function SlingshotController.Equip(self: self)
	if self.Equipped then
		return
	end
	self.Equipped = true

	self._animTracks.Idle:Play()
	self._animTracks.Equip:Play(0)
end
function SlingshotController.Unequip(self: self)
	if not self.Equipped then
		return
	end
	self.Equipped = false

	for _, animTrack in pairs(self._animTracks) do
		animTrack:Stop()
	end
end

function SlingshotController._init(self: self, character: Model)
	self._trove = Trove.new()

	local configuration = self.Instance:FindFirstChildOfClass("Configuration")
	if not configuration then
		error("Configuration not found in Instance", 2)
	end
	self._config = GetSlingshotConfig(configuration)

	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
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

return SlingshotController
