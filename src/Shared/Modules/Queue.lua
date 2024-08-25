--!strict
--!native

export type Queue<T> = {
	Size: (self: Queue<T>) -> number,

	Enqueue: (self: Queue<T>, value: T) -> (),
	Dequeue: (self: Queue<T>) -> T,
}
type self<T> = Queue<T> & {
	_first: number,
	_last: number,

	_values: { T },
}

local Queue = {}
Queue.__index = Queue

function Queue.new<T>(): Queue<T>
	local self = setmetatable({} :: self<T>, Queue)

	self._first = 0
	self._last = -1

	self._values = {}

	return self
end

function Queue.Size<T>(self: self<T>): number
	return self._last - self._first + 1
end

function Queue.Enqueue<T>(self: self<T>, value: T)
	self._last += 1
	self._values[self._last] = value
end
function Queue.Dequeue<T>(self: self<T>): T
	if self._first > self._last then
		error("Queue is empty!")
	end

	local value = self._values[self._first]
	self._values[self._first] = nil
	self._first += 1

	return value
end

return Queue
