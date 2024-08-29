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

	Projectile: PVInstance?,
}

local DEFAULT_CONFIG: Config = {
	StartSpeed = 25,
	MaxSpeed = 100,
	Resistance = 35,

	Gravity = 40,

	Lifetime = 10,

	RPM = 400,

	Damage = 50,
	SpeedMultiplier = 0.5,
	HeadshotMultiplier = 2,
}

local function LoadSlingshotConfig(configuration: Configuration): Config
	local config = DEFAULT_CONFIG

	local startSpeed = configuration:FindFirstChild("StartSpeed") :: NumberValue
	if startSpeed then
		config.StartSpeed = startSpeed.Value
	end
	local maxSpeed = configuration:FindFirstChild("MaxSpeed") :: NumberValue
	if maxSpeed then
		config.MaxSpeed = maxSpeed.Value
	end
	local resistance = configuration:FindFirstChild("Resistance") :: NumberValue
	if resistance then
		config.Resistance = resistance.Value
	end

	local gravity = configuration:FindFirstChild("Gravity") :: NumberValue
	if gravity then
		config.Gravity = gravity.Value
	end

	local lifetime = configuration:FindFirstChild("Lifetime") :: NumberValue
	if lifetime then
		config.Lifetime = lifetime.Value
	end

	local rpm = configuration:FindFirstChild("RPM") :: NumberValue
	if rpm then
		config.RPM = rpm.Value
	end

	local damage = configuration:FindFirstChild("Damage") :: NumberValue
	if damage then
		config.Damage = damage.Value
	end
	local speedMultiplier = configuration:FindFirstChild("SpeedMultiplier") :: NumberValue
	if speedMultiplier then
		config.SpeedMultiplier = speedMultiplier.Value
	end
	local headshotMultiplier = configuration:FindFirstChild("HeadshotMultiplier") :: NumberValue
	if headshotMultiplier then
		config.HeadshotMultiplier = headshotMultiplier.Value
	end

	local projectile = configuration:FindFirstChild("Projectile") :: ObjectValue
	if projectile then
		local pvInstance = projectile.Value
		if pvInstance and pvInstance:IsA("PVInstance") then
			config.Projectile = pvInstance
		else
			warn("Projectile is not a PVInstance")
		end
	end

	return config
end

return LoadSlingshotConfig
