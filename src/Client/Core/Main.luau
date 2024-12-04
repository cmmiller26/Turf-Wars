--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Client modules
local Client = ReplicatedFirst.Client
local Types = require(Client.Types)

local CharacterController = Client.Classes.CharacterController
local LobbyCharacterController = require(CharacterController.LobbyCharacterController)
local RoundCharacterController = require(CharacterController.RoundCharacterController)

-- Player-related variables
local LocalPlayer = Players.LocalPlayer

-- Remote events folder
local Remotes = ReplicatedStorage.Remotes

local Main = {}

local controller: Types.CharacterController?

local function onSpawn(controllerType: string, character: Model)
	local newController: Types.CharacterController
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
	if controller and controller:IsA("RoundCharacterController") then
		(controller :: Types.RoundCharacterController):SetCombatEnabled(enable)
	end
end

Remotes.Character.Spawn.OnClientEvent:Connect(onSpawn)
Remotes.Character.EnableCombat.OnClientEvent:Connect(onEnableCombat)

return Main
