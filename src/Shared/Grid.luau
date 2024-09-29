--!strict

local Grid = {
	SIZE = 3,
}

function Grid.SnapAxis(axis: number): number
	return math.floor(axis / Grid.SIZE) * Grid.SIZE + (Grid.SIZE / 2)
end
function Grid.SnapPosition(position: Vector3): Vector3
	local x = Grid.SnapAxis(position.X)
	local y = Grid.SnapAxis(position.Y)
	local z = Grid.SnapAxis(position.Z)
	return Vector3.new(x, y, z)
end

return Grid
