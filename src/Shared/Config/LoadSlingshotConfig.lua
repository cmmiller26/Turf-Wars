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

local function LoadSlingshotConfig(configuration: Configuration): Config
	local startSpeed = configuration:FindFirstChild("StartSpeed")
	assert(
		typeof(startSpeed) == "Instance" and startSpeed:IsA("NumberValue"),
		"LoadSlingshotConfig(): Expected 'StartSpeed' NumberValue, got " .. typeof(startSpeed)
	)
	local maxSpeed = configuration:FindFirstChild("MaxSpeed")
	assert(
		typeof(maxSpeed) == "Instance" and maxSpeed:IsA("NumberValue"),
		"LoadSlingshotConfig(): Expected 'MaxSpeed' NumberValue, got " .. typeof(maxSpeed)
	)
	local resistance = configuration:FindFirstChild("Resistance")
	assert(
		typeof(resistance) == "Instance" and resistance:IsA("NumberValue"),
		"LoadSlingshotConfig(): Expected 'Resistance' NumberValue, got " .. typeof(resistance)
	)

	local gravity = configuration:FindFirstChild("Gravity")
	assert(
		typeof(gravity) == "Instance" and gravity:IsA("NumberValue"),
		"LoadSlingshotConfig(): Expected 'Gravity' NumberValue, got " .. typeof(gravity)
	)

	local lifetime = configuration:FindFirstChild("Lifetime")
	assert(
		typeof(lifetime) == "Instance" and lifetime:IsA("NumberValue"),
		"LoadSlingshotConfig(): Expected 'Lifetime' NumberValue, got " .. typeof(lifetime)
	)

	local rpm = configuration:FindFirstChild("RPM")
	assert(
		typeof(rpm) == "Instance" and rpm:IsA("NumberValue"),
		"LoadSlingshotConfig(): Expected 'RPM' NumberValue, got " .. typeof(rpm)
	)

	local damage = configuration:FindFirstChild("Damage")
	assert(
		typeof(damage) == "Instance" and damage:IsA("NumberValue"),
		"LoadSlingshotConfig(): Expected 'Damage' NumberValue, got " .. typeof(damage)
	)
	local speedMultiplier = configuration:FindFirstChild("SpeedMultiplier")
	assert(
		typeof(speedMultiplier) == "Instance" and speedMultiplier:IsA("NumberValue"),
		"LoadSlingshotConfig(): Expected 'SpeedMultiplier' NumberValue, got " .. typeof(speedMultiplier)
	)
	local headshotMultiplier = configuration:FindFirstChild("HeadshotMultiplier")
	assert(
		typeof(headshotMultiplier) == "Instance" and headshotMultiplier:IsA("NumberValue"),
		"LoadSlingshotConfig(): Expected 'HeadshotMultiplier' NumberValue, got " .. typeof(headshotMultiplier)
	)

	local projectile = configuration:FindFirstChild("Projectile")
	assert(
		typeof(projectile) == "Instance" and projectile:IsA("ObjectValue"),
		"LoadSlingshotConfig(): Expected 'Projectile' ObjectValue, got " .. typeof(projectile)
	)
	assert(
		typeof(projectile.Value) == "Instance" and projectile.Value:IsA("PVInstance"),
		"LoadSlingshotConfig(): Expected Projectile.Value to be PVInstance, got " .. typeof(projectile.Value)
	)

	local config: Config = {
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
	return config
end

return LoadSlingshotConfig
