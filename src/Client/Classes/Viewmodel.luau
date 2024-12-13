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
local ClientTypes = require(ReplicatedFirst.Client.ClientTypes)

type Viewmodel = ClientTypes.Viewmodel
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

--[[
	Creates a new viewmodel for the given user ID.
	@param userID number
	@return Model
]]
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

--[[
	Creates a new CFrameValue to animate the viewmodel based on the humanoid's state.
	@param humanoid Humanoid
	@return CFrameValue
]]
local function CreateCFrameValue(humanoid: Humanoid): CFrameValue
	local cframeValue = Instance.new("CFrameValue")

	local trove = Trove.new()
	cframeValue.Destroying:Connect(function()
		trove:Clean()
	end)

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
	The [Model] that represents the player's viewmodel.
	@prop Instance Model
	@within Viewmodel
]=]

--[=[
	The [Trove] used to manage the viewmodel's connections and resources.
	@prop _trove Trove
	@private
	@within Viewmodel
]=]
--[=[
	The viewmodel's "RootJoint" [Motor6D].
	@prop _thisRootJoint Motor6D
	@private
	@within Viewmodel
]=]
--[=[
	The viewmodel's "Left Shoulder" [Motor6D].
	@prop _thisLeftShoulder Motor6D
	@private
	@within Viewmodel
]=]
--[=[
	The viewmodel's "Right Shoulder" [Motor6D].
	@prop _thisRightShoulder Motor6D
	@private
	@within Viewmodel
]=]
--[=[
	The character's "RootJoint" [Motor6D].
	@prop _charRootJoint Motor6D
	@private
	@within Viewmodel
]=]
--[=[
	The character's "Left Shoulder" [Motor6D].
	@prop _charLeftShoulder Motor6D
	@private
	@within Viewmodel
]=]
--[=[
	The character's "Right Shoulder" [Motor6D].
	@prop _charRightShoulder Motor6D
	@private
	@within Viewmodel
]=]
--[=[
	The [CFrameValue] used to animate the viewmodel.
	@prop _cframeValue CFrameValue
	@private
	@within Viewmodel
]=]

--[=[
	A Viewmodel represents the [Model] attached to a player's camera, which is used to display the player's arms and tools.
	The viewmodel is generated from a character model and is synchronized with that character's joints.
	@class Viewmodel
	@client
]=]
local Viewmodel = {}

local VPublicMethods = {}
local VPrivateMethods = {}

--[=[
	Constructs a new `Viewmodel` based on the given character model.
	@param character Model
	@return Viewmodel
	@within Viewmodel
]=]
function Viewmodel.new(character: Model): Viewmodel
	local self = setmetatable({} :: VInternal, { __index = CreateMultiIndex(VPublicMethods, VPrivateMethods) })

	self:_init(character)

	return self
end

--[=[
	Cleans up all connections and resources used by the viewmodel.
	@method Destroy
	@within Viewmodel
]=]
function VPublicMethods.Destroy(self: VInternal): ()
	self._trove:Clean()
end

--[=[
	Initializes the viewmodel based on the given character model, setting up the viewmodel's animations and connections.
	@method _init
	@param character Model
	@private
	@within Viewmodel
]=]
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

--[=[
	Processes pre-render updates, attaching the viewmodel to the camera and transforming its joints to match the character's joints.
	@method _onPreRender
	@private
	@within Viewmodel
]=]
function VPrivateMethods._onPreRender(self: VInternal): ()
	local cframe = Camera.CFrame
	self.Instance:PivotTo(cframe * self._cframeValue.Value + cframe.UpVector * CAMERA_OFFSET)

	-- Synchronize the viewmodel's joints with the character's joints
	self._thisRootJoint.Transform = self._charRootJoint.Transform
	self._thisLeftShoulder.Transform = self._charLeftShoulder.Transform
	self._thisRightShoulder.Transform = self._charRightShoulder.Transform
end

return Viewmodel
