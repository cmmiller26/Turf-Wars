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
local ClientTypes = require(ReplicatedFirst.Client.ClientTypes)

type TiltCharacter = ClientTypes.TiltCharacter
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

--[=[
	The character [Model] the tilt character tweens the joints of.
	@prop Instance Model
	@within TiltCharacter
]=]
--[=[
	Fired when the tilt character's neck is destroyed.
	@prop Destroying Signal
	@within TiltCharacter
]=]

--[=[
	The [Trove] used to manage the tilt character's resources.
	@prop _trove Trove
	@private
	@within TiltCharacter
]=]
--[=[
	The last angle the tilt character was updated to.
	@prop _lastAngle number
	@private
	@within TiltCharacter
]=]
--[=[
	The neck [Motor6D] of the tilt character.
	@prop _neck Motor6D
	@private
	@within TiltCharacter
]=]
--[=[
	The left shoulder [Motor6D] of the tilt character.
	@prop _leftShoulder Motor6D
	@private
	@within TiltCharacter
]=]
--[=[
	The right shoulder [Motor6D] of the tilt character.
	@prop _rightShoulder Motor6D
	@private
	@within TiltCharacter
]=]
--[=[
	The tool joint [Motor6D] of the tilt character.
	@prop _toolJoint Motor6D?
	@private
	@within TiltCharacter
]=]
--[=[
	The [TweenInfo] used to tween the tilt character's joints.
	@prop _tweenInfo TweenInfo
	@private
	@within TiltCharacter
]=]

--[=[
	TiltCharacter manages the tweening of an R6 character model's joints to visually represent the direction a character is looking.
	It is primarily used to replicate the tilt of other players' characters in multiplayer scenarios, providing a more immersive 
	and dynamic gameplay experience. The class can also be applied to the local player's character in third-person views.

	### Core Features:
	- **Neck and Shoulder Animation**: Tweens the neck and shoulder joints to align with the target tilt angle.
	- **Tool Integration**: Adjusts the shoulder and tool joint positions dynamically when a tool is equipped.
	- **Distance-Based Optimization**: Disables tilt rendering for characters that are too far from the camera to improve performance.
	- **Smooth Transitions**: Uses [TweenService] for smooth and visually appealing joint transitions.

	### Highlights:
	- **Dynamic Tilt Updates**: Continuously updates the character's tilt based on the provided angle, ensuring real-time responsiveness.
	- **Customizable Tweening**: Leverages [TweenInfo] for flexible control over the speed and style of joint animations.
	- **Event Integration**: Emits a `Destroying` [Signal] when the tilt character is destroyed, allowing for cleanup and additional handling.

	### Implementation Notes:
	- The class is designed for R6 character models and relies on specific joints (`Neck`, `Left Shoulder`, `Right Shoulder`, and optionally `ToolJoint`).
	- Ensure the character model includes these joints for the class to function properly.

	@class TiltCharacter
	@client
]=]
local TiltCharacter = {}

local TCPublicMethods = {}
local TCPrivateMethods = {}

--[=[
	Constructs a new `TiltCharacter` for the given character [Model].
	@param instance Model
	@param sendRate number -- The rate at which tilt updates will be sent to the server.
	@return TiltCharacter
	@within TiltCharacter
]=]
function TiltCharacter.new(instance: Model, sendRate: number): TiltCharacter
	local self = setmetatable({} :: TCInternal, { __index = CreateMultiIndex(TCPublicMethods, TCPrivateMethods) })

	self:_init(instance, sendRate)

	return self
end

--[=[
	Updates the tilt of the character to the given angle.
	@method Update
	@param angle number? -- If not provided, the character will update to the previous angle.
	@within TiltCharacter
]=]
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

--[=[
	Initializes the tilt character with the given character [Model] and send rate, constructing the `Destroying` [Signal] and setting up the necessary joints.
	@method _init
	@param instance Model
	@param sendRate number
	@private
	@within TiltCharacter
]=]
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
