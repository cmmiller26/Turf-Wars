--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedTypes = require(ReplicatedStorage.SharedTypes)

export type PlayerHandler = {
	Instance: Player,

	Destroy: (self: PlayerHandler) -> (),

	IsA: (self: PlayerHandler, className: string) -> boolean,

	OnTilt: (self: PlayerHandler, angle: number) -> (),
}
export type RoundPlayerHandler = PlayerHandler & {
	SetCombatEnabled: (self: RoundPlayerHandler, enabled: boolean) -> (),

	OnEquipTool: (self: RoundPlayerHandler, toolType: SharedTypes.ToolType) -> (),
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
		projHitType: SharedTypes.ProjectileHitType,
		hitPart: BasePart,
		hitTimestamp: number,
		fireTimestamp: number
	) -> (),
}

--[=[
	@type PlayerType "Lobby" | "Round"
	@within ServerTypes
]=]
export type PlayerType = "Lobby" | "Round"

--[=[
	@class ServerTypes
	@server
]=]
local ServerTypes = {}

return ServerTypes
