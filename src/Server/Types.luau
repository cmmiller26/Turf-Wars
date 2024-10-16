--!strict

export type GamePlayerHandler = {
	Instance: Player,

	Destroy: (self: GamePlayerHandler) -> (),
}

local Types = {}

return Types
