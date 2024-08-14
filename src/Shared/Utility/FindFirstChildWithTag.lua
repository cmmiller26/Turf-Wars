--!strict

local CollectionService = game:GetService("CollectionService")

local function FindFirstChildWithTag(parent: Instance, tag: string): Instance?
	for _, child in ipairs(parent:GetChildren()) do
		if CollectionService:HasTag(child, tag) then
			return child
		end
	end

	return nil
end

return FindFirstChildWithTag
