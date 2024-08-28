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
	local viewmodel = Players:CreateHumanoidModelFromDescription(
		Players:GetHumanoidDescriptionFromUserId(USER_ID),
		Enum.HumanoidRigType.R6
	)
	viewmodel.Name = "Viewmodel"

	local rootPart = viewmodel:FindFirstChild("HumanoidRootPart") :: BasePart
	rootPart.Anchored = true
	viewmodel.PrimaryPart = rootPart

	local humanoid = viewmodel:FindFirstChildOfClass("Humanoid") :: Humanoid
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

	(viewmodel:FindFirstChild("Torso") :: BasePart).Transparency = 1;

	(viewmodel:FindFirstChild("Left Arm") :: BasePart).Size = ARM_SIZE;
	(viewmodel:FindFirstChild("Right Arm") :: BasePart).Size = ARM_SIZE

	return viewmodel
end

return CreateViewmodel
