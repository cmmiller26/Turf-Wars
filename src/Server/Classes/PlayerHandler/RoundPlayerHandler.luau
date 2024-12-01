--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

-- External dependencies
local Config = ReplicatedStorage.Config
local GetHammerConfig = require(Config.GetHammerConfig)
local GetSlingshotConfig = require(Config.GetSlingshotConfig)

local Utility = ReplicatedStorage.Utility
local CreateMultiIndex = require(Utility.CreateMultiIndex)
local FindFirstChildWithTag = require(Utility.FindFirstChildWithTag)
local Grid = require(ReplicatedStorage.Utility.Grid)
local Physics = require(ReplicatedStorage.Utility.Physics)

-- Server modules
local Server = ServerScriptService.Server
local Types = require(Server.Types)

-- Superclass
local PlayerHandler = require(script.Parent)

type RoundPlayerHandler = Types.RoundPlayerHandler
type RPHInternal = RoundPlayerHandler & PlayerHandler.PHProtected & {
	_backpack: Backpack,

	_combatEnabled: boolean,

	_lastPlaceBlockTick: number,
	_lastDeleteBlockTick: number,

	_projectileRecords: { [number]: ProjectileRecord },
	_lastFireProjectileTick: number,

	_kickOffenses: number,

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

	_addKickOffense: (self: RPHInternal, reason: string) -> (),

	_onCharacterAppearanceLoaded: (self: RPHInternal, character: Model) -> (),
}

--[=[
	A ProjectileRecord holds the information of a fired projectile.
]=]
type ProjectileRecord = {
	Origin: Vector3,
	Direction: Vector3,
	Speed: number,
}

--[=[
	Damages the given block by the given amount.
	If the block's health reaches 0, it is destroyed.
	@param block -- The `BasePart` to damage
	@param damage -- The amount of damage to deal
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

local HEAD_OFFSET = Vector3.new(0, 1.5, 0)

-- Workspace variables
local Blocks = Workspace:WaitForChild("Blocks")

-- Replicated storage variables
local Effects = ReplicatedStorage.Effects
local Remotes = ReplicatedStorage.Remotes

--[=[
    `RoundPlayerHandler` extends `PlayerHandler` to manage player-specific behavior during active game rounds.

    This class handles the player's lifecycle, tool usage, block interactions, projectile firing, and hit registration within a round-based game.
    It provides robust validation to prevent abuse, such as spamming actions or hacking attempts, and ensures that all actions adhere to the game's rules and configurations.

    **Responsibilities:**
    - Manage player tools (e.g., Hammer and Slingshot) and enforce usage rules.
    - Handle block placement and deletion with grid alignment and rate limits.
    - Manage projectile firing, including speed validation and rate limiting.
    - Validate hit registration against server-side projectile records.
    - Implement anti-cheat measures to prevent exploitative behavior.
    - Enable or disable combat for the player as needed.

    **Key Features:**
    - **Rate Limiting:** Prevents spamming actions by enforcing RPM limits.
    - **Position Validation:** Ensures actions occur within acceptable distances.
    - **Offense Tracking:** Tracks offenses and kicks players after repeated violations.
    - **Tool Management:** Handles equipping and unequipping of tools with proper attachment.

    **Notes:**
    - This class should be instantiated for each player during a game round.
    - It relies on configurations for tools, which must be properly set up.
    - All client-provided data is validated server-side to maintain game integrity.
]=]
local RoundPlayerHandler = {}

local RPHPublicMethods = {}
local RPHPrivateMethods = {}

--[=[
	Constructs a round player handler for the given player.
	@param instance -- The `Player` to handle remotes for.
	@return RoundPlayerHandler -- The round player handler instance.
]=]
function RoundPlayerHandler.new(instance: Player): RoundPlayerHandler
	local self = setmetatable({} :: RPHInternal, {
		__index = CreateMultiIndex(
			RPHPublicMethods,
			RPHPrivateMethods,
			PlayerHandler.PublicMethods,
			PlayerHandler.ProtectedMethods
		),
	})

	self:_init(instance)

	return self
end

--[=[
	Sets whether combat is enabled for the player.
	@param enabled -- Whether combat is enabled.
]=]
function RPHPublicMethods.SetCombatEnabled(self: RPHInternal, enabled: boolean): ()
	self._combatEnabled = enabled
end

--[=[
	Handles the player equipping a tool.
	@param toolType -- The type of tool to equip.
]=]
function RPHPublicMethods.OnEquipTool(self: RPHInternal, toolType: string): ()
	if not self._isAlive then
		warn(string.format("%s tried to equip a tool while they were not alive", self.Instance.Name))
		return
	end

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

	-- Make sure the character's shoulders' tilt is replicated after equipping a tool
	Remotes.Character.Tilt:FireAllClients(self.Instance)
end

--[=[
	Handles the player unequipping their tool.
]=]
function RPHPublicMethods.OnUnequip(self: RPHInternal): ()
	if not self._curTool then
		return
	end

	-- Detach the tool from the player's character and move it to the backpack
	self._toolJoint.Part1 = nil
	self._curTool.Parent = self._backpack
	self._curTool = nil
end

--[=[
	Handles the player placing a block at the given position.
	@param placePos -- The position to place the block at.
]=]
function RPHPublicMethods.OnPlaceBlock(self: RPHInternal, placePos: Vector3): ()
	if not self._isAlive then
		warn(string.format("%s tried to place a block while they were not alive", self.Instance.Name))
		return
	end

	if self._curTool ~= self._tools.Hammer then
		warn(string.format("%s tried to place a block without a Hammer equipped", self.Instance.Name))
		return
	end

	-- Ensure the position is snapped to the grid
	if placePos ~= Grid.SnapPosition(placePos) then
		warn(string.format("%s tried to place a block at an invalid position", self.Instance.Name))
		return
	end

	local tick = os.clock()
	-- Check if block placement is too fast based on the tool's RPM
	if tick - self._lastPlaceBlockTick < (60 / self._configs.Hammer.PlaceRPM) - MAX_RPM_ERROR then
		warn(string.format("%s tried to place a block too quickly", self.Instance.Name))
		self:_addKickOffense("spamming block placement")
		return
	end

	local character = self.Instance.Character :: Model
	local charPos = character:GetPivot().Position + HEAD_OFFSET
	-- Check if the block placement is too far from the player's character
	if (charPos - placePos).Magnitude > self._configs.Hammer.MaxDistance + MAX_ORIGIN_ERROR then
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

	local block: BasePart = Effects.Hammer.Block:Clone()
	block.Color = self.Instance.TeamColor.Color
	block.Position = placePos
	block.Parent = Blocks

	self._lastPlaceBlockTick = tick
end

--[=[
	Handles the player deleting the given block.
	@param targetBlock -- The `BasePart` to delete.
]=]
function RPHPublicMethods.OnDeleteBlock(self: RPHInternal, targetBlock: BasePart)
	if not self._isAlive then
		warn(string.format("%s tried to delete a block while they were not alive", self.Instance.Name))
		return
	end

	if self._curTool ~= self._tools.Hammer then
		warn(string.format("%s tried to delete a block without a Hammer equipped", self.Instance.Name))
		return
	end

	local tick = os.clock()
	-- Check if block deletion is too fast based on the tool's RPM
	if tick - self._lastDeleteBlockTick < (60 / self._configs.Hammer.DeleteRPM) - MAX_RPM_ERROR then
		warn(string.format("%s tried to delete a block too quickly", self.Instance.Name))
		self:_addKickOffense("spamming block deletion")
		return
	end

	local charPos = (self.Instance.Character :: Model):GetPivot().Position + HEAD_OFFSET
	-- Check if the block deletion is too far from the player's character
	if (charPos - targetBlock.Position).Magnitude > self._configs.Hammer.MaxDistance + MAX_ORIGIN_ERROR then
		warn(string.format("%s tried to delete a block too far away", self.Instance.Name))
		return
	end

	DamageBlock(targetBlock, self._configs.Hammer.Damage)

	self._lastDeleteBlockTick = tick
end

--[=[
	Handles the player firing a projectile.
	@param origin -- Where the projectile was fired from.
	@param direction -- The direction the projectile was fired in.
	@param speed -- The initial speed of the projectile.
	@param timestamp -- The timestamp of when the projectile was fired.
]=]
function RPHPublicMethods.OnFireProjectile(
	self: RPHInternal,
	origin: Vector3,
	direction: Vector3,
	speed: number,
	timestamp: number
): ()
	if not self._combatEnabled then
		warn(string.format("%s tried to fire a projectile while combat was disabled", self.Instance.Name))
		return
	end

	if not self._isAlive then
		warn(string.format("%s tried to fire a projectile while they were not alive", self.Instance.Name))
		return
	end

	if self._curTool ~= self._tools.Slingshot then
		warn(string.format("%s tried to fire a projectile without a Slingshot equipped", self.Instance.Name))
		return
	end

	if direction == Vector3.zero then
		warn(string.format("%s tried to fire a projectile in an invalid direction", self.Instance.Name))
		return
	end
	direction = direction.Unit

	if speed > self._configs.Slingshot.Projectile.MaxSpeed then
		self.Instance:Kick("You were kicked for firing a projectile at a hacked speed")
		return
	end

	local tick = os.clock()
	-- Check if the timestamp is too far from the current time based on the network ping
	if math.abs(tick - timestamp) > self.Instance:GetNetworkPing() then
		warn(string.format("%s tried to fire a projectile with an invalid timestamp", self.Instance.Name))
		return
	end

	-- Check if projectile firing is too fast based on the tool's RPM
	if tick - self._lastFireProjectileTick < (60 / self._configs.Slingshot.RPM) - MAX_RPM_ERROR then
		warn(string.format("%s tried to fire a projectile too quickly", self.Instance.Name))
		self:_addKickOffense("spamming projectile firing")
		return
	end

	local charPos = (self.Instance.Character :: Model):GetPivot().Position + HEAD_OFFSET
	-- Check if the projectile origin is too far from the player's character
	if (charPos - origin).Magnitude > MAX_ORIGIN_ERROR then
		warn(string.format("%s tried to fire a projectile from an invalid origin", self.Instance.Name))
		return
	end

	local projectileRecord = {
		Origin = origin,
		Direction = direction,
		Speed = speed,
	}
	self._projectileRecords[timestamp] = projectileRecord -- Record the projectile record for hit registration
	task.delay(self._configs.Slingshot.Projectile.Lifetime, function()
		self._projectileRecords[timestamp] = nil -- Remove the record after the projectile's lifetime
	end)

	-- Replicate the projectile information for clients to visualize locally
	Remotes.Tool.Slingshot.FireProjectile:FireAllClients(self.Instance, projectileRecord, self._configs.Slingshot)

	self._lastFireProjectileTick = tick
end

--[=[
	Handles the player registering a hit on a block or character.
	@param hitType -- The type of object that was hit ("Block" or "Character").
	@param hitPart -- The `BasePart` that was hit.
	@param hitTimestamp -- The timestamp of when the hit was registered.
	@param fireTimestamp -- The timestamp of when the projectile was fired.
]=]
function RPHPublicMethods.OnRegisterHit(
	self: RPHInternal,
	hitType: "Block" | "Character",
	hitPart: BasePart,
	hitTimestamp: number,
	fireTimestamp: number
): ()
	if not self._combatEnabled then
		warn(string.format("%s tried to register a hit while combat was disabled", self.Instance.Name))
		return
	end

	local timeSinceFire = hitTimestamp - fireTimestamp
	if timeSinceFire < 0 or timeSinceFire > self._configs.Slingshot.Projectile.Lifetime + MAX_RPM_ERROR then
		warn(string.format("%s tried to register a hit outside the projectile's lifetime", self.Instance.Name))
		return
	end

	local fireRecord = self._projectileRecords[fireTimestamp]
	if not fireRecord then
		warn(string.format("%s tried to register a hit without a projectile record", self.Instance.Name))
		return
	end

	local hitParent = hitPart.Parent
	if not hitParent then
		warn(string.format("%s tried to register a hit on an instance without a parent", self.Instance.Name))
		return
	end
	if hitType == "Block" then
		if hitParent ~= Blocks then
			warn(string.format("%s tried to register a block not in the Blocks folder", self.Instance.Name))
			return
		end
		if hitPart.BrickColor == self.Instance.TeamColor then
			warn(string.format("%s tried to register a hit on a block of their own team", self.Instance.Name))
			return
		end
	elseif hitType == "Character" and not hitParent:FindFirstChildOfClass("Humanoid") then
		warn(string.format("%s tried to register a hit on a character without a Humanoid", self.Instance.Name))
		return
	end

	local position = Physics.CalculatePosition(
		fireRecord.Origin,
		fireRecord.Direction * fireRecord.Speed,
		Vector3.new(0, -self._configs.Slingshot.Projectile.Gravity, 0),
		timeSinceFire
	)
	local maxPositionError = 0.5 * math.max(hitPart.Size.X, hitPart.Size.Y, hitPart.Size.Z) + MAX_ORIGIN_ERROR
	-- Check if the registered hit position is too far from the calculated position
	if (position - hitPart.Position).Magnitude > maxPositionError then
		warn(string.format("%s registered hit position did not match the calculated position", self.Instance.Name))
		return
	end

	local damage = self._configs.Slingshot.Damage.Base
		+ fireRecord.Speed * self._configs.Slingshot.Damage.SpeedMultiplier
	if hitType == "Block" then
		DamageBlock(hitPart, damage)
	elseif hitType == "Character" then
		if hitPart.Name == "Head" then
			damage *= self._configs.Slingshot.Damage.HeadshotMultiplier
		end
		(hitParent:FindFirstChildOfClass("Humanoid") :: Humanoid):TakeDamage(damage)
	end
end

function RPHPrivateMethods._init(self: RPHInternal, instance: Player): ()
	self._className = "RoundPlayerHandler"
	self._charControllerType = "RoundCharacter"

	PlayerHandler.ProtectedMethods._init(self, instance)

	self._backpack = self.Instance:FindFirstChildOfClass("Backpack") :: Backpack

	self._combatEnabled = false

	self._lastPlaceBlockTick = 0
	self._lastDeleteBlockTick = 0

	self._projectileRecords = {}
	self._lastFireProjectileTick = 0

	self._kickOffenses = 0

	self._trove:Connect(self.Instance.CharacterAppearanceLoaded, function(character: Model)
		self:_onCharacterAppearanceLoaded(character)
	end)
end

function RPHPrivateMethods._addKickOffense(self: RPHInternal, reason: string): ()
	if self._kickOffenses == MAX_KICK_OFFENSES then
		self.Instance:Kick(string.format("You were kicked for %s", reason))
		return
	end

	self._kickOffenses = math.min(self._kickOffenses + 1, MAX_KICK_OFFENSES)
	task.delay(KICK_OFFENSE_LIFETIME, function()
		self._kickOffenses = math.max(self._kickOffenses - 1, 0)
	end)
end

-- @Override
function RPHPrivateMethods._onCharacterAdded(self: RPHInternal, character: Model): ()
	PlayerHandler.ProtectedMethods._onCharacterAdded(self, character)

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
end

function RPHPrivateMethods._onCharacterAppearanceLoaded(_, character: Model): ()
	-- Disable CanQuery for all accessories to prevent them from being queried by projectiles
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle") :: BasePart
			if handle then
				handle.CanQuery = false
			end
		end
	end
end

return RoundPlayerHandler
