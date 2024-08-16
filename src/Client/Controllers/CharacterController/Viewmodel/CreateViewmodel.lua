--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local USER_ID = Players.LocalPlayer.UserId
if RunService:IsStudio() then
	USER_ID = 107484074
end

local VALID_CHILDREN = {
	["Body Colors"] = true,
	["Shirt"] = true,
	["Humanoid"] = true,
	["HumanoidRootPart"] = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Torso"] = true,
	["Left Shoulder"] = true,
	["Right Shoulder"] = true,
	["RootJoint"] = true,
}

local VIEWMODEL_COLLISION_GROUP = "Viewmodel"

local ARM_SIZE = Vector3.new(0.5, 2, 0.5)

local function CreateViewmodel(): Model
	local description = Players:GetHumanoidDescriptionFromUserId(USER_ID)
	local viewmodel = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	viewmodel.Name = "Viewmodel"

	viewmodel.PrimaryPart = viewmodel:FindFirstChild("HumanoidRootPart") :: BasePart
	viewmodel.PrimaryPart.Anchored = true

	local humanoid = viewmodel:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.EvaluateStateMachine = false
	humanoid.RequiresNeck = false

	for _, descendant in ipairs(viewmodel:GetDescendants()) do
		if not VALID_CHILDREN[descendant.Name] then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.CastShadow = false
			descendant.CollisionGroup = VIEWMODEL_COLLISION_GROUP
			descendant.Massless = true
		end
	end

	viewmodel.Torso.Transparency = 1

	viewmodel["Left Arm"].Size = ARM_SIZE
	viewmodel["Right Arm"].Size = ARM_SIZE

	return viewmodel
end

return CreateViewmodel
