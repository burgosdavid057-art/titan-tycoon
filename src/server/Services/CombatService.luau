--!strict
-- CombatService.luau — valida los cortes del cliente (anti-exploit básico):
-- cooldown por jugador, distancia real y que el titán exista y esté vivo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TitanService = require(script.Parent.TitanService)

local C = Config.Combat

local CombatService = {}

local lastAttack: { [Player]: number } = {}

local function onMeleeHit(player: Player, titanModel: unknown, hitPartName: unknown)
	-- validación de tipos
	if typeof(titanModel) ~= "Instance" or not (titanModel :: Instance):IsA("Model") then
		return
	end
	if type(hitPartName) ~= "string" then
		return
	end
	local model = titanModel :: Model
	if model.Parent ~= TitanService.Folder then
		return
	end

	local state = TitanService.GetState(model)
	if not state or state.dead then
		return
	end

	-- cooldown (con 10% de tolerancia por latencia)
	local now = os.clock()
	if now - (lastAttack[player] or 0) < C.Cooldown * 0.9 then
		return
	end
	lastAttack[player] = now

	-- distancia real: raíz del jugador vs pivot del titán (son gigantes,
	-- el margen escala con la altura)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local dist = ((root :: BasePart).Position - model:GetPivot().Position).Magnitude
	if dist > C.Range + state.height * 0.5 then
		return
	end

	local damage = C.Damage
	if hitPartName == "Nuca" then
		damage *= C.NapeMultiplier
	end

	TitanService.TakeDamage(model, damage, player)
end

function CombatService.Init()
	Remotes.MeleeHit.OnServerEvent:Connect(onMeleeHit)
	Players.PlayerRemoving:Connect(function(player)
		lastAttack[player] = nil
	end)
	print("[CombatService] listo")
end

return CombatService
