--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- External dependencies
local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)
local GetHammerConfig = require(ReplicatedStorage.Config.GetHammerConfig)

-- Superclass
local ToolController = require(script.Parent)

export type HammerController = ToolController.ToolController & {
	PlaceBlock: (self: HammerController, toPlace: boolean) -> (),
	DeleteBlock: (self: HammerController, toDelete: boolean) -> (),
}
type HCInternal = HammerController & ToolController.TCInherited & {
	_config: GetHammerConfig.Config,

	_init: (self: HCInternal) -> (),
}

--[=[
	A HammerController is a subclass of ToolController for using the hammer tool.
	It inherits all the basic tool functionality such as equipping and unequipping.
	It adds the ability to build and delete blocks.
]=]
local HammerController = {}

local HCPublicMethods = {}
local HCPrivateMethods = {}

HammerController.InheritedMethods = nil

--[=[
	Constructs a HammerController for the given hammer instance and character.
	@param instance The hammer model.
	@param character The player's character model.
	@return HammerController
]=]
function HammerController.new(instance: Model, character: Model): HammerController
	local self = setmetatable(
		ToolController.new(instance, character) :: HCInternal,
		{ __index = CreateMultiIndex(ToolController.InheritedMethods, HCPublicMethods, HCPrivateMethods) }
	)

	self:_init()

	return self
end

--[=[
	Builds a block where the player's cursor is pointing.
	@param toBuild boolean -- Whether to start or stop building
]=]
function HCPublicMethods.PlaceBlock(self: HammerController, toPlace: boolean): () end

--[=[
	Deletes the block, if any, where the player's cursor is pointing.
	@param toDelete boolean -- Whether to start or stop deleting
]=]
function HCPublicMethods.DeleteBlock(self: HammerController, toDelete: boolean): () end

function HCPrivateMethods._init(self: HCInternal): ()
	-- Load the hammer configuration
	local configuration = self.Instance:FindFirstChildOfClass("Configuration")
	if not configuration then
		error("Configuration not found in Instance", 2)
	end
	self._config = GetHammerConfig(configuration)
end

return HammerController
