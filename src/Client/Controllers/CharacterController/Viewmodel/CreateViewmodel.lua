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

	local rootPart = viewmodel:FindFirstChild("HumanoidRootPart")
	assert(
		typeof(rootPart) == "Instance" and rootPart:IsA("BasePart"),
		"CreateViewmodel(): Expected 'HumanoidRootPart' BasePart in Viewmodel, got " .. typeof(rootPart)
	)
	rootPart.Anchored = true
	viewmodel.PrimaryPart = rootPart

	local humanoid = viewmodel:FindFirstChildOfClass("Humanoid")
	assert(humanoid, "CreateViewmodel(): Expected a Humanoid in Viewmodel")
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

	local torso = viewmodel:FindFirstChild("Torso")
	assert(
		typeof(torso) == "Instance" and torso:IsA("BasePart"),
		"CreateViewmodel(): Expected 'Torso' BasePart in Viewmodel, got " .. typeof(torso)
	)
	torso.Transparency = 1

	local leftArm = viewmodel:FindFirstChild("Left Arm")
	assert(
		typeof(leftArm) == "Instance" and leftArm:IsA("BasePart"),
		"CreateViewmodel(): Expected 'Left Arm' BasePart in Viewmodel, got " .. typeof(leftArm)
	)
	leftArm.Size = ARM_SIZE
	local rightArm = viewmodel:FindFirstChild("Right Arm")
	assert(
		typeof(rightArm) == "Instance" and rightArm:IsA("BasePart"),
		"CreateViewmodel(): Expected 'Right Arm' BasePart in Viewmodel, got " .. typeof(rightArm)
	)
	rightArm.Size = ARM_SIZE

	return viewmodel
end

return CreateViewmodel
