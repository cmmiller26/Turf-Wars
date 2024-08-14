--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)

export type HammerController = {
	Instance: Model,
	Destroy: (self: self) -> (),

	Equip: (self: self) -> (),
	Unequip: (self: self) -> (),
}
type self = HammerController & {
	_trove: Trove.Trove,

	_equipped: boolean,

	_init: (self: self) -> (),
}

local HammerController = {}
HammerController.__index = HammerController

function HammerController.new(instance: Model): HammerController
	assert(
		typeof(instance) == "Instance" and instance:IsA("Model"),
		"HammerController.new() expected Model for argument #1, got " .. typeof(instance)
	)

	local self = setmetatable({} :: self, HammerController)

	self.Instance = instance
	self:_init()

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
end
function HammerController.Unequip(self: self)
	if not self._equipped then
		return
	end
	self._equipped = false
end

function HammerController._init(self: self)
	self._trove = Trove.new()

	self._equipped = false
end

return HammerController
