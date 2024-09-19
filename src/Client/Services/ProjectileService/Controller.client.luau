--disable
--!strict

local Actor: Actor = script.Parent

Actor:BindToMessage("Initialize", function(moduleScript: ModuleScript)
	(require(moduleScript) :: any).Initialize(Actor)
end)