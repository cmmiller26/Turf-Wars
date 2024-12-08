--!native
--!strict

local Physics = {}

function Physics.CalculatePosition(x0: Vector3, v0: Vector3, a: Vector3, t: number): Vector3
	return x0 + v0 * t + 0.5 * a * t * t
end
function Physics.CalculateVelocity(v0: Vector3, a: Vector3, t: number): Vector3
	return v0 + a * t
end

function Physics.GetMass(instance: Instance): number
	local mass = 0
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			mass += descendant.Mass
		end
	end
	return mass
end

return Physics
