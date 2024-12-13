--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- External dependencies
local Trove = require(ReplicatedStorage.Packages.Trove)

-- Server modules
local ServerTypes = require(ServerScriptService.Server.ServerTypes)

type PlayerHandler = ServerTypes.PlayerHandler
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

-- Constants
local RESPAWN_TIME = 5

-- Remote events folder
local Remotes = ReplicatedStorage.Remotes

local PlayerHandler = {}

local PHPublicMethods = {}
local PHProtectedMethods = {}

PlayerHandler.PublicMethods = PHPublicMethods
PlayerHandler.ProtectedMethods = PHProtectedMethods

function PHPublicMethods.Destroy(self: PHInternal): ()
	self._trove:Clean()
end

function PHPublicMethods.IsA(self: PHInternal, className: string): boolean
	return self._className == className
end

function PHPublicMethods.OnTilt(self: PHInternal, angle: number): ()
	if not self._isAlive then
		warn(string.format("[PlayerHandler.OnTilt]: %s is not alive", self.Instance.Name))
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

	self._trove:Add(task.delay(RESPAWN_TIME, function()
		self.Instance:LoadCharacter()
	end))
end

return PlayerHandler
