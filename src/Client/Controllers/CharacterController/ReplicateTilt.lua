--!strict

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TILT_SEND_RATE = 1 / 10

local Camera = Workspace.CurrentCamera

local function ReplicateTilt(remoteEvent: UnreliableRemoteEvent): RBXScriptConnection
	local prevTilt = 0

	local accumulator = 0
	local connection = RunService.PostSimulation:Connect(function(deltaTime: number)
		accumulator += deltaTime
		while accumulator >= TILT_SEND_RATE do
			accumulator -= TILT_SEND_RATE

			local tilt = math.asin(Camera.CFrame.LookVector.Y)
			if tilt ~= prevTilt then
				remoteEvent:FireServer(tilt)
			end
			prevTilt = tilt
		end
	end)

	return connection
end

return ReplicateTilt
