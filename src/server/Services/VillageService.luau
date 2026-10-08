--!strict
-- VillageService.luau — La aldea de cada jugador (el "tycoon"):
--   · 6 parcelas alrededor del mapa; cada jugador reclama una al entrar
--   · Edificios comprables/mejorables que producen Monedas o Esencia
--   · Muro con vida que los titanes atacan; roto = la producción se detiene
--   · Cuartel reduce el daño que recibe el muro
--
-- Todo el estado permanente vive en el perfil (DataService); aquí solo vive
-- el estado runtime (vida actual del muro, referencias a parts).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local TextureService = require(script.Parent.TextureService)

local V = Config.Village

local VillageService = {}

local plotsFolder = Instance.new("Folder")
plotsFolder.Name = "Plots"

local PLOT_COUNT = 6
local PLOT_RADIUS = 210     -- distancia del centro del mapa a cada parcela
local PLOT_SIZE = 90

type VillageState = {
	player: Player,
	plotIndex: number,
	center: Vector3,
	folder: Folder,
	wallParts: { Part },
	buildingParts: { [string]: Part },
	muroVida: number,
	muroVidaMax: number,
	muroRoto: boolean,
	esenciaAcc: number,
	monedasAcc: number,
}

local villages: { [Player]: VillageState } = {}
local plotTaken: { [number]: Player? } = {}

-- colores placeholder por edificio (fase 4 = modelos reales)
local BUILDING_COLORS: { [string]: Color3 } = {
	Granja = Color3.fromRGB(110, 180, 80),
	Mina = Color3.fromRGB(120, 120, 130),
	Altar = Color3.fromRGB(170, 90, 255),
	Cuartel = Color3.fromRGB(200, 90, 70),
}
-- posición de cada edificio dentro de la parcela
local BUILDING_SLOTS: { [string]: Vector3 } = {
	Granja = Vector3.new(-22, 0, -22),
	Mina = Vector3.new(22, 0, -22),
	Altar = Vector3.new(-22, 0, 22),
	Cuartel = Vector3.new(22, 0, 22),
}

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------

local function edificioCfg(id: string): any?
	for _, e in V.Edificios do
		if e.id == id then
			return e
		end
	end
	return nil
end

local function wallMaxHealth(muroNivel: number): number
	return math.floor(V.MuroVidaBase * V.MuroVidaGrowth ^ (muroNivel - 1))
end

local function wallHeight(muroNivel: number): number
	return 16 + muroNivel * 2
end

local function buildingCost(id: string, nivelActual: number): number
	local cfg = edificioCfg(id)
	return cfg and math.floor(cfg.costoBase * V.CostoGrowth ^ nivelActual) or math.huge
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

----------------------------------------------------------------
-- Sincronización con el cliente
----------------------------------------------------------------

local function pushUpdate(player: Player)
	local v = villages[player]
	local profile = DataService.Get(player)
	if not v or not profile then
		return
	end

	local edificios = {}
	local costos = { edificios = {} :: { [string]: number } }
	for _, e in V.Edificios do
		local nivel = profile.Aldea.Edificios[e.id] or 0
		edificios[e.id] = nivel
		if nivel < V.MaxNivelEdificio then
			(costos.edificios :: any)[e.id] = buildingCost(e.id, nivel)
		end
	end

	local muroNivel = profile.Aldea.MuroNivel
	Remotes.VillageUpdate:FireClient(player, {
		muroNivel = muroNivel,
		muroVida = math.floor(v.muroVida),
		muroVidaMax = v.muroVidaMax,
		muroRoto = v.muroRoto,
		muroCosto = muroNivel < V.MaxMuroNivel and math.floor(V.MuroCostoBase * V.MuroCostoGrowth ^ (muroNivel - 1)) or nil,
		repararCosto = math.ceil((v.muroVidaMax - v.muroVida) * V.RepairCostPerHP),
		edificios = edificios,
		costos = costos,
	})
end

----------------------------------------------------------------
-- Construcción física de la parcela
----------------------------------------------------------------

local function buildBuilding(v: VillageState, id: string, nivel: number)
	local old = v.buildingParts[id]
	if old then
		old:Destroy()
	end
	if nivel <= 0 then
		return
	end
	local slot = BUILDING_SLOTS[id] or Vector3.zero
	local height = 8 + nivel * 1.5
	local b = part({
		Name = "Edificio_" .. id,
		Size = Vector3.new(14, height, 14),
		Position = v.center + slot + Vector3.new(0, height / 2 + 1, 0),
		Color = BUILDING_COLORS[id] or Color3.fromRGB(150, 150, 150),
		Material = Enum.Material.WoodPlanks,
		Parent = v.folder,
	})
	TextureService.ApplyWood(b)
	-- letrero con nombre y nivel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 120, 0, 22)
	gui.StudsOffset = Vector3.new(0, height / 2 + 2, 0)
	gui.MaxDistance = 200
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	local cfg = edificioCfg(id)
	label.Text = ((cfg and cfg.nombre) or id) .. " Nv." .. nivel
	label.Parent = gui
	gui.Parent = b
	v.buildingParts[id] = b
end

local function refreshWallLook(v: VillageState)
	local ratio = v.muroVidaMax > 0 and v.muroVida / v.muroVidaMax or 0
	for _, w in v.wallParts do
		if v.muroRoto then
			w.Transparency = 0.65
			w.CanCollide = false
			w.Color = Color3.fromRGB(80, 70, 65)
		else
			w.Transparency = 0
			w.CanCollide = true
			-- se oscurece a medida que pierde vida
			w.Color = Color3.fromRGB(140, 138, 130):Lerp(Color3.fromRGB(70, 60, 55), 1 - ratio)
		end
	end
end

local function buildPlot(player: Player, plotIndex: number, profile: any): VillageState
	local angle = (plotIndex / PLOT_COUNT) * math.pi * 2
	local center = Vector3.new(math.cos(angle) * PLOT_RADIUS, 0, math.sin(angle) * PLOT_RADIUS)

	local folder = Instance.new("Folder")
	folder.Name = "Plot_" .. player.Name

	local floor = part({
		Name = "SueloAldea",
		Size = Vector3.new(PLOT_SIZE, 1, PLOT_SIZE),
		Position = center + Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(110, 145, 75),
		Material = Enum.Material.Grass,
		Parent = folder,
	})
	TextureService.ApplyGrass(floor)

	-- letrero de dueño
	local post = part({
		Name = "Letrero",
		Size = Vector3.new(1, 8, 1),
		Position = center + Vector3.new(0, 4, -PLOT_SIZE / 2 - 3),
		Color = Color3.fromRGB(120, 90, 60),
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 200, 0, 30)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.MaxDistance = 400
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 225, 150)
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = "Aldea de " .. player.DisplayName
	label.Parent = gui
	gui.Parent = post

	-- 4 muros perimetrales
	local muroNivel = profile.Aldea.MuroNivel
	local h = wallHeight(muroNivel)
	local half = PLOT_SIZE / 2
	local wallParts = {}
	local wallDefs = {
		{ Vector3.new(0, h / 2, -half), Vector3.new(PLOT_SIZE + 4, h, 4) },
		{ Vector3.new(0, h / 2, half), Vector3.new(PLOT_SIZE + 4, h, 4) },
		{ Vector3.new(-half, h / 2, 0), Vector3.new(4, h, PLOT_SIZE + 4) },
		{ Vector3.new(half, h / 2, 0), Vector3.new(4, h, PLOT_SIZE + 4) },
	}
	for i, def in wallDefs do
		local w = part({
			Name = "MuroAldea" .. i,
			Size = def[2],
			Position = center + def[1],
			Color = Color3.fromRGB(140, 138, 130),
			Material = Enum.Material.Brick,
			Parent = folder,
		})
		w:SetAttribute("OwnerUserId", player.UserId)
		TextureService.ApplyStone(w)
		table.insert(wallParts, w)
	end

	folder.Parent = plotsFolder

	local maxHp = wallMaxHealth(muroNivel)
	local v: VillageState = {
		player = player,
		plotIndex = plotIndex,
		center = center,
		folder = folder,
		wallParts = wallParts,
		buildingParts = {},
		muroVida = maxHp,
		muroVidaMax = maxHp,
		muroRoto = false,
		esenciaAcc = 0,
		monedasAcc = 0,
	}

	-- reconstruir edificios ya comprados (persistidos)
	for id, nivel in profile.Aldea.Edificios do
		buildBuilding(v, id, nivel)
	end

	return v
end

----------------------------------------------------------------
-- API para TitanService
----------------------------------------------------------------

-- Muro no roto más cercano a `pos`. Devuelve (part, distancia, dueño)
function VillageService.NearestWall(pos: Vector3): (Part?, number, Player?)
	local best: Part? = nil
	local bestDist = math.huge
	local bestOwner: Player? = nil
	for player, v in villages do
		if not v.muroRoto then
			for _, w in v.wallParts do
				local d = (w.Position - pos).Magnitude
				if d < bestDist then
					bestDist = d
					best = w
					bestOwner = player
				end
			end
		end
	end
	return best, bestDist, bestOwner
end

function VillageService.DamageWall(owner: Player, amount: number)
	local v = villages[owner]
	local profile = DataService.Get(owner)
	if not v or v.muroRoto or not profile then
		return
	end

	-- el Cuartel reduce el daño recibido
	local cuartel = profile.Aldea.Edificios.Cuartel or 0
	local reduction = math.min(cuartel * V.CuartelReduccion, 0.5)
	local dmg = amount * (1 - reduction)

	v.muroVida = math.max(0, v.muroVida - dmg)
	if v.muroVida <= 0 then
		v.muroRoto = true
	end
	refreshWallLook(v)
	pushUpdate(owner)
end

----------------------------------------------------------------
-- Acciones del cliente
----------------------------------------------------------------

local function onVillageAction(player: Player, payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local data = payload :: { action: unknown, id: unknown }
	local action = data.action
	if type(action) ~= "string" then
		return
	end

	local v = villages[player]
	local profile = DataService.Get(player)
	if not v or not profile then
		return
	end

	if action == "get" then
		pushUpdate(player)
		return
	end

	if action == "buy" then
		local id = data.id
		if type(id) ~= "string" or not edificioCfg(id) then
			return
		end
		local nivel = profile.Aldea.Edificios[id] or 0
		if nivel >= V.MaxNivelEdificio then
			return
		end
		local cost = buildingCost(id, nivel)
		if DataService.TrySpend(player, "Monedas", cost) then
			profile.Aldea.Edificios[id] = nivel + 1
			buildBuilding(v, id, nivel + 1)
			pushUpdate(player)
		end
		return
	end

	if action == "upgradeWall" then
		local nivel = profile.Aldea.MuroNivel
		if nivel >= V.MaxMuroNivel then
			return
		end
		local cost = math.floor(V.MuroCostoBase * V.MuroCostoGrowth ^ (nivel - 1))
		if DataService.TrySpend(player, "Monedas", cost) then
			profile.Aldea.MuroNivel = nivel + 1
			v.muroVidaMax = wallMaxHealth(nivel + 1)
			v.muroVida = v.muroVidaMax -- mejora = reparación completa
			v.muroRoto = false
			-- muros más altos
			local h = wallHeight(nivel + 1)
			for _, w in v.wallParts do
				w.Size = Vector3.new(w.Size.X > w.Size.Z and w.Size.X or 4, h, w.Size.Z > w.Size.X and w.Size.Z or 4)
				w.Position = Vector3.new(w.Position.X, h / 2, w.Position.Z)
			end
			refreshWallLook(v)
			pushUpdate(player)
		end
		return
	end

	if action == "repair" then
		if v.muroVida >= v.muroVidaMax then
			return
		end
		local cost = math.ceil((v.muroVidaMax - v.muroVida) * V.RepairCostPerHP)
		if DataService.TrySpend(player, "Monedas", cost) then
			v.muroVida = v.muroVidaMax
			v.muroRoto = false
			refreshWallLook(v)
			pushUpdate(player)
		end
		return
	end
end

----------------------------------------------------------------
-- Producción
----------------------------------------------------------------

local function productionTick()
	for player, v in villages do
		if v.muroRoto then
			continue -- muro roto = producción detenida
		end
		local profile = DataService.Get(player)
		if not profile then
			continue
		end
		local mult = DataService.GetRebirthMult(player)
		for _, e in V.Edificios do
			local nivel = profile.Aldea.Edificios[e.id] or 0
			if nivel > 0 then
				if e.produce == "Monedas" then
					v.monedasAcc += e.baseRate * nivel * mult
				elseif e.produce == "Esencia" then
					v.esenciaAcc += (e.baseRate * nivel * mult) / 60 -- baseRate es por minuto
				end
			end
		end
		if v.monedasAcc >= 1 then
			local whole = math.floor(v.monedasAcc)
			v.monedasAcc -= whole
			DataService.AddMonedas(player, whole)
		end
		if v.esenciaAcc >= 1 then
			local whole = math.floor(v.esenciaAcc)
			v.esenciaAcc -= whole
			DataService.AddEsencia(player, whole)
		end
	end
end

-- Reconstruye la parcela desde el perfil (usado tras un rebirth)
function VillageService.Rebuild(player: Player)
	local v = villages[player]
	local profile = DataService.Get(player)
	if not v or not profile then
		return
	end
	local plotIndex = v.plotIndex
	v.folder:Destroy()
	villages[player] = buildPlot(player, plotIndex, profile)
	pushUpdate(player)
end

----------------------------------------------------------------
-- Ciclo de vida
----------------------------------------------------------------

local function onPlayerAdded(player: Player)
	-- esperar a que DataService cargue el perfil
	task.spawn(function()
		local profile = DataService.Get(player)
		while not profile and player.Parent do
			task.wait(0.2)
			profile = DataService.Get(player)
		end
		if not profile then
			return
		end

		local plotIndex: number? = nil
		for i = 1, PLOT_COUNT do
			if not plotTaken[i] then
				plotIndex = i
				break
			end
		end
		if not plotIndex then
			warn("[VillageService] Sin parcelas libres para", player.Name)
			return
		end
		plotTaken[plotIndex] = player
		villages[player] = buildPlot(player, plotIndex, profile)
		pushUpdate(player)
		print(("[VillageService] %s reclamó la parcela %d"):format(player.Name, plotIndex))
	end)
end

local function onPlayerRemoving(player: Player)
	local v = villages[player]
	if v then
		plotTaken[v.plotIndex] = nil
		v.folder:Destroy()
		villages[player] = nil
	end
end

function VillageService.Init()
	plotsFolder.Parent = Workspace
	Remotes.VillageAction.OnServerEvent:Connect(onVillageAction)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			productionTick()
		end
	end)
	print("[VillageService] listo — " .. PLOT_COUNT .. " parcelas")
end

return VillageService
