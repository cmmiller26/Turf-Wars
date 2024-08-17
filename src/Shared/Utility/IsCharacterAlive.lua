--!strict

local function IsCharacterAlive(character: Model): boolean
	assert(
		typeof(character) == "Instance" and character:IsA("Model"),
		"IsCharacterAlive() expected Model for argument #1, got " .. typeof(character)
	)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	return humanoid.Health > 0
end

return IsCharacterAlive
