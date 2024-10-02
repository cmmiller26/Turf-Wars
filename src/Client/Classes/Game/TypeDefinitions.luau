--!strict

--[[
	Types for specific Game classes. These types are defined here to avoid circular dependencies.
]]
local TypeDefinitions = {}

export type GameCharacterController = {
	Instance: Model, -- The character model

	Destroy: (self: GameCharacterController) -> (),

	EquipTool: (self: GameCharacterController, string) -> (),
	Unequip: (self: GameCharacterController) -> boolean,
}

export type ToolController = {
	Instance: Model, -- The tool instance

	Equipped: boolean, -- Whether the tool is equipped
	IsActive: boolean, -- Whether the tool is being used

	MouseIcon: string, -- The mouse icon to display when the tool is equipped

	Destroy: (self: ToolController) -> (),

	IsA: (self: ToolController, classType: string) -> boolean,

	Equip: (self: ToolController) -> (),
	Unequip: (self: ToolController) -> (),
}
export type HammerController = ToolController & {
	PlaceBlock: (self: HammerController, toPlace: boolean) -> (),
	DeleteBlock: (self: HammerController, toDelete: boolean) -> (),
}
export type SlingshotController = ToolController & {
	FireProjectile: (self: SlingshotController, toFire: boolean) -> (),
}

return TypeDefinitions
