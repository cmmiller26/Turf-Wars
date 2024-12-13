--!strict

--[=[
	@type ToolType "Hammer" | "Slingshot"
	@within SharedTypes
]=]
export type ToolType = "Hammer" | "Slingshot"

--[=[
	@interface HammerConfig
	@field Damage number -- The amount of damage the hammer does to a block each hit
	@field MaxDistance number -- The maximum distance the hammer can perform an action
	@field PlaceRPM number -- The rate at which the hammer can place blocks per minute
	@field DeleteRPM number -- The rate at which the hammer hits blocks per minute
	@within SharedTypes
]=]
export type HammerConfig = {
	Damage: number,

	MaxDistance: number,

	PlaceRPM: number,
	DeleteRPM: number,
}
--[=[
	@interface SlingshotConfig
	@field Damage { Base: number, SpeedMultiplier: number, HeadshotMultiplier: number }
	@field Projectile { StartSpeed: number, MaxSpeed: number, Gravity: number, Lifetime: number, PVInstance: PVInstance? }
	@field DrawSpeed number -- The rate of change of the projectile's speed when drawing the slingshot
	@field RPM number -- The rate of fire of the slingshot
	@within SharedTypes
]=]
export type SlingshotConfig = {
	Damage: {
		Base: number,
		SpeedMultiplier: number,
		HeadshotMultiplier: number,
	},

	Projectile: {
		StartSpeed: number,
		MaxSpeed: number,

		Gravity: number,

		Lifetime: number,

		PVInstance: PVInstance?,
	},

	DrawSpeed: number,

	RPM: number,
}

--[=[
	@type ProjectileHitType "Block" | "Character"
	@within SharedTypes
]=]
export type ProjectileHitType = "Block" | "Character"

--[=[
	@class SharedTypes
	@external Trove https://sleitnick.github.io/RbxUtil/api/Trove/
	@external Signal https://sleitnick.github.io/RbxUtil/api/Signal/
]=]
local SharedTypes = {}

return SharedTypes
