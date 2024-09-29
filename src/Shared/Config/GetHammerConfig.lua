--!strict

export type Config = {
	MaxDistance: number,

	BuildRPM: number,
}

local DEFAULT_CONFIG: Config = {
	MaxDistance = 15,

	BuildRPM = 300,
}

local function GetHammerConfig(configuration: Configuration): Config
	local config: Config = DEFAULT_CONFIG

	local maxDistance = configuration:FindFirstChild("MaxDistance")
	if maxDistance and maxDistance:IsA("NumberValue") then
		config.MaxDistance = maxDistance.Value
	end

	local buildRPM = configuration:FindFirstChild("BuildRPM")
	if buildRPM and buildRPM:IsA("NumberValue") then
		config.BuildRPM = buildRPM.Value
	end

	return config
end

return GetHammerConfig
