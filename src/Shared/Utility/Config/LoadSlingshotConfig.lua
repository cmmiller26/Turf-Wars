--!strict

export type Config = {
	StartSpeed: number,
	MaxSpeed: number,
	Resistance: number,

	Gravity: number,

	Lifetime: number,

	RPM: number,

	Damage: number,
	SpeedMultiplier: number,
	HeadshotMultiplier: number,

	Projectile: PVInstance,
}

local function LoadSlingshotConfig(config: Configuration): Config
	local startSpeed = config:FindFirstChild("StartSpeed")
	assert(
		typeof(startSpeed) == "Instance" and startSpeed:IsA("NumberValue"),
		"LoadSlingshotConfig(): Expected a 'StartSpeed' NumberValue, got " .. typeof(startSpeed)
	)
	local maxSpeed = config:FindFirstChild("MaxSpeed")
	assert(
		typeof(maxSpeed) == "Instance" and maxSpeed:IsA("NumberValue"),
		"LoadSlingshotConfig(): Expected a 'MaxSpeed' NumberValue, got " .. typeof(maxSpeed)
	)
	local resistance = config:FindFirstChild("Resistance")
	assert(
		typeof(resistance) == "Instance" and resistance:IsA("NumberValue"),
		"LoadSlingshotConfig(): Expected a 'Resistance' NumberValue, got " .. typeof(resistance)
	)

	local gravity = config:FindFirstChild("Gravity")
	assert(
		typeof(gravity) == "Instance" and gravity:IsA("NumberValue"),
		"LoadSlingshotConfig(): Expected a 'Gravity' NumberValue, got " .. typeof(gravity)
	)

	local lifetime = config:FindFirstChild("Lifetime")
	assert(
		typeof(lifetime) == "Instance" and lifetime:IsA("NumberValue"),
		"LoadSlingshotConfig(): Expected a 'Lifetime' NumberValue, got " .. typeof(lifetime)
	)

	local rpm = config:FindFirstChild("RPM")
	assert(
		typeof(rpm) == "Instance" and rpm:IsA("NumberValue"),
		"LoadSlingshotConfig(): Expected a 'RPM' NumberValue, got " .. typeof(rpm)
	)

	local damage = config:FindFirstChild("Damage")
	assert(
		typeof(damage) == "Instance" and damage:IsA("NumberValue"),
		"LoadSlingshotConfig(): Expected a 'Damage' NumberValue, got " .. typeof(damage)
	)
	local speedMultiplier = config:FindFirstChild("SpeedMultiplier")
	assert(
		typeof(speedMultiplier) == "Instance" and speedMultiplier:IsA("NumberValue"),
		"LoadSlingshotConfig(): Expected a 'SpeedMultiplier' NumberValue, got " .. typeof(speedMultiplier)
	)
	local headshotMultiplier = config:FindFirstChild("HeadshotMultiplier")
	assert(
		typeof(headshotMultiplier) == "Instance" and headshotMultiplier:IsA("NumberValue"),
		"LoadSlingshotConfig(): Expected a 'HeadshotMultiplier' NumberValue, got " .. typeof(headshotMultiplier)
	)

	local projectile = config:FindFirstChild("Projectile")
	assert(
		typeof(projectile) == "Instance" and projectile:IsA("ObjectValue"),
		"LoadSlingshotConfig(): Expected a 'Projectile' ObjectValue, got " .. typeof(projectile)
	)
	assert(
		typeof(projectile.Value) == "Instance" and projectile.Value:IsA("PVInstance"),
		"LoadSlingshotConfig(): Expected 'Projectile' ObjectValue to have a value of type PVInstance, got "
			.. typeof(projectile.Value)
	)

	return {
		StartSpeed = startSpeed.Value,
		MaxSpeed = maxSpeed.Value,
		Resistance = resistance.Value,

		Gravity = gravity.Value,

		Lifetime = lifetime.Value,

		RPM = rpm.Value,

		Damage = damage.Value,
		SpeedMultiplier = speedMultiplier.Value,
		HeadshotMultiplier = headshotMultiplier.Value,

		Projectile = projectile.Value,
	}
end

return LoadSlingshotConfig
