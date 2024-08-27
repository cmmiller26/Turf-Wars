--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage.Packages.Trove)

local CreateViewmodel = require(script.CreateViewmodel)
local CreateCFrameValue = require(script.CreateCFrameValue)

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

local CAMERA_OFFSET = -1.5

local Camera = Workspace.CurrentCamera

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

	do
		local thisRootPart = self.Instance.PrimaryPart :: BasePart
		local thisTorso = self.Instance:FindFirstChild("Torso") :: BasePart

		local charRootPart = character.PrimaryPart :: BasePart

		local charTorso = character:FindFirstChild("Torso") :: Instance
		local toolJoint = charTorso:FindFirstChild("ToolJoint") :: Motor6D
		toolJoint.Part0 = thisTorso

		self._thisRootJoint = thisRootPart:FindFirstChild("RootJoint") :: Motor6D
		self._thisLeftShoulder = thisTorso:FindFirstChild("Left Shoulder") :: Motor6D
		self._thisRightShoulder = thisTorso:FindFirstChild("Right Shoulder") :: Motor6D

		local charRootJoint = charRootPart:FindFirstChild("RootJoint") :: Motor6D
		assert(
			typeof(charRootJoint) == "Instance" and charRootJoint:IsA("Motor6D"),
			"Viewmodel._init(): Expected 'RootJoint' Motor6D in Character.PrimaryPart, got " .. typeof(charRootJoint)
		)
		local charLeftShoulder = charTorso:FindFirstChild("Left Shoulder") :: Motor6D
		assert(
			typeof(charLeftShoulder) == "Instance" and charLeftShoulder:IsA("Motor6D"),
			"Viewmodel._init(): Expected 'Left Shoulder' Motor6D in Character.Torso, got " .. typeof(charLeftShoulder)
		)
		local charRightShoulder = charTorso:FindFirstChild("Right Shoulder") :: Motor6D
		assert(
			typeof(charRightShoulder) == "Instance" and charRightShoulder:IsA("Motor6D"),
			"Viewmodel._init(): Expected 'Right Shoulder' Motor6D in Character.Torso, got " .. typeof(charRightShoulder)
		)
		self._charRootJoint = charRootJoint
		self._charLeftShoulder = charLeftShoulder
		self._charRightShoulder = charRightShoulder
	end

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
