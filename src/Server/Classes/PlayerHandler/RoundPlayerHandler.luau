--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

-- External dependencies
local SharedTypes = require(ReplicatedStorage.SharedTypes)

local Config = ReplicatedStorage.Config
local GetHammerConfig = require(Config.GetHammerConfig)
local GetSlingshotConfig = require(Config.GetSlingshotConfig)

local Utility = ReplicatedStorage.Utility
local CreateMultiIndex = require(Utility.CreateMultiIndex)
local FindFirstChildWithTag = require(Utility.FindFirstChildWithTag)
local Grid = require(Utility.Grid)
local Physics = require(Utility.Physics)

-- Server modules
local Server = ServerScriptService.Server
local ServerTypes = require(Server.ServerTypes)
local TurfService = require(Server.Services.TurfService)

-- Superclass
local PlayerHandler = require(script.Parent)

type RoundPlayerHandler = ServerTypes.RoundPlayerHandler
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
		Hammer: SharedTypes.HammerConfig,
		Slingshot: SharedTypes.SlingshotConfig,
	},

	_addKickOffense: (self: RPHInternal, reason: string) -> (),

	_onCharacterAppearanceLoaded: (self: RPHInternal, character: Model) -> (),
}

type ProjectileRecord = {
	Origin: Vector3,
	Direction: Vector3,
	Speed: number,
}

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

local MAX_KICK_OFFENSES = 3 -- Maximum offenses before kicking the player
local KICK_OFFENSE_LIFETIME = 60 -- Time (in seconds) before reducing offenses

local MAX_ORIGIN_ERROR = 4 -- Maximum error (in studs) for origin calculations
local MAX_PING_ERROR = 0.05 -- Maximum error (in seconds) for RPM calculations

local HEAD_OFFSET = Vector3.new(0, 1.5, 0)

local Blocks = Workspace:WaitForChild("Blocks")

local Effects = ReplicatedStorage.Effects
local Remotes = ReplicatedStorage.Remotes

local RoundPlayerHandler = {}

local RPHPublicMethods = {}
local RPHPrivateMethods = {}

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

function RPHPublicMethods.SetCombatEnabled(self: RPHInternal, enabled: boolean): ()
	self._combatEnabled = enabled
	if self._isAlive then
		Remotes.Character.EnableCombat:FireClient(self.Instance, enabled)
	end
end

function RPHPublicMethods.OnEquipTool(self: RPHInternal, toolType: SharedTypes.ToolType): ()
	if not self._isAlive then
		warn(string.format("[RoundPlayerHandler.OnEquipTool]: %s is not alive", self.Instance.Name))
		return
	end

	local tool = self._tools[toolType]
	if not tool then
		warn(string.format("[RoundPlayerHandler.OnEquipTool]: %s does not have a %s", self.Instance.Name, toolType))
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

function RPHPublicMethods.OnUnequip(self: RPHInternal): ()
	if not self._curTool then
		return
	end

	-- Detach the tool from the player's character and move it to the backpack
	self._toolJoint.Part1 = nil
	self._curTool.Parent = self._backpack
	self._curTool = nil
end

function RPHPublicMethods.OnPlaceBlock(self: RPHInternal, placePos: Vector3): boolean
	if not self._isAlive then
		warn(string.format("[RoundPlayerHandler.OnPlaceBlock]: %s is not alive", self.Instance.Name))
		return false
	end

	if self._curTool ~= self._tools.Hammer then
		warn(string.format("[RoundPlayerHandler.OnPlaceBlock]: %s does not have a Hammer equipped", self.Instance.Name))
		return false
	end

	-- Ensure the position is snapped to the grid
	if placePos ~= Grid.SnapPosition(placePos) then
		warn(
			string.format("[RoundPlayerHandler.OnPlaceBlock]: %s passed an invalid block position", self.Instance.Name)
		)
		return false
	end

	if not TurfService:IsPositionOnTurf(self.Instance.Team, placePos) then
		warn(
			string.format(
				"[RoundPlayerHandler.OnPlaceBlock]: %s tried to place a block outside their turf",
				self.Instance.Name
			)
		)
		return false
	end

	local tick = os.clock()
	-- Check if block placement is too fast based on the tool's RPM
	if tick - self._lastPlaceBlockTick < (60 / self._configs.Hammer.PlaceRPM) - MAX_PING_ERROR then
		warn(string.format("[RoundPlayerHandler.OnPlaceBlock]: %s tried to place too quickly", self.Instance.Name))
		self:_addKickOffense("spamming block placement")
		return false
	end

	local character = self.Instance.Character :: Model
	local charPos = character:GetPivot().Position + HEAD_OFFSET
	-- Check if the block placement is too far from the player's character
	if (charPos - placePos).Magnitude > self._configs.Hammer.MaxDistance + MAX_ORIGIN_ERROR then
		warn(string.format("[RoundPlayerHandler.OnPlaceBlock]: %s tried to place too far away", self.Instance.Name))
		return false
	end

	local overlapSize = Vector3.new(Grid.SIZE, Grid.SIZE, Grid.SIZE) / 2

	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = { character }
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude

	-- Check if the block placement area is already occupied
	if #Workspace:GetPartBoundsInBox(CFrame.new(placePos), overlapSize, overlapParams) > 0 then
		warn(
			string.format(
				"[RoundPlayerHandler.OnPlaceBlock]: %s tried to place in an occupied area",
				self.Instance.Name
			)
		)
		return false
	end

	local block: BasePart = Effects.Hammer.Block:Clone()
	block.BrickColor = self.Instance.TeamColor
	block.Position = placePos
	block.Parent = Blocks

	TurfService:ProcessBlockPlacement(self.Instance.Team, block)

	self._lastPlaceBlockTick = tick

	return true
end

function RPHPublicMethods.OnDeleteBlock(self: RPHInternal, targetBlock: BasePart)
	if not self._isAlive then
		warn(string.format("[RoundPlayerHandler.OnDeleteBlock]: %s is not alive", self.Instance.Name))
		return
	end

	if self._curTool ~= self._tools.Hammer then
		warn(
			string.format("[RoundPlayerHandler.OnDeleteBlock]: %s does not have a Hammer equipped", self.Instance.Name)
		)
		return
	end

	if targetBlock.BrickColor ~= self.Instance.TeamColor then
		warn(
			string.format(
				"[RoundPlayerHandler.OnDeleteBlock]: %s tried to delete a block of another team",
				self.Instance.Name
			)
		)
		return
	end

	local tick = os.clock()
	-- Check if block deletion is too fast based on the tool's RPM
	if tick - self._lastDeleteBlockTick < (60 / self._configs.Hammer.DeleteRPM) - MAX_PING_ERROR then
		warn(string.format("[RoundPlayerHandler.OnDeleteBlock]: %s tried to delete too quickly", self.Instance.Name))
		self:_addKickOffense("spamming block deletion")
		return
	end

	local charPos = (self.Instance.Character :: Model):GetPivot().Position + HEAD_OFFSET
	-- Check if the block deletion is too far from the player's character
	if (charPos - targetBlock.Position).Magnitude > self._configs.Hammer.MaxDistance + MAX_ORIGIN_ERROR then
		warn(string.format("[RoundPlayerHandler.OnDeleteBlock]: %s tried to delete too far away", self.Instance.Name))
		return
	end

	DamageBlock(targetBlock, self._configs.Hammer.Damage)

	self._lastDeleteBlockTick = tick
end

function RPHPublicMethods.OnFireProjectile(
	self: RPHInternal,
	origin: Vector3,
	direction: Vector3,
	speed: number,
	timestamp: number
): ()
	if not self._combatEnabled then
		warn(
			string.format(
				"[RoundPlayerHandler.OnFireProjectile]: %s tried to fire while combat was disabled",
				self.Instance.Name
			)
		)
		return
	end

	if not self._isAlive then
		warn(string.format("[RoundPlayerHandler.OnFireProjectile]: %s is not alive", self.Instance.Name))
		return
	end

	if self._curTool ~= self._tools.Slingshot then
		warn(
			string.format(
				"[RoundPlayerHandler.OnFireProjectile]: %s does not have a Slingshot equipped",
				self.Instance.Name
			)
		)
		return
	end

	if direction == Vector3.zero then
		warn(
			string.format(
				"[RoundPlayerHandler.OnFireProjectile]: %s fired with a zero vector direction",
				self.Instance.Name
			)
		)
		return
	end
	direction = direction.Unit

	if speed > self._configs.Slingshot.Projectile.MaxSpeed then
		warn(
			string.format(
				"[RoundPlayerHandler.OnFireProjectile]: Kicking %s for firing a projectile at a hacked speed",
				self.Instance.Name
			)
		)
		self.Instance:Kick("You were kicked for firing a projectile at a hacked speed")
		return
	end

	-- Check if the timestamp is too far from the current time based on the network ping
	if math.abs(Workspace:GetServerTimeNow() - timestamp) > self.Instance:GetNetworkPing() + MAX_PING_ERROR then
		warn(
			string.format(
				"[RoundPlayerHandler.OnFireProjectile]: %s fired with an invalid timestamp",
				self.Instance.Name
			)
		)
		return
	end

	local tick = os.clock()
	-- Check if projectile firing is too fast based on the tool's RPM
	if tick - self._lastFireProjectileTick < (60 / self._configs.Slingshot.RPM) - MAX_PING_ERROR then
		warn(string.format("[RoundPlayerHandler.OnFireProjectile]: %s tried to fire too quickly", self.Instance.Name))
		self:_addKickOffense("spamming projectile firing")
		return
	end

	local charPos = (self.Instance.Character :: Model):GetPivot().Position + HEAD_OFFSET
	-- Check if the projectile origin is too far from the player's character
	if (charPos - origin).Magnitude > MAX_ORIGIN_ERROR then
		warn(
			string.format("[RoundPlayerHandler.OnFireProjectile]: %s fired from an invalid origin", self.Instance.Name)
		)
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

function RPHPublicMethods.OnRegisterHit(
	self: RPHInternal,
	projHitType: SharedTypes.ProjectileHitType,
	hitPart: BasePart,
	hitTimestamp: number,
	fireTimestamp: number
): ()
	if not self._combatEnabled then
		warn(
			string.format(
				"[RoundPlayerHandler.OnRegisterHit]: %s tried to register while combat was disabled",
				self.Instance.Name
			)
		)
		return
	end

	local timeSinceFire = hitTimestamp - fireTimestamp
	if timeSinceFire < 0 or timeSinceFire > self._configs.Slingshot.Projectile.Lifetime + MAX_PING_ERROR then
		warn(
			string.format(
				"[RoundPlayerHandler.OnRegisterHit]: %s tried to register outside the projectile's lifetime",
				self.Instance.Name
			)
		)
		return
	end

	local fireRecord = self._projectileRecords[fireTimestamp]
	if not fireRecord then
		warn(
			string.format(
				"[RoundPlayerHandler.OnRegisterHit]: %s tried to register without a projectile record",
				self.Instance.Name
			)
		)
		return
	end

	local hitParent = hitPart.Parent
	if not hitParent then
		warn(
			string.format(
				"[RoundPlayerHandler.OnRegisterHit]: %s tried to register an instance without a parent",
				self.Instance.Name
			)
		)
		return
	end
	if projHitType == "Block" then
		if hitParent ~= Blocks then
			warn(
				string.format(
					"[RoundPlayerHandler.OnRegisterHit]: %s tried to register a block not in the Blocks folder",
					self.Instance.Name
				)
			)
			return
		end
		if hitPart.BrickColor == self.Instance.TeamColor then
			warn(
				string.format(
					"[RoundPlayerHandler.OnRegisterHit]: %s tried to register a hit on a block of their own team",
					self.Instance.Name
				)
			)
			return
		end
	elseif projHitType == "Character" then
		local humanoid = hitParent:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			warn(
				string.format(
					"[RoundPlayerHandler.OnRegisterHit]: %s tried to register a hit on a character without a Humanoid or with 0 health",
					self.Instance.Name
				)
			)
			return
		end
		local player = Players:GetPlayerFromCharacter(hitParent)
		if not player or player.Team == self.Instance.Team then
			warn(
				string.format(
					"[RoundPlayerHandler.OnRegisterHit]: %s tried to register a hit on a player that doesn't exist or is on the same team",
					self.Instance.Name
				)
			)
			return
		end
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
		warn(
			string.format(
				"[RoundPlayerHandler.OnRegisterHit]: %s registered hit position did not match the calculated position",
				self.Instance.Name
			)
		)
		return
	end

	local damage = self._configs.Slingshot.Damage.Base
		+ fireRecord.Speed * self._configs.Slingshot.Damage.SpeedMultiplier
	if projHitType == "Block" then
		DamageBlock(hitPart, damage)
	elseif projHitType == "Character" then
		if hitPart.Name == "Head" then
			damage *= self._configs.Slingshot.Damage.HeadshotMultiplier
		end

		local humanoid = hitParent:FindFirstChildOfClass("Humanoid") :: Humanoid
		local prevHealth = humanoid.Health
		humanoid:TakeDamage(damage)

		print(
			string.format(
				"[RoundPlayerHandler.OnRegisterHit]: %s successfully hit %s's %s for %d damage",
				self.Instance.Name,
				hitParent.Name,
				hitPart.Name,
				damage
			)
		)

		if prevHealth - damage <= 0 then
			local player = Players:GetPlayerFromCharacter(hitParent)
			if player then
				TurfService:RegisterKill(self.Instance, player)
			end
		end
	end
end

function RPHPrivateMethods._init(self: RPHInternal, instance: Player): ()
	self._className = "RoundPlayerHandler"
	self._charControllerType = "RoundCharacter"

	PlayerHandler.ProtectedMethods._init(self, instance)

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

function RPHPrivateMethods._onCharacterAdded(self: RPHInternal, character: Model): ()
	PlayerHandler.ProtectedMethods._onCharacterAdded(self, character)

	self._backpack = self.Instance:FindFirstChildOfClass("Backpack") :: Backpack

	-- Create a Motor6D to attach tools to the character
	local toolJoint = Instance.new("Motor6D")
	toolJoint.Name = "ToolJoint"
	toolJoint.Part0 = character:FindFirstChild("Torso") :: BasePart
	toolJoint.Parent = toolJoint.Part0
	self._toolJoint = toolJoint

	-- Find the tools in the character's backpack
	local hammer = FindFirstChildWithTag(self._backpack, "Hammer")
	if not (hammer and hammer:IsA("Model")) then
		warn(
			string.format(
				"[RoundPlayerHandler._onCharacterAdded]: %s's Backpack does not have a Hammer",
				self.Instance.Name
			)
		)
		return
	end
	local slingshot = FindFirstChildWithTag(self._backpack, "Slingshot")
	if not (slingshot and slingshot:IsA("Model")) then
		warn(
			string.format(
				"[RoundPlayerHandler._onCharacterAdded]: %s's Backpack does not have a Slingshot",
				self.Instance.Name
			)
		)
		return
	end
	self._tools = {
		Hammer = hammer,
		Slingshot = slingshot,
	}

	-- Get the configurations for the tools
	local hammerConfiguration = hammer:FindFirstChildOfClass("Configuration")
	if not hammerConfiguration then
		warn(
			string.format(
				"[RoundPlayerHandler._onCharacterAdded]: %s's Hammer does not have a Configuration",
				self.Instance.Name
			)
		)
		return
	end
	local slingshotConfiguration = slingshot:FindFirstChildOfClass("Configuration")
	if not slingshotConfiguration then
		warn(
			string.format(
				"[RoundPlayerHandler._onCharacterAdded]: %s's Slingshot does not have a Configuration",
				self.Instance.Name
			)
		)
		return
	end
	self._configs = {
		Hammer = GetHammerConfig(hammerConfiguration),
		Slingshot = GetSlingshotConfig(slingshotConfiguration),
	}

	Remotes.Character.EnableCombat:FireClient(self.Instance, self._combatEnabled)
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
