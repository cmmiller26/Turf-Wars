--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- External dependencies
local SharedTypes = require(ReplicatedStorage.SharedTypes)
local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

-- Server modules
local Server = ServerScriptService.Server
local ServerTypes = require(Server.ServerTypes)

local PlayerHandler = Server.Classes.PlayerHandler
local LobbyPlayerHandler = require(PlayerHandler.LobbyPlayerHandler)
local RoundPlayerHandler = require(PlayerHandler.RoundPlayerHandler)

type PlayerRegistry = {
	GetHandler: (self: PlayerRegistry, player: Player) -> ServerTypes.PlayerHandler?,
	CreateHandler: (
		self: PlayerRegistry,
		player: Player,
		characterType: SharedTypes.CharacterType
	) -> ServerTypes.PlayerHandler?,
}
type PMInternal = PlayerRegistry & {
	_handlers: { [number]: ServerTypes.PlayerHandler },

	_init: (self: PMInternal) -> (),
	_setupRemoteHandlers: (self: PMInternal) -> (),

	_onPlayerRemoving: (self: PMInternal, player: Player) -> (),
}

-- Remote events folder
local Remotes = ReplicatedStorage.Remotes

--[[
	Warns the server that a remote event was fired with an invalid argument.
	@param player Player -- The player who fired the remote event
	@param remoteName string
	@param argName string
	@param expectedType string
]]
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
	A dictionary mapping player user IDs to their respective [PlayerHandler] instances.
	@prop _handlers { [number]: PlayerHandler }
	@private
	@within PlayerRegistry
]=]

--[=[
	PlayerRegistry is a singleton class that manages the [PlayerHandler] instances for each player in the game.
	It is responsible for listening to remote events and invoking the appropriate methods on the player handlers.
	@class PlayerRegistry
	@server
	@tag Singleton
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
	Returns the [PlayerHandler] for the given player, if it exists.
	@method GetHandler
	@param player Player
	@return PlayerHandler?
	@within PlayerRegistry
]=]
function PMPublicMethods.GetHandler(self: PMInternal, player: Player): ServerTypes.PlayerHandler?
	return self._handlers[player.UserId]
end

--[=[
	Creates a new [PlayerHandler] for the given player with the specified [CharacterType].
	If a handler already exists for the player, it will be destroyed before creating a new one.
	@method CreateHandler
	@param player Player
	@param characterType CharacterType
	@return PlayerHandler?
	@within PlayerRegistry
]=]
function PMPublicMethods.CreateHandler(
	self: PMInternal,
	player: Player,
	characterType: SharedTypes.CharacterType
): ServerTypes.PlayerHandler?
	local handler = self._handlers[player.UserId]
	if handler then
		handler:Destroy()
	end

	if characterType == "LobbyCharacter" then
		handler = LobbyPlayerHandler.new(player)
	elseif characterType == "RoundCharacter" then
		handler = RoundPlayerHandler.new(player)
	else
		warn(string.format("[PlayerRegistry:CreateHandler]: Invalid character type '%s'", characterType))
		return nil
	end
	self._handlers[player.UserId] = handler

	return handler
end

--[=[
	Initializes the player registry by setting up event listeners and remote handlers.
	@method _init
	@private
	@within PlayerRegistry
]=]
function PMPrivateMethods._init(self: PMInternal): ()
	_instance = self

	self._handlers = {}

	Players.PlayerRemoving:Connect(function(player)
		self:_onPlayerRemoving(player)
	end)

	self:_setupRemoteHandlers()
end

--[=[
	Sets up the remote event handlers for the player registry.
	@method _setupRemoteHandlers
	@private
	@within PlayerRegistry
]=]
function PMPrivateMethods._setupRemoteHandlers(self: PMInternal): ()
	local function ValidateRoundHandler(player: Player, remoteName: string): ServerTypes.RoundPlayerHandler?
		if not Players:GetPlayerByUserId(player.UserId) then
			return nil
		end

		local handler = self:GetHandler(player)
		if handler and handler:IsCharacterType("RoundCharacter") then
			return handler :: ServerTypes.RoundPlayerHandler
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

--[=[
	Destroys the [PlayerHandler] for the given player when they leave the game.
	@method _onPlayerRemoving
	@param player Player
	@private
	@within PlayerRegistry
]=]
function PMPrivateMethods._onPlayerRemoving(self: PMInternal, player: Player): ()
	local handler = self:GetHandler(player)
	if handler then
		handler:Destroy()
	end
	self._handlers[player.UserId] = nil
end

return PlayerRegistry.new()
