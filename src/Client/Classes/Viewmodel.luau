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
local ARM_SIZE = Vector3.new(0.5, 2, 0.5)

local CAMERA_OFFSET = -1.5

-- Player-related variables
local Camera = Workspace.CurrentCamera

--[=[
	Creates a viewmodel rig for the given user ID.
	@param userID -- The user ID used to create the humanoid model.
	@return Model -- The viewmodel instance
]=]
local function CreateViewmodel(userID: number): Model
	local viewmodel = Players:CreateHumanoidModelFromUserId(userID, Enum.HumanoidRigType.R6)
	viewmodel.Name = "Viewmodel"

	local rootPart = viewmodel:FindFirstChild("HumanoidRootPart") :: BasePart
	rootPart.Anchored = true
	viewmodel.PrimaryPart = rootPart

	local humanoid = viewmodel:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.EvaluateStateMachine = false
	humanoid.RequiresNeck = false

	-- Get rid of unnecessary parts
	for _, descendant in ipairs(viewmodel:GetDescendants()) do
		if not VALID_CHILDREN[descendant.Name] then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			-- Make sure kept parts don't affect the character
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

--[=[
	Creates a cframe value to track falling and landing animations.
	Uses the given humanoid's state to determine when to play the animations.
	@param humanoid -- The `Humanoid` to track the state of for animations.
	@return CFrameValue -- The cframe value instance
]=]
local function CreateCFrameValue(humanoid: Humanoid): CFrameValue
	local cframeValue = Instance.new("CFrameValue")

	local trove = Trove.new()
	trove:AttachToInstance(cframeValue)

	local landTween1 = trove:Add(
		TweenService:Create(cframeValue, TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Value = CFrame.Angles(-math.rad(5), 0, 0),
		})
	)
	local landTween2 = trove:Add(
		TweenService:Create(cframeValue, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Value = CFrame.new(),
		})
	)
	trove:Connect(landTween1.Completed, function()
		if humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
			landTween2:Play()
		end
	end)

	local fallTween = trove:Add(TweenService:Create(cframeValue, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
		Value = CFrame.Angles(math.rad(7.5), 0, 0),
	}))

	trove:Connect(humanoid.StateChanged, function(_, newState)
		if newState == Enum.HumanoidStateType.Landed then
			fallTween:Cancel()

			landTween1:Play()
		elseif newState == Enum.HumanoidStateType.Freefall then
			landTween1:Cancel()
			landTween2:Cancel()

			fallTween:Play()
		end
	end)

	return cframeValue
end

--[=[
	Viewmodel handles the creation and management of a first-person viewmodel rig that synchronizes with the player’s character and camera.

	This class ensures the viewmodel stays in sync with the character's animations and the camera's position, providing smooth and immersive gameplay.
	It supports dynamic state-based animations, collision optimization, and resource cleanup.

	Responsibilities:
	- Create and initialize a simplified viewmodel rig from the player’s avatar.
	- Synchronize viewmodel joints with the character’s joints in real time.
	- Play dynamic landing and falling animations based on the character’s state.
	- Manage resources and clean up connections when destroyed.

	Notes:
	- Assumes the player’s character uses the R6 rig type.
	- Requires a valid `RoundCharacterController` and appropriate avatar setup.
	- Supports collision optimization with a custom collision group.
]=]
local Viewmodel = {}

local VPublicMethods = {}
local VPrivateMethods = {}

--[=[
	Constructs a viewmodel for the given character model.
	@param character -- The character `Model` to create the viewmodel for.
	@return Viewmodel -- The viewmodel instance.
]=]
function Viewmodel.new(character: Model): Viewmodel
	local self = setmetatable({} :: VInternal, { __index = CreateMultiIndex(VPublicMethods, VPrivateMethods) })

	self:_init(character)

	return self
end

--[=[
	Destroys the viewmodel, cleaning up all connections and resources used by it.
]=]
function VPublicMethods.Destroy(self: VInternal): ()
	self._trove:Clean()
end

function VPrivateMethods._init(self: VInternal, character: Model): ()
	self._trove = Trove.new()

	self.Instance = self._trove:Add(CreateViewmodel(USER_ID))
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

	self._cframeValue = self._trove:Add(CreateCFrameValue(character:FindFirstChildOfClass("Humanoid") :: Humanoid))

	self._trove:Connect(RunService.PreRender, function()
		self:_onPreRender()
	end)
end

function VPrivateMethods._onPreRender(self: VInternal): ()
	local cframe = Camera.CFrame
	self.Instance:PivotTo(cframe * self._cframeValue.Value + cframe.UpVector * CAMERA_OFFSET)

	-- Synchronize the viewmodel's joints with the character's joints
	self._thisRootJoint.Transform = self._charRootJoint.Transform
	self._thisLeftShoulder.Transform = self._charLeftShoulder.Transform
	self._thisRightShoulder.Transform = self._charRightShoulder.Transform
end

return Viewmodel
