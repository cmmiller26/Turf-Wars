--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage.Packages.Trove)

export type Viewmodel = {
	Instance: Model,

	Destroy: (self: Viewmodel) -> (),
}
type self = Viewmodel & {
	_trove: Trove.Trove,

	_thisRootJoint: Motor6D,
	_thisLeftShoulder: Motor6D,
	_thisRightShoulder: Motor6D,

	_charRootJoint: Motor6D,
	_charLeftShoulder: Motor6D,
	_charRightShoulder: Motor6D,

	_cframeValue: CFrameValue,

	_init: (self: self, character: Model) -> (),

	_onPreRender: (self: self) -> (),
}

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

local CAMERA_OFFSET = -1.5

local Camera = Workspace.CurrentCamera

local function CreateViewmodel(): Model
	local viewmodel = Players:CreateHumanoidModelFromUserId(USER_ID, Enum.HumanoidRigType.R6)
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

local function CreateCFrameValue(humanoid: Humanoid): CFrameValue
	local cframeValue = Instance.new("CFrameValue")

	local landTween1 =
		TweenService:Create(cframeValue, TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Value = CFrame.Angles(-math.rad(5), 0, 0),
		})
	local landTween2 =
		TweenService:Create(cframeValue, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Value = CFrame.new(),
		})
	landTween1.Completed:Connect(function()
		if humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
			landTween2:Play()
		end
	end)

	local fallTween = TweenService:Create(cframeValue, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
		Value = CFrame.Angles(math.rad(7.5), 0, 0),
	})

	local connection = humanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Landed then
			landTween1:Play()
		elseif newState == Enum.HumanoidStateType.Freefall then
			fallTween:Play()
		end
	end)

	cframeValue.Destroying:Connect(function()
		landTween1:Destroy()
		landTween2:Destroy()

		fallTween:Destroy()

		connection:Disconnect()
	end)

	return cframeValue
end

local Viewmodel = {}
Viewmodel.__index = Viewmodel

function Viewmodel.new(character: Model): Viewmodel
	local self = setmetatable({} :: self, Viewmodel)

	self:_init(character)

	return self
end
function Viewmodel.Destroy(self: self)
	self._trove:Clean()
end

function Viewmodel._init(self: self, character: Model)
	self._trove = Trove.new()

	self.Instance = self._trove:Add(CreateViewmodel())
	self.Instance.Parent = Camera

	local thisRootPart = self.Instance.PrimaryPart :: BasePart
	local thisTorso = self.Instance:FindFirstChild("Torso") :: BasePart

	local charRootPart = character.PrimaryPart :: BasePart
	local charTorso = character:FindFirstChild("Torso") :: BasePart

	local toolJoint = charTorso:FindFirstChild("ToolJoint") :: Motor6D
	toolJoint.Part0 = thisTorso

	self._thisRootJoint = thisRootPart:FindFirstChild("RootJoint") :: Motor6D
	self._thisLeftShoulder = thisTorso:FindFirstChild("Left Shoulder") :: Motor6D
	self._thisRightShoulder = thisTorso:FindFirstChild("Right Shoulder") :: Motor6D

	self._charRootJoint = charRootPart:FindFirstChild("RootJoint") :: Motor6D
	self._charLeftShoulder = charTorso:FindFirstChild("Left Shoulder") :: Motor6D
	self._charRightShoulder = charTorso:FindFirstChild("Right Shoulder") :: Motor6D

	self._cframeValue = self._trove:Add(CreateCFrameValue(character:FindFirstChildOfClass("Humanoid") :: Humanoid))

	self._trove:Connect(RunService.PreRender, function()
		self:_onPreRender()
	end)
end

function Viewmodel._onPreRender(self: self)
	local cframe = Camera.CFrame
	self.Instance:PivotTo(cframe * self._cframeValue.Value + cframe.UpVector * CAMERA_OFFSET)

	self._thisRootJoint.Transform = self._charRootJoint.Transform
	self._thisLeftShoulder.Transform = self._charLeftShoulder.Transform
	self._thisRightShoulder.Transform = self._charRightShoulder.Transform
end

return Viewmodel
