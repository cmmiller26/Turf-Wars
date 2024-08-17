--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Packages.Loader)

Loader.LoadChildren(script.Core)
Loader.LoadChildren(script.Handlers, Loader.MatchesName("Handler$"))
