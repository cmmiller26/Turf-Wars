--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedTypes = require(ReplicatedStorage.SharedTypes)
local Signal = require(ReplicatedStorage.Packages.Signal)

export type CharacterController = {
	Instance: Model,

	Destroy: (self: CharacterController) -> (),

	IsA: (self: CharacterController, characterType: SharedTypes.CharacterType) -> boolean,

	Sneak: (self: CharacterController, toSneak: boolean) -> (),
	Sprint: (self: CharacterController, toSprint: boolean) -> (),
}
export type RoundCharacterController = CharacterController & {
	ToolEquipped: Signal.Signal<ToolController>,
	ToolUnequipped: Signal.Signal<ToolController>,

	EquipTool: (self: RoundCharacterController, toolType: SharedTypes.ToolType) -> (),
	Unequip: (self: RoundCharacterController) -> boolean,

	GetCurrentTool: (self: RoundCharacterController) -> ToolController?,

	GetCombatEnabled: (self: RoundCharacterController) -> boolean,
	SetCombatEnabled: (self: RoundCharacterController, enabled: boolean) -> (),
}

export type ToolController = {
	Instance: Model,

	Equipped: boolean,
	IsActive: boolean,

	MouseIcon: string,

	Destroy: (self: ToolController) -> (),

	IsA: (self: ToolController, toolType: SharedTypes.ToolType) -> boolean,

	Equip: (self: ToolController) -> (),
	Unequip: (self: ToolController) -> (),

	ActivatePrimary: (self: ToolController, toActivate: boolean) -> (),
	ActivateSecondary: (self: ToolController, toActivate: boolean) -> (),
}

export type RoundInputHandler = {
	Destroy: (self: RoundInputHandler) -> (),
}

export type TiltCharacter = {
	Instance: Model,

	Destroying: Signal.Signal<nil>,

	Update: (self: TiltCharacter, angle: number?) -> (),
}

export type Viewmodel = {
	Instance: Model,

	Destroy: (self: Viewmodel) -> (),
}

--[=[
	@interface ProjectileModifier
	@field Speed number -- The speed to cast the projectile at
	@field Gravity number -- The gravity to apply to the projectile
	@field Lifetime number -- The lifetime of the projectile
	@field PVInstance PVInstance? -- The instance to represent the projectile
	@field Color Color3? -- The color to set the PVInstance to
	@field Timestamp number? -- Server time when the projectile was cast
	@field OnImpact BindableEvent? -- The event to fire on projectile impact
	@within ClientTypes
]=]
export type ProjectileModifier = {
	Speed: number,
	Gravity: number,

	Lifetime: number,

	PVInstance: PVInstance?,
	Color: Color3?,

	Timestamp: number?,

	OnImpact: BindableEvent?,
}

--[=[
	@interface Projectile
	@field Position Vector3 -- The current position of the projectile
	@field Velocity Vector3 -- The current velocity of the projectile
	@field Acceleration Vector3 -- The acceleration of the projectile
	@field RaycastParams RaycastParams -- The raycast parameters for the projectile
	@field Lifetime number -- The lifetime of the projectile
	@field StartTick number -- The tick the projectile was cast
	@field LastTick number -- The last tick the projectile was updated
	@field PVInstance PVInstance? -- The instance representing the projectile
	@field Timestamp number? -- Server time when the projectile was cast
	@field OnImpact BindableEvent? -- The event to fire when the projectile impacts
	@within ClientTypes
]=]
export type Projectile = {
	Position: Vector3,
	Velocity: Vector3,
	Acceleration: Vector3,

	RaycastParams: RaycastParams,

	Lifetime: number,
	StartTick: number,
	LastTick: number,

	PVInstance: PVInstance?,

	Timestamp: number?,

	OnImpact: BindableEvent?,
}

--[=[
	@class ClientTypes
	@client
]=]
local ClientTypes = {}

return ClientTypes
