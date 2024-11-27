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

	_onTilt: (self: PHInternal, angle: number) -> (),
}

-- Remote folder reference
local Remotes = ReplicatedStorage.Remotes

--[=[
    A PlayerHandler is an abstract class for handling a player's CharacterController.
	It stores each PlayerHandler to be accessed by other classes.
	The base class handles tilt data and character states.
]=]
local PlayerHandler = {}

local PHPublicMethods = {}
local PHProtectedMethods = {}

PlayerHandler.PublicMethods = PHPublicMethods
PlayerHandler.ProtectedMethods = PHProtectedMethods

--[=[
    Destroys the PlayerHandler, cleaning up any resources.
]=]
function PHPublicMethods.Destroy(self: PHInternal): ()
	self._trove:Clean()
end

--[=[
	Returns whether the PlayerHandler is an instance of the given class.
	@param className string -- The class name to check against.
	@return boolean -- Whether the PlayerHandler is an instance of the given class.
]=]
function PHPublicMethods.IsA(self: PHInternal, className: string): boolean
	return self._className == className
end

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
	self._trove:AttachToInstance(self.Instance) -- Destroy the handler if the player leaves

	-- Connect character events
	self._trove:Connect(self.Instance.CharacterAdded, function(character: Model)
		self:_onCharacterAdded(character)
	end)
	self._trove:Connect(self.Instance.CharacterRemoving, function()
		self:_onCharacterRemoving()
	end)

	-- Load the player's character
	self.Instance:LoadCharacter()
end

function PHProtectedMethods._onCharacterAdded(self: PHInternal, character: Model): ()
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
function PHProtectedMethods._onCharacterRemoving(self: PHInternal): ()
	if self._isAlive then
		self:_onDied()
	end
end

function PHProtectedMethods._onDied(self: PHInternal): ()
	self._isAlive = false
end

return PlayerHandler
