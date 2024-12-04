--!strict

export type PlayerHandler = {
	Instance: Player,

	Destroy: (self: PlayerHandler) -> (),

	IsA: (self: PlayerHandler, className: string) -> boolean,

	OnTilt: (self: PlayerHandler, angle: number) -> (),
}
export type RoundPlayerHandler = PlayerHandler & {
	SetCombatEnabled: (self: RoundPlayerHandler, enabled: boolean) -> (),

	OnEquipTool: (self: RoundPlayerHandler, toolType: ToolType) -> (),
	OnUnequip: (self: RoundPlayerHandler) -> (),

	OnPlaceBlock: (self: RoundPlayerHandler, placePos: Vector3) -> (),
	OnDeleteBlock: (self: RoundPlayerHandler, targetBlock: BasePart) -> (),

	OnFireProjectile: (
		self: RoundPlayerHandler,
		origin: Vector3,
		direction: Vector3,
		speed: number,
		timestamp: number
	) -> (),
	OnRegisterHit: (
		self: RoundPlayerHandler,
		projHitType: ProjectileHitType,
		hitPart: BasePart,
		hitTimestamp: number,
		fireTimestamp: number
	) -> (),
}
export type HandlerType = "Lobby" | "Round"

export type ToolType = "Hammer" | "Slingshot"
export type ProjectileHitType = "Block" | "Character"

local Types = {}

return Types
