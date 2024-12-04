--!strict

export type Config = {
	Damage: number, -- The amount of damage the hammer does to a block each hit

	MaxDistance: number, -- The maximum distance the hammer can be from a block to hit it

	PlaceRPM: number, -- The rate at which the hammer can place blocks per minute
	DeleteRPM: number, -- The rate at which the hammer hits blocks per minute
}

local DEFAULT_CONFIG: Config = {
	Damage = 25,

	MaxDistance = 15,

	PlaceRPM = 300,
	DeleteRPM = 600,
}

local function GetHammerConfig(configuration: Configuration): Config
	local config = DEFAULT_CONFIG

	local maxDistance = configuration:FindFirstChild("MaxDistance")
	if maxDistance and maxDistance:IsA("NumberValue") then
		config.MaxDistance = maxDistance.Value
	end

	local placeRPM = configuration:FindFirstChild("PlaceRPM")
	if placeRPM and placeRPM:IsA("NumberValue") then
		config.PlaceRPM = placeRPM.Value
	end
	local deleteRPM = configuration:FindFirstChild("DeleteRPM")
	if deleteRPM and deleteRPM:IsA("NumberValue") then
		config.DeleteRPM = deleteRPM.Value
	end

	return config
end

return GetHammerConfig
