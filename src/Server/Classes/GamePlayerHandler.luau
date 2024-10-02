--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- External dependencies
local Grid = require(ReplicatedStorage.Grid)

local Trove = require(ReplicatedStorage.Packages.Trove)

local Config = ReplicatedStorage.Config
local GetHammerConfig = require(Config.GetHammerConfig)
local GetSlingshotConfig = require(Config.GetSlingshotConfig)

local Utility = ReplicatedStorage.Utility
local CreateMultiIndex = require(Utility.CreateMultiIndex)
local FindFirstChildWithTag = require(Utility.FindFirstChildWithTag)

export type GamePlayerHandler = {
	Instance: Player, -- The player instance

	Destroy: (self: GamePlayerHandler) -> (),
}
type GPHInternal = GamePlayerHandler & {
	_trove: Trove.Trove,

	_isAlive: boolean,

	_backpack: Backpack,

	_toolJoint: Motor6D,

	_tools: {
		Hammer: Model,
		Slingshot: Model,
	},
	_curTool: Model?,

	_configs: {
		Hammer: GetHammerConfig.Config,
		Slingshot: GetSlingshotConfig.Config,
	},

	_kickOffenses: number,

	_lastPlaceBlockTick: number,
	_lastDeleteBlockTick: number,

	_init: (self: GPHInternal) -> (),

	_onCharacterAdded: (self: GPHInternal, character: Model) -> (),
	_onCharacterAppearanceLoaded: (self: GPHInternal, character: Model) -> (),
	_onCharacterRemoving: (self: GPHInternal) -> (),

	_onDied: (self: GPHInternal) -> (),

	_onEquipTool: (self: GPHInternal, toolType: string) -> (),
	_onUnequip: (self: GPHInternal) -> (),

	_onTilt: (self: GPHInternal, angle: number) -> (),

	_onPlaceBlock: (self: GPHInternal, placePos: Vector3) -> (),
	_onDeleteBlock: (self: GPHInternal, targetBlock: BasePart) -> (),
}

--[=[
	Damages the block by the given amount.
	If the block's health reaches 0, it is destroyed.
	@param block BasePart -- The block to damage
	@param damage number -- The amount of damage to deal
]=]
local function DamageBlock(block: BasePart, damage: number)
	local health = block:FindFirstChild("Health") :: NumberValue
	local maxHealth = block:FindFirstChild("MaxHealth") :: NumberValue
	health.Value -= damage
	if health.Value > 0 then
		block.Transparency = 0.5 * (1 - (health.Value / maxHealth.Value))
	else
		block:Destroy()
	end
end

-- Constants
local MAX_KICK_OFFENSES = 3 -- Maximum offenses before kicking the player
local KICK_OFFENSE_LIFETIME = 60 -- Time (in seconds) before reducing offenses

local MAX_ORIGIN_ERROR = 4 -- Maximum error (in studs) for origin calculations
local MAX_RPM_ERROR = 0.05 -- Maximum error (in seconds) for RPM calculations

-- Workspace references
local Blocks = Workspace:WaitForChild("Blocks")

-- ReplicatedStorage references
local Effects = ReplicatedStorage.Effects
local Remotes = ReplicatedStorage.Remotes

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
	-- Get the player's backpack
	self._backpack = self.Instance:FindFirstChildOfClass("Backpack") :: Backpack

	-- By default, the primary part of a R6 character is the Head, so we need to set it to the HumanoidRootPart
	character.PrimaryPart = character:FindFirstChild("HumanoidRootPart") :: BasePart

	-- Create a Motor6D to attach tools to the character
	local toolJoint = Instance.new("Motor6D")
	toolJoint.Name = "ToolJoint"
	toolJoint.Part0 = character:FindFirstChild("Torso") :: BasePart
	toolJoint.Parent = toolJoint.Part0
	self._toolJoint = toolJoint

	-- Find the tools in the character's backpack
	local hammer = FindFirstChildWithTag(self._backpack, "Hammer")
	if not (hammer and hammer:IsA("Model")) then
		warn(string.format("%s's Backpack does not have a Hammer", self.Instance.Name))
		return
	end
	local slingshot = FindFirstChildWithTag(self._backpack, "Slingshot")
	if not (slingshot and slingshot:IsA("Model")) then
		warn(string.format("%s's Backpack does not have a Slingshot", self.Instance.Name))
		return
	end
	self._tools = {
		Hammer = hammer,
		Slingshot = slingshot,
	}

	-- Get the configurations for the tools
	local hammerConfiguration = hammer:FindFirstChildOfClass("Configuration")
	if not hammerConfiguration then
		warn(string.format("%s's Hammer does not have a Configuration", self.Instance.Name))
		return
	end
	local slingshotConfiguration = slingshot:FindFirstChildOfClass("Configuration")
	if not slingshotConfiguration then
		warn(string.format("%s's Slingshot does not have a Configuration", self.Instance.Name))
		return
	end
	self._configs = {
		Hammer = GetHammerConfig(hammerConfiguration),
		Slingshot = GetSlingshotConfig(slingshotConfiguration),
	}

	self._kickOffenses = 0

	self._lastPlaceBlockTick = 0
	self._lastDeleteBlockTick = 0

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
	if not self._isAlive then
		warn(string.format("%s tried to equip a tool while they were not alive", self.Instance.Name))
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
		self._curTool.Parent = self._backpack
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
	self._curTool.Parent = self._backpack
	self._curTool = nil
end

function GPHPrivateMethods._onTilt(self: GPHInternal, angle: number): ()
	if not self._isAlive then
		warn(string.format("%s tried to tilt while they were not alive", self.Instance.Name))
		return
	end

	Remotes.Tilt:FireAllClients(self.Instance, angle)
end

function GPHPrivateMethods._onPlaceBlock(self: GPHInternal, placePos: Vector3): ()
	if not self._isAlive then
		warn(string.format("%s tried to place a block while they were not alive", self.Instance.Name))
		return
	end

	-- Ensure the position is snapped to the grid
	if placePos ~= Grid.SnapPosition(placePos) then
		warn(string.format("%s tried to place a block at an invalid position", self.Instance.Name))
		return
	end

	local tick = os.clock()
	-- Check if block placement is too fast based on the tool's RPM
	print(tick - self._lastPlaceBlockTick)
	if tick - self._lastPlaceBlockTick < (60 / self._configs.Hammer.PlaceRPM) - MAX_RPM_ERROR then
		warn(string.format("%s tried to place a block too quickly", self.Instance.Name))

		if self._kickOffenses == MAX_KICK_OFFENSES then
			self.Instance:Kick("You were kicked for spamming block placement")
			return
		end

		self._kickOffenses += 1
		task.delay(KICK_OFFENSE_LIFETIME, function()
			self._kickOffenses -= 1
		end)

		return
	end

	local character = self.Instance.Character :: Model
	-- Check if the block placement is too far from the player's character
	if (character:GetPivot().Position - placePos).Magnitude > self._configs.Hammer.MaxDistance + MAX_ORIGIN_ERROR then
		warn(string.format("%s tried to place a block too far away", self.Instance.Name))
		return
	end

	local overlapSize = Vector3.new(Grid.SIZE, Grid.SIZE, Grid.SIZE) / 2

	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = { character }
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude

	-- Check if the block placement area is already occupied
	if #Workspace:GetPartBoundsInBox(CFrame.new(placePos), overlapSize, overlapParams) > 0 then
		warn(string.format("%s tried to place a block in an occupied area", self.Instance.Name))
		return
	end

	-- Place the block
	local block: BasePart = Effects.Hammer.Block:Clone()
	block.Color = self.Instance.TeamColor.Color
	block.Position = placePos
	block.Parent = Blocks

	self._lastPlaceBlockTick = tick
end
function GPHPrivateMethods._onDeleteBlock(self: GPHInternal, targetBlock: BasePart)
	if not self._isAlive then
		warn(string.format("%s tried to delete a block while they were not alive", self.Instance.Name))
		return
	end

	local tick = os.clock()
	-- Check if block deletion is too fast based on the tool's RPM
	if tick - self._lastDeleteBlockTick < (60 / self._configs.Hammer.DeleteRPM) - MAX_RPM_ERROR then
		warn(string.format("%s tried to delete a block too quickly", self.Instance.Name))

		if self._kickOffenses == MAX_KICK_OFFENSES then
			self.Instance:Kick("You were kicked for spamming block deletion")
			return
		end

		self._kickOffenses += 1
		task.delay(KICK_OFFENSE_LIFETIME, function()
			self._kickOffenses -= 1
		end)

		return
	end

	local charPos = (self.Instance.Character :: Model):GetPivot().Position
	-- Check if the block deletion is too far from the player's character
	if (charPos - targetBlock.Position).Magnitude > self._configs.Hammer.MaxDistance + MAX_ORIGIN_ERROR then
		warn(string.format("%s tried to delete a block too far away", self.Instance.Name))
		return
	end

	-- Delete the block
	DamageBlock(targetBlock, self._configs.Hammer.Damage)

	self._lastDeleteBlockTick = tick
end

--[[
    Instad of having each GamePlayerHandler listen to each remote event, it is more efficient to listen to them once
    and then call the appropriate method on the appropiate handler.
    We can also use this to validate the arguments passed by each client to the remote events.
]]
do
	-- Character RemoteEvents
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

	-- Hammer RemoteEvents
	local function onPlaceBlock(player: Player, placePos: Vector3)
		if typeof(placePos) ~= "Vector3" then
			warn(string.format("%s passed an invalid argument: Expected Vector3 for placePos", player.Name))
			return
		end

		local handler = GamePlayerHandler._handlers[player.UserId]
		if not handler then
			warn(string.format("%s's GamePlayerHandler not found", player.Name))
			return
		end
		handler:_onPlaceBlock(placePos)
	end
	local function onDelteBlock(player: Player, targetBlock: BasePart)
		if typeof(targetBlock) ~= "Instance" or not targetBlock:IsA("BasePart") then
			warn(string.format("%s passed an invalid argument: Expected BasePart for targetBlock", player.Name))
			return
		end

		local handler = GamePlayerHandler._handlers[player.UserId]
		if not handler then
			warn(string.format("%s's GamePlayerHandler not found", player.Name))
			return
		end
		handler:_onDeleteBlock(targetBlock)
	end

	Remotes.EquipTool.OnServerEvent:Connect(onEquipTool)
	Remotes.Unequip.OnServerEvent:Connect(onUnequip)
	Remotes.Tilt.OnServerEvent:Connect(onTilt)

	Remotes.Hammer.PlaceBlock.OnServerEvent:Connect(onPlaceBlock)
	Remotes.Hammer.DeleteBlock.OnServerEvent:Connect(onDelteBlock)
end

return GamePlayerHandler
