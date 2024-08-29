--!strict

local function FindFirstChildWithTag(parent: Instance, tag: string): Instance?
	for _, child in ipairs(parent:GetChildren()) do
		if child:HasTag(tag) then
			return child
		end
	end
	return nil
end

return FindFirstChildWithTag
