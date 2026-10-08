--!strict
-- init.server.luau — bootstrap del servidor. Orden de arranque explícito.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Crear remotes primero (los clientes los esperan)
require(ReplicatedStorage.Shared.Remotes)

local Services = script.Services

local MapService = require(Services.MapService)
local TextureService = require(Services.TextureService)
local DataService = require(Services.DataService)
local VillageService = require(Services.VillageService)
local TitanService = require(Services.TitanService)
local CombatService = require(Services.CombatService)
local CompanionService = require(Services.CompanionService)
local EventService = require(Services.EventService)
local RebirthService = require(Services.RebirthService)
local LeaderboardService = require(Services.LeaderboardService)
local WeaponService = require(Services.WeaponService)

MapService.Init()
TextureService.Init()
DataService.Init()
VillageService.Init()
TitanService.Init()
CombatService.Init()
CompanionService.Init()
EventService.Init()
RebirthService.Init()
LeaderboardService.Init()
WeaponService.Init()

print("[Server] Titan Tycoon — servidor iniciado (fase 5 completa)")
