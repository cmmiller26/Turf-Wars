--!strict

export type PlayerHandler = {
	Instance: Player,

	Destroy: (self: PlayerHandler) -> (),

	IsA: (self: PlayerHandler, className: string) -> boolean,
}

local Types = {}

return Types
