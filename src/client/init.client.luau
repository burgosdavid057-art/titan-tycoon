--!strict
-- init.client.luau — bootstrap del cliente.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Controllers = script.Controllers
local GrappleController = require(Controllers.GrappleController)
local AnimationController = require(Controllers.AnimationController)
local CombatController = require(Controllers.CombatController)
local UIController = require(Controllers.UIController)
local WheelController = require(Controllers.WheelController)

AnimationController.Init()
GrappleController.Init()
CombatController.Init()
UIController.Init()
WheelController.Init()

Remotes.DataLoaded.OnClientEvent:Connect(function(profile)
	print(("[Client] Perfil cargado — Nivel %d | Monedas %d | Esencia %d"):format(
		profile.Nivel, profile.Monedas, profile.Esencia
	))
end)

print("[Client] Titan Tycoon v0.6 — cliente iniciado")
