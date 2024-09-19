--!strict

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local GamePlayerHandler = require(ServerScriptService.Server.Classes.GamePlayerHandler)

local HandlerManager = {}

local gamePlayerHandlers: { [number]: GamePlayerHandler.GamePlayerHandler } = {}

do
	local function OnPlayerAdded(player: Player)
		gamePlayerHandlers[player.UserId] = GamePlayerHandler.new(player)
	end
	local function OnPlayerRemoving(player: Player)
		gamePlayerHandlers[player.UserId]:Destroy()
		gamePlayerHandlers[player.UserId] = nil
	end

	Players.PlayerAdded:Connect(OnPlayerAdded)
	Players.PlayerRemoving:Connect(OnPlayerRemoving)
end

return HandlerManager
