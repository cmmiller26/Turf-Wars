import { ProjectileConfig } from "./projectileTypes";

export const enum ToolType {
	Hammer = "Hammer",
	Slingshot = "Slingshot",
}

export interface ToolInstance extends Model {
	Animations: Folder & {
		R6: AnimationFolder;
		R15: AnimationFolder;
		Viewmodel: AnimationFolder;
	};
	Handle: BasePart;
}

export interface ToolAnimations {
	Idle: Animation;
	Equip: Animation;
}

type AnimationFolder = Folder & ToolAnimations;

export const enum ResourceType {
	None = "None",
	Block = "Block",
	Projectile = "Projectile",
}

export type TargetIndicator = PVInstance & { SelectionBox: SelectionBox };
export type HammerConfig = {
	range: number;

	damage: number;
	rateOfDamage: number;
};

export type SlingshotConfig = {
	drawSpeed: number;
	projectile: ProjectileConfig;
	rateOfFire: number;
};
