--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local MAX_TILT_DISTANCE = 100
local TILT_RECEIVE_RATE = 1 / 10
local JOINT_CFRAMES = {
	Neck = CFrame.new(0, 1, 0),
	LeftShoulder = CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	RightShoulder = CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
}

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Remotes = ReplicatedStorage.Remotes

local Replicate = {}

function Replicate.onCharacterTilt(player: Player, angle: number): ()
	if player == LocalPlayer then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local distance = (Camera.CFrame.Position - character:GetPivot().Position).Magnitude
	if distance > MAX_TILT_DISTANCE then
		return
	end

	local torso = character:FindFirstChild("Torso")
	if not torso then
		return
	end

	local neck = torso:FindFirstChild("Neck") :: Motor6D
	local leftShoulder = torso:FindFirstChild("Left Shoulder") :: Motor6D
	local rightShoulder = torso:FindFirstChild("Right Shoulder") :: Motor6D
	local toolJoint = torso:FindFirstChild("ToolJoint") :: Motor6D
	if not (neck and leftShoulder and rightShoulder and toolJoint) then
		return
	end

	local tweenInfo = TweenInfo.new(TILT_RECEIVE_RATE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(neck, tweenInfo, {
		C0 = JOINT_CFRAMES.Neck * CFrame.Angles(angle + math.rad(-90), 0, math.rad(180)),
	}):Play()

	local leftShoulderC0 = JOINT_CFRAMES.LeftShoulder
	local rightShoulderC0 = JOINT_CFRAMES.RightShoulder

	local curTool = toolJoint.Part1 and toolJoint.Part1.Parent
	if curTool then
		leftShoulderC0 *= CFrame.Angles(0, 0, -angle)
		rightShoulderC0 *= CFrame.Angles(0, 0, angle)

		TweenService:Create(toolJoint, tweenInfo, {
			C0 = CFrame.Angles(angle, 1.55, 0) * CFrame.fromEulerAnglesXYZ(0, -math.pi / 2, 0),
		}):Play()
	end

	TweenService:Create(leftShoulder, tweenInfo, {
		C0 = leftShoulderC0,
	}):Play()
	TweenService:Create(rightShoulder, tweenInfo, {
		C0 = rightShoulderC0,
	}):Play()
end

do
	Remotes.Character.Tilt.OnClientEvent:Connect(Replicate.onCharacterTilt)
end

return Replicate
