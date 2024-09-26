--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Packages.Loader)

Loader.LoadChildren(script.Services)
Loader.LoadChildren(script.Core)
