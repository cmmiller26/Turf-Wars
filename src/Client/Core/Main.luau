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
local combatEnabled = false

local function onSpawn(characterType: SharedTypes.CharacterType, character: Model)
	character:WaitForChild("Torso"):WaitForChild("Neck")

	if characterType == "LobbyCharacter" then
		charController = LobbyCharacterController.new(character)
	elseif characterType == "RoundCharacter" then
		local roundCharController = RoundCharacterController.new(character)
		roundCharController:SetCombatEnabled(combatEnabled)
		charController = roundCharController
	end
end

local function onEnableCombat(enable: boolean)
	combatEnabled = enable
	if charController and charController:IsA("RoundCharacter") then
		(charController :: ClientTypes.RoundCharacterController):SetCombatEnabled(enable)
	end
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
