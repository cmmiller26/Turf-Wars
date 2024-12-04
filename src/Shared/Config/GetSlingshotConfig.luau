--!strict

export type Config = {
	Damage: {
		Base: number, -- Base damage of the projectile
		SpeedMultiplier: number, -- Multiplier for the speed of the projectile
		HeadshotMultiplier: number, -- Multiplier for headshot damage
	},

	Projectile: {
		StartSpeed: number, -- Initial speed of the projectile
		MaxSpeed: number, -- Maximum speed of the projectile

		Gravity: number, -- The downward acceleration of the projectile

		Lifetime: number, -- The time in seconds before the projectile is destroyed

		PVInstance: PVInstance?, -- The PVInstance to use for the projectile
	},

	DrawSpeed: number, -- The rate at which the speed of the projectile increases when drawing the slingshot

	RPM: number, -- The rate of fire of the slingshot
}

local DEFAULT_CONFIG: Config = {
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

local function GetSlingshotConfig(configuration: Configuration): Config
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
