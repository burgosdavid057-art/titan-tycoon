--!strict
-- CompanionService.luau — Rueda gacha + compañeros de combate.
--   · Tirada: costo en monedas, probabilidad por peso de rareza, pity a 50
--   · Compañeros equipados (máx 3) flotan junto al jugador y atacan titanes
--   · Todo persiste en el perfil (uid incremental por compañero)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local TitanService = require(script.Parent.TitanService)

local CP = Config.Companions

local CompanionService = {}

local petsFolder = Instance.new("Folder")
petsFolder.Name = "Companions"

type PetState = {
	part: Part,
	dps: number,
	attackAcc: number,
	orbitOffset: number,
}

-- pets activos por jugador
local activePets: { [Player]: { PetState } } = {}

----------------------------------------------------------------
-- Rueda
----------------------------------------------------------------

local LEGENDARY_PLUS = { "Legendario", "Mitico", "Secreto" }

local function isLegendaryPlus(rarityId: string): boolean
	return table.find(LEGENDARY_PLUS, rarityId) ~= nil
end

local function weightedRoll(pool: { any }): any
	local total = 0
	for _, r in pool do
		total += r.peso
	end
	local roll = math.random() * total
	local acc = 0
	for _, r in pool do
		acc += r.peso
		if roll <= acc then
			return r
		end
	end
	return pool[#pool]
end

local function rollRarity(profile: any): string
	if profile.TiradasSinLegendario + 1 >= Config.Wheel.PityLegendario then
		-- pity: garantizado Legendario o superior (pesos relativos entre ellos)
		local pool = {}
		for _, r in Config.Rarities do
			if isLegendaryPlus(r.id) then
				table.insert(pool, r)
			end
		end
		return weightedRoll(pool).id
	end
	return weightedRoll(Config.Rarities).id
end

local function pushCompanions(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	Remotes.CompanionsUpdate:FireClient(player, {
		companeros = profile.Companeros,
		maxEquipados = CP.MaxEquipados,
		pity = profile.TiradasSinLegendario,
		pityMax = Config.Wheel.PityLegendario,
	})
end

local function rebuildPets(player: Player)
	-- destruir los actuales
	local current = activePets[player]
	if current then
		for _, pet in current do
			pet.part:Destroy()
		end
	end
	activePets[player] = {}

	local profile = DataService.Get(player)
	if not profile then
		return
	end

	local i = 0
	for _, comp in profile.Companeros do
		if comp.equipado then
			i += 1
			local rarity = Config.getRarity(comp.rareza)
			local color = rarity and rarity.color or Color3.fromRGB(200, 200, 200)

			-- buscar dps en el pool
			local dps = 5
			local pool = (CP.Pool :: any)[comp.rareza]
			if pool then
				for _, def in pool do
					if def.id == comp.id then
						dps = def.dps
						break
					end
				end
			end

			local part = Instance.new("Part")
			part.Name = "Pet_" .. player.Name .. "_" .. comp.uid
			part.Shape = Enum.PartType.Ball
			part.Size = Vector3.new(2, 2, 2)
			part.Color = color
			part.Material = comp.rareza == "Secreto" and Enum.Material.Neon or Enum.Material.SmoothPlastic
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false

			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.new(0, 110, 0, 18)
			gui.StudsOffset = Vector3.new(0, 2, 0)
			gui.MaxDistance = 120
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBold
			label.TextScaled = true
			label.TextColor3 = color
			label.TextStrokeTransparency = 0.5
			local nombre = comp.id
			if pool then
				for _, def in pool do
					if def.id == comp.id then
						nombre = def.nombre
						break
					end
				end
			end
			label.Text = nombre
			label.Parent = gui
			gui.Parent = part

			part.Parent = petsFolder

			table.insert(activePets[player], {
				part = part,
				dps = dps,
				attackAcc = 0,
				orbitOffset = i * (math.pi * 2 / CP.MaxEquipados),
			})
		end
	end
end

----------------------------------------------------------------
-- Handlers
----------------------------------------------------------------

local function onSpin(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	if not DataService.TrySpend(player, "Monedas", Config.Wheel.CostoTirada) then
		Remotes.WheelResult:FireClient(player, { error = "Monedas insuficientes" })
		return
	end

	local rarityId = rollRarity(profile)
	if isLegendaryPlus(rarityId) then
		profile.TiradasSinLegendario = 0
	else
		profile.TiradasSinLegendario += 1
	end

	local pool = (CP.Pool :: any)[rarityId]
	local def = pool[math.random(1, #pool)]

	local uid = profile.NextCompanionUid
	profile.NextCompanionUid += 1
	table.insert(profile.Companeros, {
		uid = uid,
		id = def.id,
		rareza = rarityId,
		equipado = false,
	})

	Remotes.WheelResult:FireClient(player, {
		uid = uid,
		id = def.id,
		nombre = def.nombre,
		rareza = rarityId,
		dps = def.dps,
	})
	pushCompanions(player)
end

local function onCompanionAction(player: Player, payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local data = payload :: { action: unknown, uid: unknown }
	if type(data.action) ~= "string" or type(data.uid) ~= "number" then
		return
	end
	local profile = DataService.Get(player)
	if not profile then
		return
	end

	local target: any = nil
	local equippedCount = 0
	for _, comp in profile.Companeros do
		if comp.equipado then
			equippedCount += 1
		end
		if comp.uid == data.uid then
			target = comp
		end
	end
	if not target then
		return
	end

	if data.action == "equip" and not target.equipado then
		if equippedCount >= CP.MaxEquipados then
			return
		end
		target.equipado = true
	elseif data.action == "unequip" and target.equipado then
		target.equipado = false
	else
		return
	end

	rebuildPets(player)
	pushCompanions(player)
end

----------------------------------------------------------------
-- Movimiento + combate de los pets
----------------------------------------------------------------

local clock = 0

local function onHeartbeat(dt: number)
	clock += dt
	for player, pets in activePets do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then
			continue
		end
		local rootPos = (root :: BasePart).Position

		-- titán más cercano al jugador (objetivo compartido de los pets)
		local targetTitan: Model? = nil
		local bestDist = CP.AttackRange
		for _, titanModel in TitanService.Folder:GetChildren() do
			if titanModel:IsA("Model") then
				local state = TitanService.GetState(titanModel :: Model)
				if state and not state.dead then
					local d = ((titanModel :: Model):GetPivot().Position - rootPos).Magnitude
					if d < bestDist then
						bestDist = d
						targetTitan = titanModel :: Model
					end
				end
			end
		end

		for _, pet in pets do
			-- orbita flotando alrededor del jugador
			local angle = clock * 0.8 + pet.orbitOffset
			local goal = rootPos + Vector3.new(math.cos(angle) * 6, 3 + math.sin(clock * 2 + pet.orbitOffset) * 0.5, math.sin(angle) * 6)
			pet.part.Position = pet.part.Position:Lerp(goal, math.clamp(dt * 6, 0, 1))

			-- ataque
			pet.attackAcc += dt
			if pet.attackAcc >= CP.AttackTick then
				pet.attackAcc = 0
				if targetTitan then
					TitanService.TakeDamage(targetTitan, pet.dps * CP.AttackTick, player)
				end
			end
		end
	end
end

----------------------------------------------------------------

function CompanionService.Init()
	petsFolder.Parent = Workspace
	Remotes.SpinWheel.OnServerEvent:Connect(onSpin)
	Remotes.CompanionAction.OnServerEvent:Connect(onCompanionAction)
	RunService.Heartbeat:Connect(onHeartbeat)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			while not DataService.Get(player) and player.Parent do
				task.wait(0.2)
			end
			if player.Parent then
				rebuildPets(player)
				pushCompanions(player)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local pets = activePets[player]
		if pets then
			for _, pet in pets do
				pet.part:Destroy()
			end
			activePets[player] = nil
		end
	end)

	print("[CompanionService] listo — rueda: " .. Config.Wheel.CostoTirada .. " monedas/tirada")
end

return CompanionService
