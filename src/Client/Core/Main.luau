--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Client modules
local Client = ReplicatedFirst.Client
local SharedTypes = require(ReplicatedStorage.SharedTypes)
local ClientTypes = require(Client.ClientTypes)

local CharacterController = Client.Classes.CharacterController
local LobbyCharacterController = require(CharacterController.LobbyCharacterController)
local RoundCharacterController = require(CharacterController.RoundCharacterController)

-- Player-related variables
local LocalPlayer = Players.LocalPlayer

-- Remote events folder
local Remotes = ReplicatedStorage.Remotes

local Main = {}

local charController: ClientTypes.CharacterController?

local function onSpawn(characterType: SharedTypes.CharacterType, character: Model)
	repeat
		task.wait()
	until character:FindFirstChildOfClass("Humanoid")

	if characterType == "LobbyCharacter" then
		charController = LobbyCharacterController.new(character)
	elseif characterType == "RoundCharacter" then
		charController = RoundCharacterController.new(character)
	end
end

local function onEnableCombat(enable: boolean)
	if not (charController and charController:IsA("RoundCharacter")) then
		warn("[Main.onEnableCombat]: Character controller does not exist or is not a RoundCharacter")
		return
	end
	(charController :: ClientTypes.RoundCharacterController):SetCombatEnabled(enable)
end

local function onCharacterRemoving()
	if charController then
		charController:Destroy()
		charController = nil
	end
end

Remotes.Character.Spawn.OnClientEvent:Connect(onSpawn)
Remotes.Character.EnableCombat.OnClientEvent:Connect(onEnableCombat)

LocalPlayer.CharacterRemoving:Connect(onCharacterRemoving)

return Main
