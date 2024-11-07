--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- External dependencies
local Trove = require(ReplicatedStorage.Packages.Trove)
local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

-- Server modules
local Types = require(ServerScriptService.Server.Types)

type PlayerHandler = Types.PlayerHandler
type PHInternal = PlayerHandler & PHInherited & {
	_init: (self: PHInternal) -> (),

	_onTilt: (self: PHInternal, angle: number) -> (),
}
export type PHInherited = {
	_className: string,
	_charControllerType: string,

	_trove: Trove.Trove,

	_isAlive: boolean,

	_onCharacterAdded: (self: PHInternal, character: Model) -> (),
	_onCharacterRemoving: (self: PHInternal) -> (),

	_onDied: (self: PHInternal) -> (),
}

-- Remote folder reference
local Remotes = ReplicatedStorage.Remotes

--[=[
    A PlayerHandler is an abstract class for handling a player's CharacterController.
	It stores each PlayerHandler to be accessed by other classes.
	The base class handles tilt data and character states.
]=]
local PlayerHandler = {
	_handlers = {} :: { [number]: PlayerHandler },
}

local PHPublicMethods = {}
local PHPrivateMethods = {}

--[=[
    Constructs a PlayerHandler for the given player.
    @param player Player -- The player instance.
    @return PlayerHandler
]=]
function PlayerHandler.new(instance: Player): PlayerHandler
	local self = setmetatable({} :: PHInternal, { __index = CreateMultiIndex(PHPublicMethods, PHPrivateMethods) })

	self.Instance = instance

	self:_init()

	return self
end

--[=[
    Returns the PlayerHandler for the given player.
    @param player Player -- The player instance.
    @return PlayerHandler?
]=]
function PlayerHandler.GetHandlerFromPlayer(player: Player): PlayerHandler?
	return PlayerHandler._handlers[player.UserId]
end

--[=[
    Destroys the PlayerHandler, cleaning up any resources.
]=]
function PHPublicMethods.Destroy(self: PlayerHandler): ()
	(self :: PHInternal)._trove:Clean()
end

--[=[
    Returns whether the PlayerHandler is the given class.
    @param className string -- The class name to check
	@return boolean -- Whether the PlayerHandler is the given class.
]=]
function PHPublicMethods.IsA(self: PlayerHandler, className: string): boolean
	return (self :: PHInternal)._className == className
end

function PHPrivateMethods._init(self: PHInternal): ()
	self._trove = Trove.new()

	-- Connect character events
	self._trove:Connect(self.Instance.CharacterAdded, function(character: Model)
		self:_onCharacterAdded(character)
	end)
	self._trove:Connect(self.Instance.CharacterRemoving, function()
		self:_onCharacterRemoving()
	end)

	-- Add the handler to the handlers table and remove it when it's destroyed
	PlayerHandler._handlers[self.Instance.UserId] = self
	self._trove:Add(function()
		PlayerHandler._handlers[self.Instance.UserId] = nil
	end)
end

function PHPrivateMethods._onCharacterAdded(self: PHInternal, character: Model): ()
	-- By default, the primary part of a R6 character is the Head, so we need to set it to the HumanoidRootPart
	character.PrimaryPart = character:FindFirstChild("HumanoidRootPart") :: BasePart

	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		self:_onDied()
	end)

	self._isAlive = true

	-- Tell the client to construct its character controller
	Remotes.Character.Spawn:FireClient(self.Instance, self._charControllerType, character)
end
function PHPrivateMethods._onCharacterRemoving(self: PHInternal): ()
	if self._isAlive then
		self:_onDied()
	end
end

function PHPrivateMethods._onDied(self: PHInternal): ()
	self._isAlive = false
end

function PHPrivateMethods._onTilt(self: PHInternal, angle: number): ()
	if not self._isAlive then
		warn(string.format("%s tried to tilt while they were not alive", self.Instance.Name))
		return
	end

	Remotes.Character.Tilt:FireAllClients(self.Instance, angle)
end

PlayerHandler.InheritedMethods = {
	Destroy = PHPublicMethods.Destroy,
	_init = PHPrivateMethods._init,
	_onCharacterAdded = PHPrivateMethods._onCharacterAdded,
	_onCharacterRemoving = PHPrivateMethods._onCharacterRemoving,
	_onDied = PHPrivateMethods._onDied,
}

--[[
    Instad of having each PlayerHandler listen to each remote event, it is more efficient to listen to them once
    and then call the appropriate method on the appropiate handler.
    We can also use this to validate the arguments passed by each client to the remote events.
]]
do
	local function onTilt(player: Player, angle: number)
		if typeof(angle) ~= "number" then
			warn(string.format("%s passed an invalid argument: Expected number for angle", player.Name))
			return
		end

		local handler = PlayerHandler.GetHandlerFromPlayer(player)
		if not handler then
			warn(string.format("%s's RoundPlayerHandler not found", player.Name))
			return
		end
		PHPrivateMethods._onTilt(handler :: PHInternal, angle)
	end

	Remotes.Character.Tilt.OnServerEvent:Connect(onTilt)
end

return PlayerHandler
