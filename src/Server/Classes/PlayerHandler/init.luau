--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- External dependencies
local Trove = require(ReplicatedStorage.Packages.Trove)

-- Server modules
local Types = require(ServerScriptService.Server.Types)

type PlayerHandler = Types.PlayerHandler
type PHInternal = PlayerHandler & PHProtected
export type PHProtected = {
	_className: string,
	_charControllerType: string,

	_trove: Trove.Trove,

	_isAlive: boolean,

	_init: (self: PHInternal, instance: Player) -> (),

	_onCharacterAdded: (self: PHInternal, character: Model) -> (),
	_onCharacterRemoving: (self: PHInternal) -> (),

	_onDied: (self: PHInternal) -> (),
}

-- Remote events folder
local Remotes = ReplicatedStorage.Remotes

--[=[
	PlayerHandler provides a foundational implementation for managing a player's lifecycle, such as character spawning, removal, and tilt replication.

	This class is intended to be extended by subclasses to provide game-specific behaviors and functionalities.
	Subclasses must define their own `_charControllerType` and override or extend protected methods to implement specific logic.

	Responsibilities:
	- Handle character addition and removal for players.
	- Replicate player tilt to other clients.
	- Provide lifecycle hooks for subclasses to customize behavior.

	Notes:
	- This class should not be instantiated directly.
	- Subclasses must define `_charControllerType` to specify the type of character controller to spawn on the client.
]=]
local PlayerHandler = {}

local PHPublicMethods = {}
local PHProtectedMethods = {}

PlayerHandler.PublicMethods = PHPublicMethods
PlayerHandler.ProtectedMethods = PHProtectedMethods

--[=[
	Destroys the player handler, cleaning up all connections and resources used by it.
]=]
function PHPublicMethods.Destroy(self: PHInternal): ()
	self._trove:Clean()
end

--[=[
	Checks if the player handler is an instance of the given class name.
	@param className -- The class name to check against.
	@return boolean -- True if the instance is of the given class name, false otherwise.
]=]
function PHPublicMethods.IsA(self: PHInternal, className: string): boolean
	return self._className == className
end

--[=[
	Replicates the client's given tilt angle to all other clients.
	@param angle -- The tilt angle to replicate.
]=]
function PHPublicMethods.OnTilt(self: PHInternal, angle: number): ()
	if not self._isAlive then
		warn(string.format("%s tried to tilt while they were not alive", self.Instance.Name))
		return
	end

	Remotes.Character.Tilt:FireAllClients(self.Instance, angle)
end

function PHProtectedMethods._init(self: PHInternal, instance: Player): ()
	self._trove = Trove.new()

	self.Instance = instance

	self._trove:Connect(self.Instance.CharacterAdded, function(character: Model)
		self:_onCharacterAdded(character)
	end)
	self._trove:Connect(self.Instance.CharacterRemoving, function()
		self:_onCharacterRemoving()
	end)

	self.Instance:LoadCharacter()
end

function PHProtectedMethods._onCharacterAdded(self: PHInternal, character: Model): ()
	-- By default, the primary part of a R6 character is the head, so we need to set it to the humanoid root part
	character.PrimaryPart = character:FindFirstChild("HumanoidRootPart") :: BasePart

	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		self:_onDied()
	end)

	self._isAlive = true

	-- Tell the client to construct its corresponding character controller
	Remotes.Character.Spawn:FireClient(self.Instance, self._charControllerType, character)
end
function PHProtectedMethods._onCharacterRemoving(self: PHInternal): ()
	if self._isAlive then
		self:_onDied()
	end
end

function PHProtectedMethods._onDied(self: PHInternal): ()
	self._isAlive = false
end

return PlayerHandler
