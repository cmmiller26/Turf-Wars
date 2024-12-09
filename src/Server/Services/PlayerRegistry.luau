--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- External dependencies
local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

-- Server modules
local Server = ServerScriptService.Server
local Types = require(Server.Types)

local PlayerHandler = Server.Classes.PlayerHandler
local LobbyPlayerHandler = require(PlayerHandler.LobbyPlayerHandler)
local RoundPlayerHandler = require(PlayerHandler.RoundPlayerHandler)

type PlayerRegistry = {
	GetHandler: (self: PlayerRegistry, player: Player) -> Types.PlayerHandler?,
	CreateHandler: (self: PlayerRegistry, player: Player, handlerType: Types.HandlerType) -> Types.PlayerHandler?,
}
type PMInternal = PlayerRegistry & {
	_handlers: { [number]: Types.PlayerHandler },

	_init: (self: PMInternal) -> (),
	_setupRemoteHandlers: (self: PMInternal) -> (),

	_onPlayerRemoving: (self: PMInternal, player: Player) -> (),
}

-- Remote events folder
local Remotes = ReplicatedStorage.Remotes

--[=[
	Warns the server that a player called a method with an invalid argument.
	@param player -- The `Player` that called the method.
	@param methodName -- The name of the method that was called.
	@param argName -- The name of the argument that was invalid.
	@param expectedType -- The expected type of the argument.
]=]
local function WarnInvalidArgument(player: Player, remoteName: string, argName: string, expectedType: string)
	warn(
		string.format(
			"[PlayerRegistry]: %s fired %s with invalid argument '%s': Expected %s",
			player.Name,
			remoteName,
			argName,
			expectedType
		)
	)
end

--[=[
    `PlayerRegistry` is a singleton class responsible for managing player handlers within the game.

    This class maintains a mapping between `Player` instances and their corresponding `PlayerHandler` objects, facilitating efficient retrieval and management of player-specific data and behaviors.
	It also sets up server-side remote event handlers to process client requests and delegate actions to the appropriate player handlers.

    **Responsibilities:**
    - Create and manage `PlayerHandler` instances for each player.
    - Provide methods to retrieve and create player handlers.
    - Set up and handle remote events from clients.
    - Clean up player handlers when players leave the game.

    **Key Features:**
    - **Handler Management:** Dynamically creates appropriate handlers (`LobbyPlayerHandler` or `RoundPlayerHandler`) based on the game state.
    - **Remote Event Handling:** Listens to client events and delegates them to the correct player handlers after validation.
    - **Type Safety:** Employs strict typing (`--!strict`) and type annotations to enhance code reliability and maintainability.
    - **Singleton Pattern:** Ensures only one instance of `PlayerRegistry` exists throughout the game.

    **Notes:**
    - The `PlayerRegistry` should be required once and treated as a singleton.
    - It relies on remote events defined under `ReplicatedStorage.Remotes`.
    - All remote event handlers perform thorough validation of client-provided data before passing it to handlers.
    - Proper cleanup is ensured when players leave to prevent memory leaks.
]=]
local PlayerRegistry = {}

local PMPublicMethods = {}
local PMPrivateMethods = {}

local _instance: PlayerRegistry?
function PlayerRegistry.new(): PlayerRegistry
	if _instance then
		error("[PlayerRegistry.new]: Attempted to create multiple instances of a singleton", 2)
	end

	local self = setmetatable({} :: PMInternal, { __index = CreateMultiIndex(PMPublicMethods, PMPrivateMethods) })

	self:_init()

	return self
end

--[=[
	Returns the player handler for the given player, if it exists.
	@param player -- The `Player` to get the handler for.
	@return PlayerHandler? -- The player handler instance, or nil if it doesn't exist.
]=]
function PMPublicMethods.GetHandler(self: PMInternal, player: Player): Types.PlayerHandler?
	return self._handlers[player.UserId]
end

--[=[
	Creates a new player handler for the given player.
	@param player -- The `Player` to create the handler for.
	@param handlerType -- The `HandlerType` of the handler to create.
	@return PlayerHandler -- The player handler instance.
]=]
function PMPublicMethods.CreateHandler(
	self: PMInternal,
	player: Player,
	handlerType: Types.HandlerType
): Types.PlayerHandler?
	local handler = self._handlers[player.UserId]
	if handler then
		handler:Destroy()
	end

	if handlerType == "Lobby" then
		handler = LobbyPlayerHandler.new(player)
	elseif handlerType == "Round" then
		handler = RoundPlayerHandler.new(player)
	else
		warn(string.format("[PlayerRegistry.CreateHandler]: Invalid handler type '%s'", handlerType))
		return nil
	end
	self._handlers[player.UserId] = handler

	return handler
end

function PMPrivateMethods._init(self: PMInternal): ()
	_instance = self

	self._handlers = {}

	Players.PlayerRemoving:Connect(function(player)
		self:_onPlayerRemoving(player)
	end)

	self:_setupRemoteHandlers()
end
function PMPrivateMethods._setupRemoteHandlers(self: PMInternal): ()
	local function ValidateRoundHandler(player: Player, remoteName: string): Types.RoundPlayerHandler?
		if not Players:GetPlayerByUserId(player.UserId) then
			return nil
		end

		local handler = self:GetHandler(player)
		if handler and handler:IsA("RoundPlayerHandler") then
			return handler :: Types.RoundPlayerHandler
		else
			warn(
				string.format(
					"[PlayerRegistry]: %s fired %s without a valid RoundPlayerHandler",
					player.Name,
					remoteName
				)
			)
			return nil
		end
	end

	-- Character RemoteEvents
	Remotes.Character.Tilt.OnServerEvent:Connect(function(player, angle)
		if typeof(angle) ~= "number" then
			return WarnInvalidArgument(player, "Tilt", "angle", "number")
		end
		local handler = self:GetHandler(player)
		if handler then
			handler:OnTilt(angle)
		end
	end)
	Remotes.Character.EquipTool.OnServerEvent:Connect(function(player, toolType)
		if not (toolType == "Hammer" or toolType == "Slingshot") then
			return WarnInvalidArgument(player, "EquipTool", "toolType", "ToolType")
		end
		local handler = ValidateRoundHandler(player, "EquipTool")
		if handler then
			handler:OnEquipTool(toolType)
		end
	end)
	Remotes.Character.Unequip.OnServerEvent:Connect(function(player)
		local handler = ValidateRoundHandler(player, "Unequip")
		if handler then
			handler:OnUnequip()
		end
	end)

	-- Hammer RemoteEvents
	Remotes.Tool.Hammer.PlaceBlock.OnServerInvoke = function(player, placePos)
		if typeof(placePos) ~= "Vector3" then
			return WarnInvalidArgument(player, "PlaceBlock", "placePos", "Vector3")
		end
		local handler = ValidateRoundHandler(player, "PlaceBlock")
		if handler then
			return handler:OnPlaceBlock(placePos)
		end
	end
	Remotes.Tool.Hammer.DeleteBlock.OnServerEvent:Connect(function(player, targetBlock)
		if not (typeof(targetBlock) == "Instance" and targetBlock:IsA("BasePart")) then
			return WarnInvalidArgument(player, "DeleteBlock", "targetBlock", "BasePart")
		end
		local handler = ValidateRoundHandler(player, "DeleteBlock")
		if handler then
			handler:OnDeleteBlock(targetBlock)
		end
	end)

	-- Slingshot RemoteEvents
	Remotes.Tool.Slingshot.FireProjectile.OnServerEvent:Connect(function(player, origin, direction, speed, timestamp)
		if typeof(origin) ~= "Vector3" then
			return WarnInvalidArgument(player, "FireProjectile", "origin", "Vector3")
		elseif typeof(direction) ~= "Vector3" then
			return WarnInvalidArgument(player, "FireProjectile", "direction", "Vector3")
		elseif typeof(speed) ~= "number" then
			return WarnInvalidArgument(player, "FireProjectile", "speed", "number")
		elseif typeof(timestamp) ~= "number" then
			return WarnInvalidArgument(player, "FireProjectile", "timestamp", "number")
		end
		local handler = ValidateRoundHandler(player, "FireProjectile")
		if handler then
			handler:OnFireProjectile(origin, direction, speed, timestamp)
		end
	end)
	Remotes.Tool.Slingshot.RegisterHit.OnServerEvent:Connect(
		function(player, projHitType, hitPart, hitTimestamp, fireTimestamp)
			if not (projHitType == "Block" or projHitType == "Character") then
				return WarnInvalidArgument(player, "RegisterHit", "projHitType", "ProjectileHitType")
			elseif not (typeof(hitPart) == "Instance" and hitPart:IsA("BasePart")) then
				return WarnInvalidArgument(player, "RegisterHit", "hitPart", "BasePart")
			elseif typeof(hitTimestamp) ~= "number" then
				return WarnInvalidArgument(player, "RegisterHit", "hitTimestamp", "number")
			elseif typeof(fireTimestamp) ~= "number" then
				return WarnInvalidArgument(player, "RegisterHit", "fireTimestamp", "number")
			end
			local handler = ValidateRoundHandler(player, "RegisterHit")
			if handler then
				handler:OnRegisterHit(projHitType, hitPart, hitTimestamp, fireTimestamp)
			end
		end
	)
end

function PMPrivateMethods._onPlayerRemoving(self: PMInternal, player: Player): ()
	local handler = self:GetHandler(player)
	if handler then
		handler:Destroy()
	end
	self._handlers[player.UserId] = nil
end

return PlayerRegistry.new()
