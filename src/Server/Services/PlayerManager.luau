--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

local Server = ServerScriptService.Server
local Types = require(Server.Types)

local PlayerHandler = Server.Classes.PlayerHandler
local LobbyPlayerHandler = require(PlayerHandler.LobbyPlayerHandler)
local RoundPlayerHandler = require(PlayerHandler.RoundPlayerHandler)

type PlayerManager = {
	GetHandler: (self: PlayerManager, player: Player) -> Types.PlayerHandler?,
	CreateHandler: (self: PlayerManager, player: Player, handlerType: string) -> Types.PlayerHandler,
}
type PMInternal = PlayerManager & {
	_handlers: { [number]: Types.PlayerHandler },

	_init: (self: PMInternal) -> (),

	_createHandler: (self: PMInternal, player: Player, handlerType: string) -> Types.PlayerHandler,
}

local HandlerType = {
	Lobby = "Lobby",
	Round = "Round",
}

local Remotes = ReplicatedStorage.Remotes

local function WarnInvalidArgument(player: Player, argName: string, expectedType: string)
	warn(string.format("%s passed an invalid argument: Expected %s for %s", player.Name, expectedType, argName))
end

local PlayerManager = {}

local PMPublicMethods = {}
local PMPrivateMethods = {}

function PlayerManager.new(): PlayerManager
	local self = setmetatable({} :: PMInternal, { __index = CreateMultiIndex(PMPublicMethods, PMPrivateMethods) })

	self:_init()

	return self
end

function PMPublicMethods.GetHandler(self: PMInternal, player: Player): Types.PlayerHandler?
	return self._handlers[player.UserId]
end
function PMPublicMethods.CreateHandler(self: PMInternal, player: Player, handlerType: string): Types.PlayerHandler
	return self:_createHandler(player, handlerType)
end

function PMPrivateMethods._init(self: PMInternal)
	self._handlers = {}

	local function ValidateRoundHandler(player: Player): Types.RoundPlayerHandler?
		local handler = self:GetHandler(player)
		if handler and handler:IsA("RoundPlayerHandler") then
			return handler :: Types.RoundPlayerHandler
		else
			warn(string.format("%s's RoundPlayerHandler not found", player.Name))
			return nil
		end
	end

	-- Character RemoteEvents
	Remotes.Character.Tilt.OnServerEvent:Connect(function(player, angle)
		if typeof(angle) ~= "number" then
			return WarnInvalidArgument(player, "angle", "number")
		end
		local handler = self:GetHandler(player)
		if handler then
			handler:OnTilt(angle)
		end
	end)
	Remotes.Character.EquipTool.OnServerEvent:Connect(function(player, toolType)
		if typeof(toolType) ~= "string" then
			return WarnInvalidArgument(player, "toolType", "string")
		end
		local handler = ValidateRoundHandler(player)
		if handler then
			handler:OnEquipTool(toolType)
		end
	end)
	Remotes.Character.Unequip.OnServerEvent:Connect(function(player)
		local handler = ValidateRoundHandler(player)
		if handler then
			handler:OnUnequip()
		end
	end)

	-- Hammer RemoteEvents
	Remotes.Tool.Hammer.PlaceBlock.OnServerEvent:Connect(function(player, placePos)
		if typeof(placePos) ~= "Vector3" then
			return WarnInvalidArgument(player, "placePos", "Vector3")
		end
		local handler = ValidateRoundHandler(player)
		if handler then
			handler:OnPlaceBlock(placePos)
		end
	end)
	Remotes.Tool.Hammer.DeleteBlock.OnServerEvent:Connect(function(player, targetBlock)
		if typeof(targetBlock) ~= "Instance" or not targetBlock:IsA("BasePart") then
			return WarnInvalidArgument(player, "targetBlock", "BasePart")
		end
		local handler = ValidateRoundHandler(player)
		if handler then
			handler:OnDeleteBlock(targetBlock)
		end
	end)

	-- Slingshot RemoteEvents
	Remotes.Tool.Slingshot.FireProjectile.OnServerEvent:Connect(function(player, origin, direction, speed, timestamp)
		if
			typeof(origin) ~= "Vector3"
			or typeof(direction) ~= "Vector3"
			or typeof(speed) ~= "number"
			or typeof(timestamp) ~= "number"
		then
			return WarnInvalidArgument(player, "FireProjectile", "Vector3, Vector3, number, number")
		end
		local handler = ValidateRoundHandler(player)
		if handler then
			handler:OnFireProjectile(origin, direction, speed, timestamp)
		end
	end)
	Remotes.Tool.Slingshot.RegisterHit.OnServerEvent:Connect(
		function(player, hitType, hitPart, hitTimestamp, fireTimestamp)
			if
				not (hitType == "Block" or hitType == "Character")
				or typeof(hitPart) ~= "Instance"
				or not hitPart:IsA("BasePart")
				or typeof(hitTimestamp) ~= "number"
				or typeof(fireTimestamp) ~= "number"
			then
				return WarnInvalidArgument(player, "RegisterHit", '"Block" | "Character", BasePart, number, number')
			end
			local handler = ValidateRoundHandler(player)
			if handler then
				handler:OnRegisterHit(hitType, hitPart, hitTimestamp, fireTimestamp)
			end
		end
	)
end

function PMPrivateMethods._createHandler(self: PMInternal, player: Player, handlerType: string): Types.PlayerHandler
	local handler = self._handlers[player.UserId]
	if handler then
		handler:Destroy()
	end

	if handlerType == HandlerType.Lobby then
		handler = LobbyPlayerHandler.new(player)
	elseif handlerType == HandlerType.Round then
		handler = RoundPlayerHandler.new(player)
	else
		error(string.format("Invalid handlerType: %s", handlerType))
	end
	self._handlers[player.UserId] = handler

	return handler
end

return PlayerManager.new()
