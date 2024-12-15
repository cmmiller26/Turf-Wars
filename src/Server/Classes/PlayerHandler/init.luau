--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- External dependencies
local SharedTypes = require(ReplicatedStorage.SharedTypes)
local Trove = require(ReplicatedStorage.Packages.Trove)

-- Server modules
local ServerTypes = require(ServerScriptService.Server.ServerTypes)

type PlayerHandler = ServerTypes.PlayerHandler
export type PHProtected = {
	_characterType: SharedTypes.CharacterType,

	_trove: Trove.Trove,

	_isAlive: boolean,

	_init: (self: PHInternal, instance: Player) -> (),

	_onCharacterAdded: (self: PHInternal, character: Model) -> (),
	_onCharacterRemoving: (self: PHInternal) -> (),

	_onDied: (self: PHInternal) -> (),
}
type PHInternal = PlayerHandler & PHProtected

-- Constants
local RESPAWN_TIME = 5

-- Remote events folder
local Remotes = ReplicatedStorage.Remotes

--[=[
	The [Player] who is being handled by the player handler.
	@prop Instance Player
	@within PlayerHandler
]=]

--[=[
	The [CharacterType] of the [CharacterController] associated with the player handler.
	@prop _characterType CharacterType
	@private
	@within PlayerHandler
]=]
--[=[
	The [Trove] used to manage the player handler's connections and resources.
	@prop _trove Trove
	@private
	@within PlayerHandler
]=]
--[=[
	Whether the player handler's character is alive.
	@prop _isAlive boolean
	@private
	@within PlayerHandler
]=]

--[=[
	PlayerHandler is an abstract base class for managing a client's [CharacterController].
	It provides core functionality for handling the lifecycle of the client's character, while allowing subclasses to handle specific remote events and character logic.
	This class cannot be instantiated directly and is intended to be extended by subclasses.
	@class PlayerHandler
	@server
	@tag Abstract
]=]
local PlayerHandler = {}

local PHPublicMethods = {}
local PHPrivateMethods = {}

PlayerHandler.PublicMethods = PHPublicMethods
PlayerHandler.PrivateMethods = PHPrivateMethods

--[=[
	Cleans up all connections used by the player handler.
	@method Destroy
	@within PlayerHandler
]=]
function PHPublicMethods.Destroy(self: PHInternal): ()
	self._trove:Clean()
end

--[=[
	Returns whether the player handler is of the given [CharacterType].
	@method IsCharacterType
	@param characterType CharacterType
	@return boolean
	@within PlayerHandler
]=]
function PHPublicMethods.IsCharacterType(self: PHInternal, characterType: SharedTypes.CharacterType): boolean
	return self._characterType == characterType
end

--[=[
	Handles a tilt event from the client, sending the tilt angle to all clients.
	@method OnTilt
	@param angle number
	@within PlayerHandler
]=]
function PHPublicMethods.OnTilt(self: PHInternal, angle: number): ()
	if not self._isAlive then
		warn(string.format("[PlayerHandler:OnTilt]: %s is not alive", self.Instance.Name))
		return
	end

	Remotes.Character.Tilt:FireAllClients(self.Instance, angle)
end

--[=[
	Initializes the player handler with the given [Player], connecting to its character events.
	@method _init
	@param instance Player
	@private
	@within PlayerHandler
]=]
function PHPrivateMethods._init(self: PHInternal, instance: Player): ()
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

--[=[
	Handles the loading of the client's character, telling them to construct their character controller.
	@method _onCharacterAdded
	@param character Model
	@private
	@within PlayerHandler
]=]
function PHPrivateMethods._onCharacterAdded(self: PHInternal, character: Model): ()
	-- By default, the primary part of a R6 character is the head, so we need to set it to the humanoid root part
	character.PrimaryPart = character:FindFirstChild("HumanoidRootPart") :: BasePart

	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		self:_onDied()
	end)

	self._isAlive = true

	-- Tell the client to construct its corresponding character controller
	Remotes.Character.Spawn:FireClient(self.Instance, self._characterType, character)
end

--[=[
	Handles the removal of the client's character, ensuring `:_onDied` has been called.
	@method _onCharacterRemoving
	@private
	@within PlayerHandler
]=]
function PHPrivateMethods._onCharacterRemoving(self: PHInternal): ()
	if self._isAlive then
		self:_onDied()
	end
end

--[=[
	Handles character death, marking the player handler as dead and respawning the character.
	@method _onDied
	@private
	@within PlayerHandler
]=]
function PHPrivateMethods._onDied(self: PHInternal): ()
	self._isAlive = false

	self._trove:Add(task.delay(RESPAWN_TIME, function()
		self.Instance:LoadCharacter()
	end))
end

return PlayerHandler
