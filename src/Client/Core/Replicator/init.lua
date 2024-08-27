--!strict

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LoadSlingshotConfig = require(ReplicatedStorage.Config.LoadSlingshotConfig)

local ProjectileCaster = require(ReplicatedFirst.Client.Modules.ProjectileCaster)

local MAX_TILT_DISTANCE = 100
local JOINT_CFRAMES = {
	Neck = CFrame.new(0, 1, 0),
	LeftShoulder = CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	RightShoulder = CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
}

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Remotes = ReplicatedStorage.Remotes

local TILT_SEND_RATE = Remotes.Character.Tilt.SendRate.Value

local Replicator = {}

function Replicator.OnCharacterTilt(character: Model, angle: number)
	if character == LocalPlayer.Character then
		return
	end

	local distance = (Camera.CFrame.Position - character:GetPivot().Position).Magnitude
	if distance > MAX_TILT_DISTANCE then
		return
	end

	local torso = character:FindFirstChild("Torso")
	if not torso then
		warn("Replicator.OnCharacterTilt(): Could not find 'Torso' in " .. character.Name)
		return
	end

	local neck = torso:FindFirstChild("Neck") :: Motor6D
	local leftShoulder = torso:FindFirstChild("Left Shoulder") :: Motor6D
	local rightShoulder = torso:FindFirstChild("Right Shoulder") :: Motor6D
	local toolJoint = torso:FindFirstChild("ToolJoint") :: Motor6D

	local tweenInfo = TweenInfo.new(TILT_SEND_RATE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(neck, tweenInfo, {
		C0 = JOINT_CFRAMES.Neck * CFrame.Angles(angle + math.rad(-90), 0, math.rad(180)),
	}):Play()

	local leftShoulderC0 = JOINT_CFRAMES.LeftShoulder
	local rightShoulderC0 = JOINT_CFRAMES.RightShoulder

	if toolJoint.Part1 then
		leftShoulderC0 *= CFrame.Angles(0, 0, -angle)
		rightShoulderC0 *= CFrame.Angles(0, 0, angle)

		TweenService:Create(toolJoint, tweenInfo, {
			C0 = CFrame.Angles(angle, 1.55, 0) * CFrame.fromEulerAnglesXYZ(0, -math.pi / 2, 0),
		}):Play()
	end

	--[[
		Only tween the shoulder joints if the new C0 is different from the current C0
		This prevents unnecessary tweens when the character is not holding a tool
	]]
	if leftShoulder.C0 ~= leftShoulderC0 then
		TweenService:Create(leftShoulder, tweenInfo, {
			C0 = leftShoulderC0,
		}):Play()
		TweenService:Create(rightShoulder, tweenInfo, {
			C0 = rightShoulderC0,
		}):Play()
	end
end

function Replicator.OnSlingshotFire(slingshot: Model, origin: Vector3, direction: Vector3, speed: number)
	local character = slingshot.Parent
	if not character or character == LocalPlayer.Character then
		return
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local configuration = slingshot:FindFirstChildOfClass("Configuration")
	assert(
		configuration,
		"Replicator.OnSlingshotFire(): Could not find Configuration in " .. character.Name .. "'s Slingshot"
	)

	local config = LoadSlingshotConfig(configuration)
	local projectileModifier: ProjectileCaster.Modifier = {
		Speed = speed,
		Gravity = config.Gravity,
		Lifetime = config.Lifetime,
		PVInstance = config.Projectile,
	}

	ProjectileCaster.Cast(origin, direction, raycastParams, projectileModifier)
end

do
	Remotes.Character.Tilt.OnClientEvent:Connect(Replicator.OnCharacterTilt)

	Remotes.Slingshot.Fire.OnClientEvent:Connect(Replicator.OnSlingshotFire)
end

return Replicator
