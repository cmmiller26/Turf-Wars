--!strict

export type GameCharacterController = {
	Instance: Model,

	Destroy: (self: GameCharacterController) -> (),

	EquipTool: (self: GameCharacterController, string) -> (),
	Unequip: (self: GameCharacterController) -> boolean,

	GetCurrentTool: (self: GameCharacterController) -> ToolController?,
}

export type ToolController = {
	Instance: Model,

	Equipped: boolean,
	IsActive: boolean,

	MouseIcon: string,

	Destroy: (self: ToolController) -> (),

	IsA: (self: ToolController, className: string) -> boolean,

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

export type GameInputHandler = {
	Destroy: (self: GameInputHandler) -> (),
}

export type Viewmodel = {
	Instance: Model,

	Destroy: (self: Viewmodel) -> (),
}

export type TiltCharacter = {
	Instance: Model,

	Update: (self: TiltCharacter, angle: number?) -> (),
}

local Types = {}

return Types
