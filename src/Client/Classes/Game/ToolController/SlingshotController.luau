--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetSlingshotConfig = require(ReplicatedStorage.Config.GetSlingshotConfig)

local ToolController = require(script.Parent)

export type SlingshotController = ToolController.ToolController & {
	Fire: (self: SlingshotController, toFire: boolean) -> (),
}
type self = ToolController.self & SlingshotController & {
	_config: GetSlingshotConfig.Config,
}

local SlingshotController = {}
SlingshotController.__index = SlingshotController
setmetatable(SlingshotController, ToolController)

function SlingshotController.new(instance: Model, character: Model): SlingshotController
	local self = setmetatable(ToolController.new(instance, character) :: self, SlingshotController)

	self.Instance = instance
	self:_init(character)

	return self
end

function SlingshotController.Destroy(self: self)
	ToolController.Destroy(self)
end

function SlingshotController.Equip(self: self)
	ToolController.Equip(self)
end

function SlingshotController.Unequip(self: self)
	ToolController.Unequip(self)
end

function SlingshotController.Fire(self: self, toFire: boolean) end

function SlingshotController._init(self: self, character: Model)
	ToolController._init(self, character)

	local configuration = self.Instance:FindFirstChildOfClass("Configuration")
	if not configuration then
		error("Configuration not found in Instance", 2)
	end
	self._config = GetSlingshotConfig(configuration)
end

return SlingshotController
