--!strict
-- TitanService.luau — Titanes greybox: modelo construido por código, IA de
-- persecución, oleadas con jefes y muerte con recompensas.
--
-- Los titanes son modelos ANCLADOS movidos con PivotTo (sin Humanoid): cero
-- problemas de física con rigs gigantes, y en fase 4 se reemplaza el cuerpo
-- por meshes con rig real sin tocar la IA.
--
-- Punto débil: la parte "Nuca" (atrás del cuello). CombatService aplica el
-- multiplicador al validar el golpe.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local VillageService = require(script.Parent.VillageService)
local TextureService = require(script.Parent.TextureService)

local W = Config.Waves

local TitanService = {}

local titansFolder = Instance.new("Folder")
titansFolder.Name = "Titans"
TitanService.Folder = titansFolder

type TitanState = {
	model: Model,
	typeId: string,
	cfg: any,
	health: number,
	maxHealth: number,
	height: number,
	attackClock: number,
	bobClock: number,
	dead: boolean,
	barFill: Frame?,
}

local titans: { [Model]: TitanState } = {}
local waveNumber = 0

-- modificadores de eventos (los controla EventService)
local lootMultiplier = 1
local forceAnormal = false

function TitanService.SetLootMultiplier(mult: number)
	lootMultiplier = mult
end

function TitanService.SetForceAnormal(force: boolean)
	forceAnormal = force
end

----------------------------------------------------------------
-- Construcción del modelo greybox
----------------------------------------------------------------

local function block(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Anchored = true
	part.CanCollide = true
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function buildTitan(typeId: string, cfg: any, spawnPos: Vector3): Model
	local H = cfg.altura
	local model = Instance.new("Model")
	model.Name = cfg.nombre

	local origin = CFrame.new(spawnPos.X, H / 2, spawnPos.Z)

	-- torso = PrimaryPart (el pivot del modelo)
	local torso = block("Torso",
		Vector3.new(H * 0.30, H * 0.33, H * 0.15),
		origin * CFrame.new(0, H * 0.09, 0),
		cfg.color, model)

	-- piernas
	for i, x in { -H * 0.08, H * 0.08 } do
		block("Pierna" .. i,
			Vector3.new(H * 0.12, H * 0.42, H * 0.12),
			origin * CFrame.new(x, -H * 0.29, 0),
			cfg.color, model)
	end

	-- brazos
	for i, x in { -(H * 0.15 + H * 0.05), H * 0.15 + H * 0.05 } do
		block("Brazo" .. i,
			Vector3.new(H * 0.09, H * 0.34, H * 0.09),
			origin * CFrame.new(x, H * 0.07, 0),
			cfg.color, model)
	end

	-- cabeza (mira hacia -Z, la dirección de avance)
	local head = block("Cabeza",
		Vector3.new(H * 0.14, H * 0.14, H * 0.12),
		origin * CFrame.new(0, H * 0.33, 0),
		cfg.color, model)

	-- NUCA — punto débil, atrás del cuello (+Z = espalda)
	local nuca = block("Nuca",
		Vector3.new(H * 0.10, H * 0.07, H * 0.03),
		origin * CFrame.new(0, H * 0.27, H * 0.085),
		Color3.fromRGB(190, 60, 50), model)
	nuca.Material = Enum.Material.Neon

	-- barra de vida flotante
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Size = UDim2.new(0, 160, 0, 18)
	gui.StudsOffset = Vector3.new(0, H * 0.12, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 500
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 200, 70)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	gui.Parent = head

	-- textura de piel (si hay ID asignado en AssetIds)
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "Nuca" then
			TextureService.ApplyTitanSkin(part)
		end
	end

	model.PrimaryPart = torso
	model:SetAttribute("Type", typeId)
	model:SetAttribute("MaxHealth", cfg.vida)
	model:SetAttribute("Health", cfg.vida)
	model.Parent = titansFolder

	return model
end

----------------------------------------------------------------
-- Spawning y oleadas
----------------------------------------------------------------

local function aliveCount(): number
	local n = 0
	for _, state in titans do
		if not state.dead then
			n += 1
		end
	end
	return n
end

function TitanService.Spawn(typeId: string): Model?
	local cfg = (Config.Titans :: any)[typeId]
	if not cfg then
		return nil
	end
	local angle = math.random() * math.pi * 2
	local radius = math.random(W.SpawnRadiusMin, W.SpawnRadiusMax)
	local pos = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)

	local model = buildTitan(typeId, cfg, pos)
	local head = model:FindFirstChild("Cabeza")
	local bar = head and head:FindFirstChild("HealthBar")
	local fill = bar and (bar :: BillboardGui):FindFirstChild("Fill", true)

	titans[model] = {
		model = model,
		typeId = typeId,
		cfg = cfg,
		health = cfg.vida,
		maxHealth = cfg.vida,
		height = cfg.altura,
		attackClock = 0,
		bobClock = math.random() * math.pi * 2,
		dead = false,
		barFill = fill :: Frame?,
	}
	return model
end

local function waveLoop()
	while true do
		task.wait(W.Interval)
		waveNumber += 1
		local isBossWave = (waveNumber % W.BossEvery) == 0
		local count = W.BaseCount + math.floor(waveNumber * W.CountGrowth)
		count = math.max(math.min(count, W.MaxAlive - aliveCount()), 0)

		for _ = 1, count do
			local typeId = (forceAnormal or math.random() < W.AnormalChance) and "Anormal" or "Normal"
			TitanService.Spawn(typeId)
			task.wait(0.4) -- escalonado, no todos de golpe
		end
		if isBossWave and aliveCount() < W.MaxAlive + 1 then
			TitanService.Spawn("Jefe")
		end

		Remotes.WaveStarted:FireAllClients(waveNumber, count, isBossWave)
		print(("[TitanService] Oleada %d — %d titanes%s"):format(waveNumber, count, isBossWave and " + JEFE" or ""))
	end
end

----------------------------------------------------------------
-- IA — perseguir jugador más cercano (o la aldea) y atacar
----------------------------------------------------------------

local function nearestPlayerRoot(pos: Vector3): (BasePart?, number)
	local best: BasePart? = nil
	local bestDist = math.huge
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local d = ((root :: BasePart).Position - pos).Magnitude
			if d < bestDist then
				bestDist = d
				best = root :: BasePart
			end
		end
	end
	return best, bestDist
end

local function updateTitan(state: TitanState, dt: number)
	local model = state.model
	local pivot = model:GetPivot()
	local pos = pivot.Position
	local H = state.height

	-- objetivo: lo más cercano entre un jugador vivo y un muro de aldea intacto
	local targetRoot, playerDist = nearestPlayerRoot(pos)
	local wallPart, wallDist, wallOwner = VillageService.NearestWall(pos)

	local targetPos: Vector3
	local targetKind: string
	if targetRoot and (not wallPart or playerDist <= wallDist) then
		targetPos = (targetRoot :: BasePart).Position
		targetKind = "player"
	elseif wallPart then
		targetPos = wallPart.Position
		targetKind = "wall"
	else
		targetPos = Vector3.zero -- nada que atacar: deambula hacia el centro
		targetKind = "none"
	end

	local flatDir = Vector3.new(targetPos.X - pos.X, 0, targetPos.Z - pos.Z)
	local flatDist = flatDir.Magnitude
	local reach = H * 0.25 + 5

	local newPos = pos
	if flatDist > reach then
		local step = math.min(state.cfg.velocidad * dt, flatDist - reach)
		newPos = pos + flatDir.Unit * step
	end

	-- zona segura: los titanes no entran a la plaza central (anti spawn-camping)
	local safeR = W.SafeZoneRadius
	local flatNew = Vector3.new(newPos.X, 0, newPos.Z)
	if flatNew.Magnitude < safeR then
		if flatNew.Magnitude > 0.5 then
			flatNew = flatNew.Unit * safeR
		else
			flatNew = Vector3.new(safeR, 0, 0)
		end
		newPos = Vector3.new(flatNew.X, newPos.Y, flatNew.Z)
	end

	-- bamboleo al caminar (placeholder de animación de fase 4)
	state.bobClock += dt * (state.cfg.velocidad * 0.35)
	local bob = math.sin(state.bobClock) * H * 0.012
	local sway = math.sin(state.bobClock) * 0.03

	local baseY = H / 2 + bob
	local lookAt = Vector3.new(targetPos.X, baseY, targetPos.Z)
	local newCF: CFrame
	if flatDist > 0.5 then
		newCF = CFrame.lookAt(Vector3.new(newPos.X, baseY, newPos.Z), lookAt) * CFrame.Angles(0, 0, sway)
	else
		newCF = CFrame.new(Vector3.new(newPos.X, baseY, newPos.Z))
	end
	model:PivotTo(newCF)

	-- ataque por proximidad (1 golpe/seg)
	state.attackClock += dt
	if state.attackClock >= 1 then
		state.attackClock = 0
		if targetKind == "player" and targetRoot and playerDist <= reach + 6 then
			local char = (targetRoot :: BasePart).Parent
			local humanoid = char and char:FindFirstChildOfClass("Humanoid")
			if humanoid then
				(humanoid :: Humanoid):TakeDamage(state.cfg.dano)
			end
		elseif targetKind == "wall" and wallOwner and flatDist <= reach + 8 then
			VillageService.DamageWall(wallOwner, state.cfg.dano)
		end
	end
end

----------------------------------------------------------------
-- Daño y muerte
----------------------------------------------------------------

function TitanService.GetState(model: Model): TitanState?
	return titans[model]
end

local function die(state: TitanState, killer: Player?)
	state.dead = true
	local model = state.model
	titans[model] = nil

	if killer then
		-- el multiplicador de evento se aplica aquí; el de rebirth en DataService
		local recompensa = {
			monedas = math.floor(state.cfg.monedas * lootMultiplier),
			esencia = math.floor(state.cfg.esencia * lootMultiplier),
		}
		DataService.RegisterKill(killer, state.typeId, recompensa)
		Remotes.TitanKilled:FireClient(killer, state.typeId, recompensa)
	end

	-- caída simple: se desploma hacia adelante y se desvanece
	task.spawn(function()
		local pivot = model:GetPivot()
		local steps = 20
		for i = 1, steps do
			local alpha = i / steps
			model:PivotTo(pivot * CFrame.Angles(-alpha * math.rad(85), 0, 0))
			task.wait(0.03)
		end
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end
		task.wait(1.5)
		for i = 1, 10 do
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					part.Transparency = i / 10
				end
			end
			task.wait(0.08)
		end
		model:Destroy()
	end)
end

function TitanService.TakeDamage(model: Model, amount: number, attacker: Player?)
	local state = titans[model]
	if not state or state.dead then
		return
	end
	state.health = math.max(0, state.health - amount)
	model:SetAttribute("Health", state.health)

	if state.barFill then
		state.barFill.Size = UDim2.fromScale(state.health / state.maxHealth, 1)
		local ratio = state.health / state.maxHealth
		state.barFill.BackgroundColor3 = Color3.fromRGB(
			math.floor(90 + (1 - ratio) * 140), math.floor(200 * ratio + 40 * (1 - ratio)), 60)
	end

	if state.health <= 0 then
		die(state, attacker)
	end
end

----------------------------------------------------------------

function TitanService.Init()
	titansFolder.Parent = Workspace
	RunService.Heartbeat:Connect(function(dt)
		for _, state in titans do
			if not state.dead then
				updateTitan(state, dt)
			end
		end
	end)
	task.spawn(waveLoop)
	print("[TitanService] listo — primera oleada en " .. W.Interval .. "s")
end

return TitanService
