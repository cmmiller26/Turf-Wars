--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedTypes = require(ReplicatedStorage.SharedTypes)

local DEFAULT_CONFIG: SharedTypes.SlingshotConfig = {
	Damage = {
		Base = 50,
		SpeedMultiplier = 0.5,
		HeadshotMultiplier = 2,
	},

	Projectile = {
		StartSpeed = 25,
		MaxSpeed = 100,

		Gravity = 40,

		Lifetime = 10,
	},

	DrawSpeed = 35,

	RPM = 400,
}

local function GetSlingshotConfig(configuration: Configuration): SharedTypes.SlingshotConfig
	local config = DEFAULT_CONFIG

	local damageBase = configuration:FindFirstChild("DamageBase")
	if damageBase and damageBase:IsA("NumberValue") then
		config.Damage.Base = damageBase.Value
	end
	local damageSpeedMultiplier = configuration:FindFirstChild("DamageSpeedMultiplier")
	if damageSpeedMultiplier and damageSpeedMultiplier:IsA("NumberValue") then
		config.Damage.SpeedMultiplier = damageSpeedMultiplier.Value
	end
	local damageHeadshotMultiplier = configuration:FindFirstChild("DamageHeadshotMultiplier")
	if damageHeadshotMultiplier and damageHeadshotMultiplier:IsA("NumberValue") then
		config.Damage.HeadshotMultiplier = damageHeadshotMultiplier.Value
	end

	local projectileStartSpeed = configuration:FindFirstChild("ProjectileStartSpeed")
	if projectileStartSpeed and projectileStartSpeed:IsA("NumberValue") then
		config.Projectile.StartSpeed = projectileStartSpeed.Value
	end
	local projectileMaxSpeed = configuration:FindFirstChild("ProjectileMaxSpeed")
	if projectileMaxSpeed and projectileMaxSpeed:IsA("NumberValue") then
		config.Projectile.MaxSpeed = projectileMaxSpeed.Value
	end

	local projectileGravity = configuration:FindFirstChild("ProjectileGravity")
	if projectileGravity and projectileGravity:IsA("NumberValue") then
		config.Projectile.Gravity = projectileGravity.Value
	end

	local projectileLifetime = configuration:FindFirstChild("ProjectileLifetime")
	if projectileLifetime and projectileLifetime:IsA("NumberValue") then
		config.Projectile.Lifetime = projectileLifetime.Value
	end

	local projectilePVInstance = configuration:FindFirstChild("ProjectilePVInstance")
	if projectilePVInstance and projectilePVInstance:IsA("ObjectValue") then
		local pvInstance = projectilePVInstance.Value
		if pvInstance and pvInstance:IsA("PVInstance") then
			config.Projectile.PVInstance = pvInstance
		end
	end

	local drawSpeed = configuration:FindFirstChild("DrawSpeed")
	if drawSpeed and drawSpeed:IsA("NumberValue") then
		config.DrawSpeed = drawSpeed.Value
	end

	local rpm = configuration:FindFirstChild("RPM")
	if rpm and rpm:IsA("NumberValue") then
		config.RPM = rpm.Value
	end

	return config
end

return GetSlingshotConfig
