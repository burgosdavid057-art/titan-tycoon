--!strict
-- Remotes.luau — punto único de comunicación cliente<->servidor.
-- El servidor los crea; el cliente los espera. Nadie más hace Instance.new de remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTE_NAMES = {
	-- Fase 1
	"DataLoaded",        -- server -> client: perfil listo
	-- Fase 2
	"MeleeHit",          -- client -> server: intento de corte a un titán
	"WaveStarted",       -- server -> client: nueva oleada
	"TitanKilled",       -- server -> client: feedback de kill
	"BossKilled",        -- server -> client: subida de progreso de nivel
	"SpinWheel",         -- client -> server: pedir tirada de la rueda
	"WheelResult",       -- server -> client: resultado de la tirada
	"CompanionAction",   -- client -> server: {action="equip"|"unequip", uid=n}
	"CompanionsUpdate",  -- server -> client: inventario + pity
	"EventStarted",      -- server -> client: evento especial activo
	"Rebirth",           -- client -> server: pedir rebirth
	-- Fase 3
	"VillageAction",     -- client -> server: {action="buy"|"upgradeWall"|"repair"|"get", id=?}
	"VillageUpdate",     -- server -> client: estado completo de la aldea
}

local Remotes: { [string]: RemoteEvent } = {}

if RunService:IsServer() then
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in REMOTE_NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
	for _, name in REMOTE_NAMES do
		Remotes[name] = folder:FindFirstChild(name) :: RemoteEvent
	end
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in REMOTE_NAMES do
		Remotes[name] = folder:WaitForChild(name) :: RemoteEvent
	end
end

return Remotes
