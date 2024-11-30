--!strict

local Grid = {
	SIZE = 3,
}

function Grid.SnapAxis(axis: number): number
	return math.floor(axis / Grid.SIZE) * Grid.SIZE + (Grid.SIZE / 2)
end

function Grid.SnapNormal(normal: Vector3): Vector3
	local absX = math.abs(normal.X)
	local absY = math.abs(normal.Y)
	local absZ = math.abs(normal.Z)
	if absX > absY and absX > absZ then
		return Vector3.new(math.sign(normal.X), 0, 0) -- Snap to X axis
	elseif absY > absX and absY > absZ then
		return Vector3.new(0, math.sign(normal.Y), 0) -- Snap to Y axis
	else
		return Vector3.new(0, 0, math.sign(normal.Z)) -- Snap to Z axis
	end
end

function Grid.SnapPosition(position: Vector3): Vector3
	local x = Grid.SnapAxis(position.X)
	local y = Grid.SnapAxis(position.Y)
	local z = Grid.SnapAxis(position.Z)
	return Vector3.new(x, y, z)
end

return Grid
