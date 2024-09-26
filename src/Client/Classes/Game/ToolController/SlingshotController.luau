--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- External modules
local GetSlingshotConfig = require(ReplicatedStorage.Config.GetSlingshotConfig)

-- Superclass
local ToolController = require(script.Parent)

export type SlingshotController = ToolController.ToolController & {
	Fire: (self: SlingshotController, toFire: boolean) -> (),
}
type self = SlingshotController & ToolController.self & {
	_config: GetSlingshotConfig.Config,
}

--[=[
	SlingshotController is a subclass of ToolController for the slingshot tool.
	It inherits all the basic tool functionality such as equipping and unequipping.
	It adds the ability to fire the slingshot.
]=]
local SlingshotController = {
	Destroy = ToolController.Destroy,
	Equip = ToolController.Equip,
	Unequip = ToolController.Unequip,
}
SlingshotController.__index = SlingshotController

--[=[
	Constructs a new SlingshotController for the given tool instance and character.
	@param instance Model -- The tool model
	@param character Model -- The player's character model
	@return SlingshotController
]=]
function SlingshotController.new(instance: Model, character: Model): SlingshotController
	local self = setmetatable(ToolController.new(instance, character) :: self, SlingshotController)

	self.Instance = instance
	self:_init(character)

	return self
end

--[=[
	Fires the slingshot.
	@param toFire boolean -- Whether to start or stop firing
]=]
function SlingshotController.Fire(self: self, toFire: boolean) end

function SlingshotController._init(self: self, character: Model)
	-- Call the superclass's _init function
	ToolController._init(self, character)

	-- Load the slingshot configuration
	local configuration = self.Instance:FindFirstChildOfClass("Configuration")
	if not configuration then
		error("Configuration not found in Instance", 2)
	end
	self._config = GetSlingshotConfig(configuration)
end

return SlingshotController
