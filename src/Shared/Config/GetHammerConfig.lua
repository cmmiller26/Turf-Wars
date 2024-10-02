--!strict

export type Config = {
	Damage: number,

	MaxDistance: number,

	PlaceRPM: number,
	DeleteRPM: number,
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
