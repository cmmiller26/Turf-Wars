--!strict

local function IsCharacterAlive(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid.Health > 0
	end
	return false
end

return IsCharacterAlive
