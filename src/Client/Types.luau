--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

export type GameCharacterController = {
	Instance: Model,

	ToolEquipped: Signal.Signal<ToolController>,
	ToolUnequipped: Signal.Signal<ToolController>,

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

	ActivatePrimary: (self: ToolController, toActivate: boolean) -> (),
	ActivateSecondary: (self: ToolController, toActivate: boolean) -> (),
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
