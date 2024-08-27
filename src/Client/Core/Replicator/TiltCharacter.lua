--!strict

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

export type TiltCharacter = {
	Instance: Model,

	Update: (self: TiltCharacter, angle: number) -> (),
}
type self = TiltCharacter & {
	_neck: Motor6D,

	_leftShoulder: Motor6D,
	_rightShoulder: Motor6D,

	_toolJoint: Motor6D,

	_tweenInfo: TweenInfo,

	_init: (self: self, sendRate: number) -> (),
}

local MAX_TILT_DISTANCE = 100

local JOINT_CFRAMES = {
	Neck = CFrame.new(0, 1, 0),
	LeftShoulder = CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	RightShoulder = CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
}

local Camera = Workspace.CurrentCamera

local TiltCharacter = {}
TiltCharacter.__index = TiltCharacter

function TiltCharacter.new(instance: Model, sendRate: number): TiltCharacter
	local self = setmetatable({} :: self, TiltCharacter)

	self.Instance = instance
	self:_init(sendRate)

	return self
end

function TiltCharacter.Update(self: self, angle: number, tweenInfo: TweenInfo)
	local distance = (Camera.CFrame.Position - self.Instance:GetPivot().Position).Magnitude
	if distance > MAX_TILT_DISTANCE then
		return
	end

	TweenService:Create(self._neck, tweenInfo, {
		C0 = JOINT_CFRAMES.Neck * CFrame.Angles(angle + math.rad(-90), 0, math.rad(180)),
	}):Play()

	local leftShoulderC0 = JOINT_CFRAMES.LeftShoulder
	local rightShoulderC0 = JOINT_CFRAMES.RightShoulder

	if self._toolJoint.Part1 then
		leftShoulderC0 *= CFrame.Angles(0, 0, -angle)
		rightShoulderC0 *= CFrame.Angles(0, 0, angle)

		TweenService:Create(self._toolJoint, tweenInfo, {
			C0 = CFrame.Angles(angle, 1.55, 0) * CFrame.fromEulerAnglesXYZ(0, -math.pi / 2, 0),
		}):Play()
	end

	--[[
		Only tween the shoulder joints if the new C0 is different from the current C0
		This prevents unnecessary tweens when the character is not holding a tool
	]]
	if self._leftShoulder.C0 ~= leftShoulderC0 then
		TweenService:Create(self._leftShoulder, tweenInfo, {
			C0 = leftShoulderC0,
		}):Play()
		TweenService:Create(self._rightShoulder, tweenInfo, {
			C0 = rightShoulderC0,
		}):Play()
	end
end

function TiltCharacter._init(self: self, sendRate: number)
	local torso = self.Instance:FindFirstChild("Torso")
	assert(torso, "TiltCharacter._init(): Could not find 'Torso' in " .. self.Instance.Name)

	local neck = torso:FindFirstChild("Neck")
	assert(
		typeof(neck) == "Instance" and neck:IsA("Motor6D"),
		"TiltCharacter._init(): Expected 'Neck' Motor6D in " .. self.Instance.Name .. ".Torso, got " .. typeof(neck)
	)
	self._neck = neck

	local toolJoint = torso:FindFirstChild("ToolJoint")
	assert(
		typeof(toolJoint) == "Instance" and toolJoint:IsA("Motor6D"),
		"TiltCharacter._init(): Expected 'ToolJoint' Motor6D in "
			.. self.Instance.Name
			.. ".Torso, got "
			.. typeof(toolJoint)
	)
	self._toolJoint = toolJoint

	local leftShoulder = torso:FindFirstChild("Left Shoulder")
	assert(
		typeof(leftShoulder) == "Instance" and leftShoulder:IsA("Motor6D"),
		"TiltCharacter._init(): Expected 'Left Shoulder' Motor6D in "
			.. self.Instance.Name
			.. ".Torso, got "
			.. typeof(leftShoulder)
	)
	self._leftShoulder = leftShoulder
	local rightShoulder = torso:FindFirstChild("Right Shoulder")
	assert(
		typeof(rightShoulder) == "Instance" and rightShoulder:IsA("Motor6D"),
		"TiltCharacter._init(): Expected 'Right Shoulder' Motor6D in "
			.. self.Instance.Name
			.. ".Torso, got "
			.. typeof(rightShoulder)
	)
	self._rightShoulder = rightShoulder

	self._tweenInfo = TweenInfo.new(sendRate, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end

return TiltCharacter
