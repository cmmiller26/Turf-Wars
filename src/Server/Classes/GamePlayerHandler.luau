--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)
local FindFirstChildWithTag = require(ReplicatedStorage.Utility.FindFirstChildWithTag)

export type GamePlayerHandler = {
	Instance: Player,

	Destroy: (self: GamePlayerHandler) -> (),
}
type self = GamePlayerHandler & {
	_trove: Trove.Trove,

	_isAlive: boolean,

	_toolJoint: Motor6D,

	_tools: {
		Hammer: Model,
		Slingshot: Model,
	},
	_curTool: Model?,

	_init: (self: self) -> (),

	_onEquipTool: (self: GamePlayerHandler, toolType: string) -> (),
	_onUnequip: (self: GamePlayerHandler) -> (),

	_onTilt: (self: GamePlayerHandler, angle: number) -> (),

	_onCharacterAdded: (self: self, character: Model) -> (),
	_onCharacterAppearanceLoaded: (self: self, character: Model) -> (),
	_onCharacterRemoving: (self: self) -> (),

	_onDied: (self: self) -> (),
}

local Remotes = ReplicatedStorage.Remotes.Game

local GamePlayerHandler = {}
GamePlayerHandler.__index = GamePlayerHandler

local playerHandlers: { [number]: self } = {}

function GamePlayerHandler.new(instance: Player): GamePlayerHandler
	local self = setmetatable({} :: self, GamePlayerHandler)

	self.Instance = instance

	self:_init()

	return self
end
function GamePlayerHandler.Destroy(self: self)
	self._trove:Clean()
end

function GamePlayerHandler._init(self: self)
	self._trove = Trove.new()

	self._trove:Connect(self.Instance.CharacterAdded, function(character: Model)
		self:_onCharacterAdded(character)
	end)
	self._trove:Connect(self.Instance.CharacterAppearanceLoaded, function(character: Model)
		self:_onCharacterAppearanceLoaded(character)
	end)
	self._trove:Connect(self.Instance.CharacterRemoving, function()
		self:_onCharacterRemoving()
	end)

	playerHandlers[self.Instance.UserId] = self
	self._trove:Add(function()
		playerHandlers[self.Instance.UserId] = nil
	end)
end

function GamePlayerHandler._onEquipTool(self: self, toolType: string)
	if not self._isAlive then
		warn(string.format("%s is not alive", self.Instance.Name))
		return
	end

	local tool = self._tools[toolType] :: Model
	if not tool then
		warn(string.format("%s does not have a %s", self.Instance.Name, toolType))
		return
	end

	if self._curTool then
		self._curTool.Parent = self.Instance.Backpack
	end

	self._toolJoint.Part1 = tool.PrimaryPart
	tool.Parent = self.Instance.Character
	self._curTool = tool

	-- Make sure the character's arm tilt is replicated after equipping a tool
	Remotes.Tilt:FireAllClients(self.Instance)
end
function GamePlayerHandler._onUnequip(self: self)
	if not self._curTool then
		return
	end

	self._toolJoint.Part1 = nil
	self._curTool.Parent = self.Instance.Backpack
	self._curTool = nil
end

function GamePlayerHandler._onTilt(self: self, angle: number)
	if not self._isAlive then
		warn(string.format("%s is not alive", self.Instance.Name))
		return
	end

	Remotes.Tilt:FireAllClients(self.Instance, angle)
end

function GamePlayerHandler._onCharacterAdded(self: self, character: Model)
	character.PrimaryPart = character:FindFirstChild("HumanoidRootPart") :: BasePart

	local toolJoint = Instance.new("Motor6D")
	toolJoint.Name = "ToolJoint"
	toolJoint.Part0 = character:FindFirstChild("Torso") :: BasePart
	toolJoint.Parent = toolJoint.Part0
	self._toolJoint = toolJoint

	local hammer = FindFirstChildWithTag(self.Instance.Backpack, "Hammer")
	if not (hammer and hammer:IsA("Model")) then
		warn(string.format("%s's Backpack does not have a Hammer", self.Instance.Name))
		return
	end
	local slingshot = FindFirstChildWithTag(self.Instance.Backpack, "Slingshot")
	if not (slingshot and slingshot:IsA("Model")) then
		warn(string.format("%s's Backpack does not have a Slingshot", self.Instance.Name))
		return
	end
	self._tools = {
		Hammer = hammer,
		Slingshot = slingshot,
	}

	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		self:_onDied()
	end)

	self._isAlive = true
end
function GamePlayerHandler._onCharacterAppearanceLoaded(_, character: Model)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") then
			(child:FindFirstChild("Handle") :: BasePart).CanQuery = false
		end
	end
end
function GamePlayerHandler._onCharacterRemoving(self: self)
	if self._isAlive then
		self:_onDied()
	end
end

function GamePlayerHandler._onDied(self: self)
	self._isAlive = false
end

do
	local function OnEquipTool(player: Player, toolType: string)
		if typeof(toolType) ~= "string" then
			warn(string.format("%s passed an invalid argument #1: Expected string for toolType", player.Name))
			return
		end

		local playerHandler = playerHandlers[player.UserId]
		if not playerHandler then
			warn(string.format("%s GamePlayerHandler not found", player.Name))
			return
		end
		playerHandler:_onEquipTool(toolType)
	end
	local function OnUnequip(player: Player)
		local playerHandler = playerHandlers[player.UserId]
		if not playerHandler then
			warn(string.format("%s GamePlayerHandler not found", player.Name))
			return
		end
		playerHandler:_onUnequip()
	end
	local function OnTilt(player: Player, angle: number)
		if typeof(angle) ~= "number" then
			warn(string.format("%s passed an invalid argument #1: Expected number for angle", player.Name))
			return
		end

		local playerHandler = playerHandlers[player.UserId]
		if not playerHandler then
			warn(string.format("%s GamePlayerHandler not found", player.Name))
			return
		end
		playerHandler:_onTilt(angle)
	end

	Remotes.EquipTool.OnServerEvent:Connect(OnEquipTool)
	Remotes.Unequip.OnServerEvent:Connect(OnUnequip)
	Remotes.Tilt.OnServerEvent:Connect(OnTilt)
end

return GamePlayerHandler
