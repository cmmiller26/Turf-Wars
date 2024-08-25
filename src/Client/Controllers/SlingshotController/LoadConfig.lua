--!strict

export type Config = {
	StartSpeed: number,
	MaxSpeed: number,
	Resistance: number,

	Gravity: number,

	Lifetime: number,

	Projectile: PVInstance,

	RPM: number,
}

local function LoadConfig(config: Configuration): Config
	local startSpeed = config:FindFirstChild("StartSpeed")
	assert(
		typeof(startSpeed) == "Instance" and startSpeed:IsA("NumberValue"),
		"SlingshotController LoadConfig(): Expected a 'StartSpeed' NumberValue in self.Instance.Config, got "
			.. typeof(startSpeed)
	)
	local maxSpeed = config:FindFirstChild("MaxSpeed")
	assert(
		typeof(maxSpeed) == "Instance" and maxSpeed:IsA("NumberValue"),
		"SlingshotController LoadConfig(): Expected a 'MaxSpeed' NumberValue in self.Instance.Config, got "
			.. typeof(maxSpeed)
	)
	local resistance = config:FindFirstChild("Resistance")
	assert(
		typeof(resistance) == "Instance" and resistance:IsA("NumberValue"),
		"SlingshotController LoadConfig(): Expected a 'Resistance' NumberValue in self.Instance.Config, got "
			.. typeof(resistance)
	)

	local gravity = config:FindFirstChild("Gravity")
	assert(
		typeof(gravity) == "Instance" and gravity:IsA("NumberValue"),
		"SlingshotController LoadConfig(): Expected a 'Gravity' NumberValue in self.Instance.Config, got "
			.. typeof(gravity)
	)

	local lifetime = config:FindFirstChild("Lifetime")
	assert(
		typeof(lifetime) == "Instance" and lifetime:IsA("NumberValue"),
		"SlingshotController LoadConfig(): Expected a 'Lifetime' NumberValue in self.Instance.Config, got "
			.. typeof(lifetime)
	)

	local projectile = config:FindFirstChild("Projectile")
	assert(
		typeof(projectile) == "Instance" and projectile:IsA("ObjectValue"),
		"SlingshotController LoadConfig(): Expected a 'Projectile' ObjectValue in self.Instance.Config, got "
			.. typeof(projectile)
	)
	assert(
		typeof(projectile.Value) == "Instance" and projectile.Value:IsA("PVInstance"),
		"SlingshotController LoadConfig(): Expected 'Projectile' ObjectValue to have a value of type PVInstance, got "
			.. typeof(projectile.Value)
	)

	local rpm = config:FindFirstChild("RPM")
	assert(
		typeof(rpm) == "Instance" and rpm:IsA("NumberValue"),
		"SlingshotController LoadConfig(): Expected a 'RPM' NumberValue in self.Instance.Config, got " .. typeof(rpm)
	)

	return {
		StartSpeed = startSpeed.Value,
		MaxSpeed = maxSpeed.Value,
		Resistance = resistance.Value,

		Gravity = gravity.Value,

		Lifetime = lifetime.Value,

		Projectile = projectile.Value,

		RPM = rpm.Value,
	}
end

return LoadConfig
