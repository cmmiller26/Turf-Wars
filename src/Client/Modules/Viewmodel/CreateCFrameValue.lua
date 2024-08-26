--!strict

local TweenService = game:GetService("TweenService")

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

return CreateCFrameValue
