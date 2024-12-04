--!strict

-- Services
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- External dependencies
local Packages = ReplicatedStorage.Packages
local Signal = require(Packages.Signal)
local Trove = require(Packages.Trove)

local CreateMultiIndex = require(ReplicatedStorage.Utility.CreateMultiIndex)

-- Client modules
local Types = require(ReplicatedFirst.Client.Types)

type TiltCharacter = Types.TiltCharacter
type TCInternal = TiltCharacter & {
	_trove: Trove.Trove,

	_lastAngle: number,

	_neck: Motor6D,

	_leftShoulder: Motor6D,
	_rightShoulder: Motor6D,

	_toolJoint: Motor6D?,

	_tweenInfo: TweenInfo,

	_init: (self: TCInternal, instance: Model, sendRate: number) -> (),
}

-- Constants
local MAX_TILT_DISTANCE = 100
local JOINT_CFRAMES = {
	Neck = CFrame.new(0, 1, 0),
	LeftShoulder = CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	RightShoulder = CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
}

-- Player-related variables
local Camera = Workspace.CurrentCamera

local TiltCharacter = {}

local TCPublicMethods = {}
local TCPrivateMethods = {}

--[=[
	Constructs a tilt character for the given character model.
	@param instance -- The character `Model` to tilt.
	@param sendRate -- The rate at which to send tilt updates to the server.
	@return TiltCharacter -- The tilt character instance.
]=]
function TiltCharacter.new(instance: Model, sendRate: number): TiltCharacter
	local self = setmetatable({} :: TCInternal, { __index = CreateMultiIndex(TCPublicMethods, TCPrivateMethods) })

	self:_init(instance, sendRate)

	return self
end

function TCPublicMethods.Update(self: TCInternal, angle: number?): ()
	if angle and angle == self._lastAngle then
		return
	end

	-- Don't render tilt if the player is too far away
	local distance = (Camera.CFrame.Position - self.Instance:GetPivot().Position).Magnitude
	if distance > MAX_TILT_DISTANCE then
		return
	end

	local target = angle or self._lastAngle
	TweenService:Create(self._neck, self._tweenInfo, {
		C0 = JOINT_CFRAMES.Neck * CFrame.Angles(target + math.rad(-90), 0, math.rad(180)),
	}):Play()

	local leftShoulderC0 = JOINT_CFRAMES.LeftShoulder
	local rightShoulderC0 = JOINT_CFRAMES.RightShoulder
	if self._toolJoint and self._toolJoint.Part1 then
		leftShoulderC0 *= CFrame.Angles(0, 0, -target)
		rightShoulderC0 *= CFrame.Angles(0, 0, target)

		TweenService:Create(self._toolJoint, self._tweenInfo, {
			C0 = CFrame.Angles(target, 1.55, 0) * CFrame.fromEulerAnglesXYZ(0, -math.pi / 2, 0),
		}):Play()
	end

	--[[
		Only tween the shoulder joints if the new C0 is different from the current C0
		It allows the shoulders to return to their default position after a tool is unequipped, while preventing unnecessary tweens after that
	]]
	if self._leftShoulder.C0 ~= leftShoulderC0 then
		TweenService:Create(self._leftShoulder, self._tweenInfo, {
			C0 = leftShoulderC0,
		}):Play()
		TweenService:Create(self._rightShoulder, self._tweenInfo, {
			C0 = rightShoulderC0,
		}):Play()
	end

	self._lastAngle = target
end

function TCPrivateMethods._init(self: TCInternal, instance: Model, sendRate: number): ()
	self._trove = Trove.new()

	self.Instance = instance

	self.Destroying = self._trove:Construct(Signal)
	self._trove:Add(function()
		self.Destroying:Fire() -- Fire the destroying signal when the tilt character is destroyed
	end)

	self._lastAngle = 0

	local torso = self.Instance:FindFirstChild("Torso") :: Instance

	self._neck = torso:FindFirstChild("Neck") :: Motor6D
	self._trove:AttachToInstance(self._neck) -- Destroy the tilt character when the neck is destroyed

	self._toolJoint = torso:FindFirstChild("ToolJoint") :: Motor6D

	self._leftShoulder = torso:FindFirstChild("Left Shoulder") :: Motor6D
	self._rightShoulder = torso:FindFirstChild("Right Shoulder") :: Motor6D

	self._tweenInfo = TweenInfo.new(sendRate, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end

return TiltCharacter
