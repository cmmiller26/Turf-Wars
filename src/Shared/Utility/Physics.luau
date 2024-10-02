--!native
--!strict

local Physics = {}

function Physics.CalculatePosition(x0: Vector3, v0: Vector3, a: Vector3, t: number): Vector3
	return x0 + v0 * t + 0.5 * a * t * t
end
function Physics.CalculateVelocity(v0: Vector3, a: Vector3, t: number): Vector3
	return v0 + a * t
end

return Physics
