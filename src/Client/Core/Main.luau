--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Client modules
local Client = ReplicatedFirst.Client
local ClientTypes = require(Client.ClientTypes)

local CharacterController = Client.Classes.CharacterController
local LobbyCharacterController = require(CharacterController.LobbyCharacterController)
local RoundCharacterController = require(CharacterController.RoundCharacterController)

-- Player-related variables
local LocalPlayer = Players.LocalPlayer

-- Remote events folder
local Remotes = ReplicatedStorage.Remotes

local Main = {}

local controller: ClientTypes.CharacterController?

local function onSpawn(controllerType: string, character: Model)
	repeat
		task.wait()
	until character:FindFirstChildOfClass("Humanoid")

	local newController: ClientTypes.CharacterController
	if controllerType == "LobbyCharacter" then
		newController = LobbyCharacterController.new(character)
	elseif controllerType == "RoundCharacter" then
		newController = RoundCharacterController.new(character)
	end
	controller = newController

	LocalPlayer.CharacterRemoving:Once(function()
		newController:Destroy()
		controller = nil
	end)
end

local function onEnableCombat(enable: boolean)
	repeat
		task.wait()
	until controller;
	(controller :: ClientTypes.RoundCharacterController):SetCombatEnabled(enable)
end

Remotes.Character.Spawn.OnClientEvent:Connect(onSpawn)
Remotes.Character.EnableCombat.OnClientEvent:Connect(onEnableCombat)

return Main
