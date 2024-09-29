--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- External dependencies
local Trove = require(ReplicatedStorage.Packages.Trove)
local Utility = ReplicatedStorage.Utility
local CreateMultiIndex = require(Utility.CreateMultiIndex)
local FindFirstChildWithTag = require(Utility.FindFirstChildWithTag)

-- RemoteEvents folder
local Remotes = ReplicatedStorage.Remotes

export type GamePlayerHandler = {
	Instance: Player,

	Destroy: (self: GamePlayerHandler) -> (),
}
type GPHInternal = GamePlayerHandler & {
	_trove: Trove.Trove,

	_isAlive: boolean,

	_toolJoint: Motor6D,

	_tools: { [string]: Model },
	_curTool: Model?,

	_init: (self: GPHInternal) -> (),

	_onCharacterAdded: (self: GPHInternal, character: Model) -> (),
	_onCharacterAppearanceLoaded: (self: GPHInternal, character: Model) -> (),
	_onCharacterRemoving: (self: GPHInternal) -> (),

	_onDied: (self: GPHInternal) -> (),

	_onEquipTool: (self: GPHInternal, toolType: string) -> (),
	_onUnequip: (self: GPHInternal) -> (),

	_onTilt: (self: GPHInternal, angle: number) -> (),
}

local GamePlayerHandler = {
	_handlers = {} :: { [number]: GPHInternal },
}

local GPHPublicMethods = {}
local GPHPrivateMethods = {}

--[=[
    Gets the GamePlayerHandler of the given player
    @param player The player to get the handler of
    @returns GamePlayerHandler
]=]
function GamePlayerHandler.GetHandlerFromPlayer(player: Player): GamePlayerHandler?
	return GamePlayerHandler._handlers[player.UserId]
end

--[=[
    Constructs a GamePlayerHandler for the given player.
    @param instance Player -- The player instance
    @returns GamePlayerHandler
]=]
function GamePlayerHandler.new(instance: Player): GamePlayerHandler
	local self = setmetatable({} :: GPHInternal, { __index = CreateMultiIndex(GPHPublicMethods, GPHPrivateMethods) })

	self.Instance = instance

	self:_init()

	return self
end

--[=[
    Destroys the GamePlayerHandler, cleaning up any resources.
]=]
function GPHPublicMethods.Destroy(self: GamePlayerHandler): ()
	(self :: GPHInternal)._trove:Clean()
end

function GPHPrivateMethods._init(self: GPHInternal): ()
	self._trove = Trove.new()

	-- Connect character events
	self._trove:Connect(self.Instance.CharacterAdded, function(character: Model)
		self:_onCharacterAdded(character)
	end)
	self._trove:Connect(self.Instance.CharacterAppearanceLoaded, function(character: Model)
		self:_onCharacterAppearanceLoaded(character)
	end)
	self._trove:Connect(self.Instance.CharacterRemoving, function()
		self:_onCharacterRemoving()
	end)

	-- Add the handler to the handlers table and remove it when it's destroyed
	GamePlayerHandler._handlers[self.Instance.UserId] = self
	self._trove:Add(function()
		GamePlayerHandler._handlers[self.Instance.UserId] = nil
	end)
end

function GPHPrivateMethods._onCharacterAdded(self: GPHInternal, character: Model): ()
	-- By default, the primary part of a R6 character is the Head, so we need to set it to the HumanoidRootPart
	character.PrimaryPart = character:FindFirstChild("HumanoidRootPart") :: BasePart

	-- Create a Motor6D to attach tools to the character
	local toolJoint = Instance.new("Motor6D")
	toolJoint.Name = "ToolJoint"
	toolJoint.Part0 = character:FindFirstChild("Torso") :: BasePart
	toolJoint.Parent = toolJoint.Part0
	self._toolJoint = toolJoint

	-- Find the tools in the character's backpack
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
function GPHPrivateMethods._onCharacterAppearanceLoaded(_, character: Model): ()
	-- Disable CanQuery for all accessories to prevent them from being queried by projectiles
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") then
			(child:FindFirstChild("Handle") :: BasePart).CanQuery = false
		end
	end
end
function GPHPrivateMethods._onCharacterRemoving(self: GPHInternal): ()
	if self._isAlive then
		self:_onDied()
	end
end

function GPHPrivateMethods._onDied(self: GPHInternal): ()
	self._isAlive = false
end

function GPHPrivateMethods._onEquipTool(self: GPHInternal, toolType: string): ()
	-- Players can only equip tools if they are alive
	if not self._isAlive then
		warn(string.format("%s is not alive", self.Instance.Name))
		return
	end

	-- Make sure the player has the tool they are trying to equip
	local tool = self._tools[toolType]
	if not tool then
		warn(string.format("%s does not have a %s", self.Instance.Name, toolType))
		return
	end

	-- Parent the previous tool, if any, to the player's backpack
	if self._curTool then
		self._curTool.Parent = self.Instance.Backpack
	end

	-- Attach the new tool to the player's character
	self._toolJoint.Part1 = tool.PrimaryPart
	tool.Parent = self.Instance.Character
	self._curTool = tool

	-- Make sure the character's arm tilt is replicated after equipping a tool
	Remotes.Tilt:FireAllClients(self.Instance)
end
function GPHPrivateMethods._onUnequip(self: GPHInternal): ()
	if not self._curTool then
		return
	end

	-- Detach the tool from the player's character and move it to the backpack
	self._toolJoint.Part1 = nil
	self._curTool.Parent = self.Instance.Backpack
	self._curTool = nil
end

function GPHPrivateMethods._onTilt(self: GPHInternal, angle: number)
	if not self._isAlive then
		warn(string.format("%s is not alive", self.Instance.Name))
		return
	end

	Remotes.Tilt:FireAllClients(self.Instance, angle)
end

--[[
    Instad of having each GamePlayerHandler listen to each remote event, it is more efficient to listen to them once
    and then call the appropriate method on the appropiate handler.
    We can also use this to validate the arguments passed by each client to the remote events.
]]
do
	local function onEquipTool(player: Player, toolType: string)
		if typeof(toolType) ~= "string" then
			warn(string.format("%s passed an invalid argument: Expected string for toolType", player.Name))
			return
		end

		local handler = GamePlayerHandler._handlers[player.UserId]
		if not handler then
			warn(string.format("%s's GamePlayerHandler not found", player.Name))
			return
		end
		handler:_onEquipTool(toolType)
	end
	local function onUnequip(player: Player)
		local handler = GamePlayerHandler._handlers[player.UserId]
		if not handler then
			warn(string.format("%s's GamePlayerHandler not found", player.Name))
			return
		end
		handler:_onUnequip()
	end

	local function onTilt(player: Player, angle: number)
		if typeof(angle) ~= "number" then
			warn(string.format("%s passed an invalid argument: Expected number for angle", player.Name))
			return
		end

		local handler = GamePlayerHandler._handlers[player.UserId]
		if not handler then
			warn(string.format("%s's GamePlayerHandler not found", player.Name))
			return
		end
		handler:_onTilt(angle)
	end

	Remotes.EquipTool.OnServerEvent:Connect(onEquipTool)
	Remotes.Unequip.OnServerEvent:Connect(onUnequip)
	Remotes.Tilt.OnServerEvent:Connect(onTilt)
end

return GamePlayerHandler
