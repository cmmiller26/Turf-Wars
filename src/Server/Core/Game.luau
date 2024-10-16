--!strict

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local GamePlayerHandler = require(ServerScriptService.Server.Classes.GamePlayerHandler)

local Game = {}

local function onPlayerAdded(player)
	GamePlayerHandler.new(player)
end
local function onPlayerRemoving(player)
	local handler = GamePlayerHandler.GetHandlerFromPlayer(player)
	if handler then
		handler:Destroy()
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

return Game
