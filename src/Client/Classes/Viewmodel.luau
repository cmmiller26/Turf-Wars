--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- External dependencies
local Trove = require(ReplicatedStorage.Packages.Trove)
local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

-- Client modules
local Types = require(ReplicatedFirst.Client.Types)

type Viewmodel = Types.Viewmodel
type VInternal = Viewmodel & {
	_trove: Trove.Trove,

	_thisRootJoint: Motor6D,
	_thisLeftShoulder: Motor6D,
	_thisRightShoulder: Motor6D,

	_charRootJoint: Motor6D,
	_charLeftShoulder: Motor6D,
	_charRightShoulder: Motor6D,

	_cframeValue: CFrameValue,

	_init: (self: VInternal, character: Model) -> (),

	_onPreRender: (self: VInternal) -> (),
}

-- Constants
local ARM_SIZE = Vector3.new(0.5, 2, 0.5)
local CAMERA_OFFSET = -1.5
local USER_ID = RunService:IsStudio() and 107484074 or Players.LocalPlayer.UserId
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

-- Camera reference
local Camera = Workspace.CurrentCamera

local function CreateViewmodel(): Model
	local viewmodel = Players:CreateHumanoidModelFromUserId(USER_ID, Enum.HumanoidRigType.R6)
	viewmodel.Name = "Viewmodel"

	local rootPart = viewmodel:FindFirstChild("HumanoidRootPart") :: BasePart
	rootPart.Anchored = true
	viewmodel.PrimaryPart = rootPart

	-- Set up the Humanoid
	local humanoid = viewmodel:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.EvaluateStateMachine = false
	humanoid.RequiresNeck = false

	-- Get rid of unnecessary parts
	for _, descendant in ipairs(viewmodel:GetDescendants()) do
		if not VALID_CHILDREN[descendant.Name] then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			-- Make sure the parts don't affect the character
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
			fallTween:Cancel()

			landTween1:Play()
		elseif newState == Enum.HumanoidStateType.Freefall then
			landTween1:Cancel()
			landTween2:Cancel()

			fallTween:Play()
		end
	end)

	-- Destroy the tweens when the CFrameValue is destroyed
	cframeValue.Destroying:Connect(function()
		landTween1:Destroy()
		landTween2:Destroy()

		fallTween:Destroy()

		connection:Disconnect()
	end)

	return cframeValue
end

--[=[
	A Viewmodel is used to display a players's arms in first person.
	It is attached to the camera and replicates the player's third person arms.
	The class also handles weapon sway and jumping/landing animations.
]=]
local Viewmodel = {}

local VPublicMethods = {}
local VPrivateMethods = {}

--[=[
	Constructs a Viewmodel for the given character.
	@param character The character to create the Viewmodel for
	@return Viewmodel
]=]
function Viewmodel.new(character: Model): Viewmodel
	local self = setmetatable({} :: VInternal, { __index = CreateMultiIndex(VPublicMethods, VPrivateMethods) })

	self:_init(character)

	return self
end

--[=[
	Destroys the Viewmodel, cleaning up any resources.
]=]
function VPublicMethods.Destroy(self: Viewmodel): ()
	(self :: VInternal)._trove:Clean()
end

function VPrivateMethods._init(self: VInternal, character: Model): ()
	self._trove = Trove.new()

	-- Create the viewmodel, parenting it to the camera
	self.Instance = self._trove:Add(CreateViewmodel())
	self.Instance.Parent = Camera

	-- Assumes all the viewmodel joints exist
	local thisRootPart = self.Instance.PrimaryPart :: BasePart
	local thisTorso = self.Instance:FindFirstChild("Torso") :: BasePart
	self._thisRootJoint = thisRootPart:FindFirstChild("RootJoint") :: Motor6D
	self._thisLeftShoulder = thisTorso:FindFirstChild("Left Shoulder") :: Motor6D
	self._thisRightShoulder = thisTorso:FindFirstChild("Right Shoulder") :: Motor6D

	-- Assumes all the character joints exist
	local charRootPart = character.PrimaryPart :: BasePart
	local charTorso = character:FindFirstChild("Torso") :: BasePart
	self._charRootJoint = charRootPart:FindFirstChild("RootJoint") :: Motor6D
	self._charLeftShoulder = charTorso:FindFirstChild("Left Shoulder") :: Motor6D
	self._charRightShoulder = charTorso:FindFirstChild("Right Shoulder") :: Motor6D

	-- Attach the tool joint to the viewmodel
	local toolJoint = charTorso:FindFirstChild("ToolJoint") :: Motor6D
	toolJoint.Part0 = thisTorso

	-- Create a CFrameValue to handle the viewmodel's animations
	self._cframeValue = self._trove:Add(CreateCFrameValue(character:FindFirstChildOfClass("Humanoid") :: Humanoid))

	self._trove:Connect(RunService.PreRender, function()
		self:_onPreRender()
	end)
end

function VPrivateMethods._onPreRender(self: VInternal)
	-- Attach the viewmodel to the camera
	local cframe = Camera.CFrame
	self.Instance:PivotTo(cframe * self._cframeValue.Value + cframe.UpVector * CAMERA_OFFSET)

	-- Synchronize the viewmodel's joints with the character's joints
	self._thisRootJoint.Transform = self._charRootJoint.Transform
	self._thisLeftShoulder.Transform = self._charLeftShoulder.Transform
	self._thisRightShoulder.Transform = self._charRightShoulder.Transform
end

return Viewmodel
