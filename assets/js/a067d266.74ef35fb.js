"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[8455],{17651:e=>{e.exports=JSON.parse('{"functions":[{"name":"new","desc":"Constructs a new `RoundPlayerHandler` for the given [Player].","params":[{"name":"instance","desc":"","lua_type":"Player"}],"returns":[{"desc":"","lua_type":"RoundPlayerHandler"}],"function_type":"static","source":{"line":195,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}},{"name":"SetCombatEnabled","desc":"Sets whether combat is enabled for the client.","params":[{"name":"enabled","desc":"","lua_type":"boolean"}],"returns":[],"function_type":"method","source":{"line":216,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}},{"name":"OnEquipTool","desc":"Handles the client equipping a tool of the given [ToolType].","params":[{"name":"toolType","desc":"","lua_type":"ToolType"}],"returns":[],"function_type":"method","source":{"line":227,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}},{"name":"OnUnequip","desc":"Handles the client unequipping their current tool.","params":[],"returns":[],"function_type":"method","source":{"line":258,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}},{"name":"OnPlaceBlock","desc":"Handles the client placing a block at the given position.","params":[{"name":"placePos","desc":"","lua_type":"Vector3"}],"returns":[{"desc":"Whether the block was successfully placed.","lua_type":"boolean"}],"function_type":"method","source":{"line":276,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}},{"name":"OnDeleteBlock","desc":"Handles the client deleting a block at the given position.","params":[{"name":"targetBlock","desc":"","lua_type":"BasePart"}],"returns":[],"function_type":"method","source":{"line":356,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}},{"name":"OnFireProjectile","desc":"Handles the client firing a projectile with the given origin, direction, speed, and timestamp.","params":[{"name":"origin","desc":"","lua_type":"Vector3"},{"name":"direction","desc":"","lua_type":"Vector3"},{"name":"speed","desc":"","lua_type":"number"},{"name":"timestamp","desc":"","lua_type":"number"}],"returns":[],"function_type":"method","source":{"line":408,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}},{"name":"OnRegisterHit","desc":"Handles the client registering a hit on a [BasePart] with the given [ProjectileHitType], and timestamps.","params":[{"name":"projHitType","desc":"","lua_type":"ProjectileHitType"},{"name":"hitPart","desc":"","lua_type":"BasePart"},{"name":"hitTimestamp","desc":"","lua_type":"number"},{"name":"fireTimestamp","desc":"","lua_type":"number"}],"returns":[],"function_type":"method","source":{"line":515,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}},{"name":"_init","desc":"Overrides [PlayerHandler:_init].","params":[{"name":"instance","desc":"","lua_type":"Player"}],"returns":[],"function_type":"method","tags":["Override"],"private":true,"source":{"line":664,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}},{"name":"_addKickOffense","desc":"Increments the client\'s kick offenses, kicking them for the given reason if they exceed the maximum number of offenses.","params":[{"name":"reason","desc":"","lua_type":"string"}],"returns":[],"function_type":"method","private":true,"source":{"line":691,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}},{"name":"_onCharacterAdded","desc":"Overrides [PlayerHandler:_onCharacterAdded] to create the client\'s ToolJoint [Motor6D], and find their tools and configurations.","params":[{"name":"character","desc":"","lua_type":"Model"}],"returns":[],"function_type":"method","tags":["Override"],"private":true,"source":{"line":711,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}},{"name":"_onCharacterAppearanceLoaded","desc":"Handles the loading of the client\'s character appearance, disabling [BasePart.CanQuery] for all accessories to prevent them from being queried by projectiles.","params":[{"name":"character","desc":"","lua_type":"Model"}],"returns":[],"function_type":"method","private":true,"source":{"line":783,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}}],"properties":[{"name":"_backpack","desc":"The client\'s [Backpack].","lua_type":"Backpack","private":true,"source":{"line":116,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}},{"name":"_combatEnabled","desc":"Whether the client is allowed to engage in combat.","lua_type":"boolean","private":true,"source":{"line":122,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}},{"name":"_lastPlaceBlockTick","desc":"The tick of the last block placement.","lua_type":"number","private":true,"source":{"line":128,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}},{"name":"_lastDeleteBlockTick","desc":"The tick of the last block deletion.","lua_type":"number","private":true,"source":{"line":134,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}},{"name":"_projectileRecords","desc":"A dictionary mapping the timestamp of a projectile to its [ProjectileRecord].","lua_type":"{ [number]: ProjectileRecord }","private":true,"source":{"line":140,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}},{"name":"_lastFireProjectileTick","desc":"The tick of the last projectile firing.","lua_type":"number","private":true,"source":{"line":146,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}},{"name":"_kickOffenses","desc":"The number of offenses the client has committed.","lua_type":"number","private":true,"source":{"line":152,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}},{"name":"_toolJoint","desc":"The [Motor6D] used to attach tools to the character.","lua_type":"Motor6D","private":true,"source":{"line":158,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}},{"name":"_tools","desc":"A dictionary mapping the client\'s tools to their [Model].","lua_type":"{ [ToolType]: Model }","private":true,"source":{"line":164,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}},{"name":"_curTool","desc":"The currently equipped tool.","lua_type":"Model?","private":true,"source":{"line":170,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}},{"name":"_configs","desc":"The configurations for the client\'s tools.","lua_type":"{ Hammer: HammerConfig, Slingshot: SlingshotConfig }","private":true,"source":{"line":176,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}}],"types":[{"name":"ProjectileRecord","desc":"The record of a projectile fired by a player.","fields":[{"name":"Origin","lua_type":"Vector3","desc":""},{"name":"Direction","lua_type":"Vector3","desc":""},{"name":"Speed","lua_type":"number","desc":""}],"source":{"line":67,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}}],"name":"RoundPlayerHandler","desc":"RoundPlayerHandler extends [PlayerHandler] to manage a client\'s [CharacterController] during a round.\\nIt is responsible for handling the client\'s [HammerController] block placement and deletion, as well as their [SlingshotController] projectile firing.\\nIt also manages the client\'s combat state and kick offenses, kicking them if deemed necessary.","tags":["PlayerHandler"],"source":{"line":184,"path":"src/Server/Classes/PlayerHandler/RoundPlayerHandler.luau"}}')}}]);