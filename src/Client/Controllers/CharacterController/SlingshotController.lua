--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)

export type SlingshotController = {
	Instance: Model,
	Destroy: (self: self) -> (),

	Equip: (self: self) -> (),
	Unequip: (self: self) -> (),
}
type self = SlingshotController & {
	_trove: Trove.Trove,

	_equipped: boolean,

	_init: (self: self) -> (),
}

local SlingshotController = {}
SlingshotController.__index = SlingshotController

function SlingshotController.new(instance: Model): SlingshotController
	assert(
		typeof(instance) == "Instance" and instance:IsA("Model"),
		"SlingshotController.new() expected Model for argument #1, got " .. typeof(instance)
	)

	local self = setmetatable({} :: self, SlingshotController)

	self.Instance = instance
	self:_init()

	return self
end
function SlingshotController.Destroy(self: self)
	self._trove:Clean()
end

function SlingshotController.Equip(self: self)
	if self._equipped then
		return
	end
	self._equipped = true
end
function SlingshotController.Unequip(self: self)
	if not self._equipped then
		return
	end
	self._equipped = false
end

function SlingshotController._init(self: self)
	self._trove = Trove.new()

	self._equipped = false
end

return SlingshotController
