--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- External dependencies
local GetSlingshotConfig = require(ReplicatedStorage.Config.GetSlingshotConfig)
local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

-- Superclass
local ToolController = require(script.Parent)

export type SlingshotController = ToolController.ToolController & {
	Fire: (self: SlingshotController, toFire: boolean) -> (),
}
type SCInternal = SlingshotController & ToolController.TCInherited & {
	_config: GetSlingshotConfig.Config,

	_init: (self: SCInternal) -> (),
}

--[=[
	A SlingshotController is a subclass of ToolController for using the slingshot tool.
	It inherits all the basic tool functionality such as equipping and unequipping.
	It adds the ability to fire projectiles.
]=]
local SlingshotController = {}

local SCPublicMethods = {}
local SCPrivateMethods = {}

SlingshotController.InheritedMethods = nil

--[=[
	Constructs a SlingshotController for the given slingshot instance and character.
	@param instance The slingshot model.
	@param character The player's character model.
	@return SlingshotController
]=]
function SlingshotController.new(instance: Model, character: Model): SlingshotController
	local self = setmetatable(
		ToolController.new(instance, character) :: SCInternal,
		{ __index = CreateMultiIndex(ToolController.InheritedMethods, SCPublicMethods, SCPrivateMethods) }
	)

	self:_init()

	return self
end

--[=[
	Fires a projectile from the slingshot.
	@param toFire boolean -- Whether to start or stop firing
]=]
function SCPublicMethods.Fire(self: SlingshotController, toFire: boolean): () end

function SCPrivateMethods._init(self: SCInternal): ()
	-- Load the Slingshot configuration
	local configuration = self.Instance:FindFirstChildOfClass("Configuration")
	if not configuration then
		error("Configuration not found in Instance", 2)
	end
	self._config = GetSlingshotConfig(configuration)
end

return SlingshotController
