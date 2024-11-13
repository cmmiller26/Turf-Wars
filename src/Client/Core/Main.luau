--!strict

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = ReplicatedFirst.Client
local Types = require(Client.Types)

local CharacterController = Client.Classes.CharacterController
local LobbyCharacterController = require(CharacterController.LobbyCharacterController)
local RoundCharacterController = require(CharacterController.RoundCharacterController)

local LocalPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage.Remotes

local Main = {}

local function onSpawn(controllerType: string, character: Model)
	local controller: Types.CharacterController
	if controllerType == "LobbyCharacter" then
		controller = LobbyCharacterController.new(character)
	elseif controllerType == "RoundCharacter" then
		controller = RoundCharacterController.new(character)
	end

	LocalPlayer.CharacterRemoving:Once(function()
		controller:Destroy()
	end)
end

Remotes.Character.Spawn.OnClientEvent:Connect(onSpawn)

return Main
