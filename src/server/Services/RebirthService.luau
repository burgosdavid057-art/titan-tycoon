--!strict
-- RebirthService.luau — maneja la petición de rebirth del cliente:
-- valida en DataService y reconstruye la aldea (que se resetea con el rebirth).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local VillageService = require(script.Parent.VillageService)

local RebirthService = {}

function RebirthService.Init()
	Remotes.Rebirth.OnServerEvent:Connect(function(player)
		local ok = DataService.DoRebirth(player)
		if ok then
			VillageService.Rebuild(player)
			print("[RebirthService]", player.Name, "renació")
		end
	end)
	print("[RebirthService] listo")
end

return RebirthService
