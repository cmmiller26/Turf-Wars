--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

export type CharacterController = {
	Instance: Model,

	Destroy: (self: CharacterController) -> (),

	IsA: (self: CharacterController, className: string) -> boolean,
}
export type RoundCharacterController = CharacterController & {
	ToolEquipped: Signal.Signal<ToolController>,
	ToolUnequipped: Signal.Signal<ToolController>,

	EquipTool: (self: RoundCharacterController, toolType: ToolType) -> (),
	Unequip: (self: RoundCharacterController) -> boolean,

	GetCurrentTool: (self: RoundCharacterController) -> ToolController?,

	GetCombatEnabled: (self: RoundCharacterController) -> boolean,
	SetCombatEnabled: (self: RoundCharacterController, enabled: boolean) -> (),
}

export type RoundInputHandler = {
	Destroy: (self: RoundInputHandler) -> (),
}

export type TiltCharacter = {
	Instance: Model,

	Destroying: Signal.Signal<nil>,

	Update: (self: TiltCharacter, angle: number?) -> (),
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
export type ToolType = "Hammer" | "Slingshot"

export type Viewmodel = {
	Instance: Model,

	Destroy: (self: Viewmodel) -> (),
}

local Types = {} :: {
	CharacterController: CharacterController,
	RoundCharacterController: RoundCharacterController,
	RoundInputHandler: RoundInputHandler,
	TiltCharacter: TiltCharacter,
	ToolController: ToolController,
	Viewmodel: Viewmodel,
}

return Types
