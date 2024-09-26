--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- External modules
local GetHammerConfig = require(ReplicatedStorage.Config.GetHammerConfig)

-- Superclass
local ToolController = require(script.Parent)

export type HammerController = ToolController.ToolController & {
	Build: (self: HammerController, toBuild: boolean) -> (),
	Delete: (self: HammerController, toDelete: boolean) -> (),
}
type self = HammerController & ToolController.self & {
	_config: GetHammerConfig.Config,
}

--[=[
	HammerController is a subclass of ToolController for the hammer tool.
	It inherits all the basic tool functionality such as equipping and unequipping.
	It adds the ability to build and delete blocks.
]=]
local HammerController = {
	Destroy = ToolController.Destroy,
	Equip = ToolController.Equip,
	Unequip = ToolController.Unequip,
}
HammerController.__index = HammerController

--[=[
	Constructs a new HammerController for the given tool instance and character.
	@param instance Model -- The tool model
	@param character Model -- The player's character model
	@return HammerController
]=]
function HammerController.new(instance: Model, character: Model): HammerController
	local self = setmetatable(ToolController.new(instance, character) :: self, HammerController)

	self.Instance = instance
	self:_init(character)

	return self
end

--[=[
	Builds a block.
	@param toBuild boolean -- Whether to start or stop building
]=]
function HammerController.Build(self: self, toBuild: boolean) end

--[=[
	Deletes a block.
	@param toDelete boolean -- Whether to start or stop deleting
]=]
function HammerController.Delete(self: self, toDelete: boolean) end

function HammerController._init(self: self, character: Model)
	-- Call the superclass's _init function
	ToolController._init(self, character)

	-- Load the hammer configuration
	local configuration = self.Instance:FindFirstChildOfClass("Configuration")
	if not configuration then
		error("Configuration not found in Instance", 2)
	end
	self._config = GetHammerConfig(configuration)
end

return HammerController
