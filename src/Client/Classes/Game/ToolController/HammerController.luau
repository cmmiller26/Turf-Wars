--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetHammerConfig = require(ReplicatedStorage.Config.GetHammerConfig)

local ToolController = require(script.Parent)

export type HammerController = ToolController.ToolController & {
	Build: (self: HammerController, toBuild: boolean) -> (),
	Delete: (self: HammerController, toDelete: boolean) -> (),
}
type self = ToolController.self & HammerController & {
	_config: GetHammerConfig.Config,
}

local HammerController = {}
HammerController.__index = HammerController
setmetatable(HammerController, ToolController)

function HammerController.new(instance: Model, character: Model): HammerController
	local self = setmetatable(ToolController.new(instance, character) :: self, HammerController)

	self.Instance = instance
	self:_init(character)

	return self
end

function HammerController.Destroy(self: self)
	ToolController.Destroy(self)
end

function HammerController.Equip(self: self)
	ToolController.Equip(self)
end

function HammerController.Unequip(self: self)
	ToolController.Unequip(self)
end

function HammerController.Build(self: self, toBuild: boolean) end

function HammerController.Delete(self: self, toDelete: boolean) end

function HammerController._init(self: self, character: Model)
	ToolController._init(self, character)

	local configuration = self.Instance:FindFirstChildOfClass("Configuration")
	if not configuration then
		error("Configuration not found in Instance", 2)
	end
	self._config = GetHammerConfig(configuration)
end

return HammerController
