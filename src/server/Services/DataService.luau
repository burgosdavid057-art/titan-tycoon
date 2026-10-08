--!strict
-- DataService.luau — carga/guardado del perfil del jugador (DataStore).
-- El perfil ya incluye los campos de fases futuras (compañeros, aldea, rebirth)
-- para no tener que migrar datos después.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Config = require(ReplicatedStorage.Shared.Config)

local STORE_NAME = "PlayerData_v1"
local AUTOSAVE_INTERVAL = 120

local DataService = {}
DataService.Profiles = {} :: { [Player]: any }

local store = nil
if not RunService:IsStudio() then
	store = DataStoreService:GetDataStore(STORE_NAME)
else
	-- En Studio también intentamos (funciona si el juego está publicado con API activada)
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	store = ok and result or nil
end

local function defaultProfile()
	return {
		Version = 1,
		Monedas = 0,
		Esencia = 0,
		Nivel = 1,
		JefesMatados = 0,       -- total histórico
		JefesNivelActual = 0,   -- progreso hacia el siguiente nivel
		TitanesMatados = 0,
		Rebirths = 0,
		TiradasSinLegendario = 0, -- contador pity de la rueda
		NextCompanionUid = 1,
		Companeros = {},          -- { {uid, id, rareza, equipado} }
		Aldea = {
			MuroNivel = 1,
			Edificios = {},       -- { [edificioId] = nivel }
		},
	}
end

local function loadProfile(player: Player)
	local profile = defaultProfile()
	if store then
		local ok, saved = pcall(function()
			return store:GetAsync("p_" .. player.UserId)
		end)
		if ok and saved then
			-- merge: lo guardado pisa los defaults, los campos nuevos quedan
			for key, value in saved do
				profile[key] = value
			end
		elseif not ok then
			warn("[DataService] Error cargando datos de", player.Name, saved)
		end
	end
	DataService.Profiles[player] = profile

	-- leaderstats visibles en la lista de jugadores
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local nivel = Instance.new("IntValue")
	nivel.Name = "Nivel"
	nivel.Value = profile.Nivel
	nivel.Parent = stats
	local monedas = Instance.new("IntValue")
	monedas.Name = "Monedas"
	monedas.Value = profile.Monedas
	monedas.Parent = stats
	stats.Parent = player

	-- atributos replicados: la UI del cliente los lee directamente
	player:SetAttribute("Monedas", profile.Monedas)
	player:SetAttribute("Esencia", profile.Esencia)
	player:SetAttribute("Nivel", profile.Nivel)
	player:SetAttribute("JefesProgreso", profile.JefesNivelActual)
	player:SetAttribute("JefesNecesarios", Config.Levels.bossesForLevel(profile.Nivel))
	player:SetAttribute("Rebirths", profile.Rebirths)

	Remotes.DataLoaded:FireClient(player, profile)
end

local function saveProfile(player: Player)
	local profile = DataService.Profiles[player]
	if not profile or not store then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync("p_" .. player.UserId, profile)
	end)
	if not ok then
		warn("[DataService] Error guardando datos de", player.Name, err)
	end
end

-- API pública para otros servicios
function DataService.Get(player: Player)
	return DataService.Profiles[player]
end

function DataService.AddMonedas(player: Player, amount: number)
	local profile = DataService.Profiles[player]
	if profile then
		profile.Monedas += amount
		player:SetAttribute("Monedas", profile.Monedas)
		local stats = player:FindFirstChild("leaderstats")
		local monedas = stats and stats:FindFirstChild("Monedas")
		if monedas then
			(monedas :: IntValue).Value = profile.Monedas
		end
	end
end

function DataService.AddEsencia(player: Player, amount: number)
	local profile = DataService.Profiles[player]
	if profile then
		profile.Esencia += amount
		player:SetAttribute("Esencia", profile.Esencia)
	end
end

-- Intenta gastar; devuelve true si alcanzó el saldo (currency: "Monedas"|"Esencia")
function DataService.TrySpend(player: Player, currency: string, amount: number): boolean
	local profile = DataService.Profiles[player]
	if not profile or amount < 0 then
		return false
	end
	if (profile[currency] or 0) < amount then
		return false
	end
	if currency == "Monedas" then
		DataService.AddMonedas(player, -amount)
	elseif currency == "Esencia" then
		DataService.AddEsencia(player, -amount)
	else
		return false
	end
	return true
end

-- Multiplicador permanente por rebirths (aplica a monedas y esencia ganadas)
function DataService.GetRebirthMult(player: Player): number
	local profile = DataService.Profiles[player]
	if not profile then
		return 1
	end
	return 1 + profile.Rebirths * Config.Rebirth.MultiplicadorPorRebirth
end

-- Ejecuta el rebirth si cumple el nivel requerido. Devuelve (ok, nivelRequerido).
-- La reconstrucción física de la aldea la hace RebirthService via VillageService.
function DataService.DoRebirth(player: Player): (boolean, number)
	local profile = DataService.Profiles[player]
	if not profile then
		return false, 0
	end
	local required = Config.Rebirth.NivelMinimo + profile.Rebirths * Config.Rebirth.IncrementoPorRebirth
	if profile.Nivel < required then
		return false, required
	end

	profile.Rebirths += 1
	profile.Nivel = 1
	profile.JefesNivelActual = 0
	profile.Monedas = 0
	profile.Aldea = { MuroNivel = 1, Edificios = {} }
	-- se conservan: Esencia, Companeros, JefesMatados, TitanesMatados

	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local nivel = stats:FindFirstChild("Nivel")
		if nivel then
			(nivel :: IntValue).Value = 1
		end
		local monedas = stats:FindFirstChild("Monedas")
		if monedas then
			(monedas :: IntValue).Value = 0
		end
	end
	player:SetAttribute("Monedas", 0)
	player:SetAttribute("Nivel", 1)
	player:SetAttribute("JefesProgreso", 0)
	player:SetAttribute("JefesNecesarios", Config.Levels.bossesForLevel(1))
	player:SetAttribute("Rebirths", profile.Rebirths)

	return true, required
end

-- Registra una kill de titán: recompensas y, si es Jefe, progreso de nivel.
-- `recompensa` ya trae el multiplicador de evento; aquí se aplica el de rebirth.
function DataService.RegisterKill(player: Player, typeId: string, recompensa: any)
	local profile = DataService.Profiles[player]
	if not profile then
		return
	end

	local mult = DataService.GetRebirthMult(player)
	profile.TitanesMatados += 1
	DataService.AddEsencia(player, math.floor((recompensa.esencia or 0) * mult))
	DataService.AddMonedas(player, math.floor((recompensa.monedas or 0) * mult))

	if typeId == "Jefe" then
		profile.JefesMatados += 1
		profile.JefesNivelActual += 1

		-- subir de nivel (puede subir varios de golpe)
		local needed = Config.Levels.bossesForLevel(profile.Nivel)
		while profile.JefesNivelActual >= needed and profile.Nivel < Config.Levels.MaxLevel do
			profile.JefesNivelActual -= needed
			profile.Nivel += 1
			needed = Config.Levels.bossesForLevel(profile.Nivel)
		end

		local stats = player:FindFirstChild("leaderstats")
		local nivel = stats and stats:FindFirstChild("Nivel")
		if nivel then
			(nivel :: IntValue).Value = profile.Nivel
		end
		player:SetAttribute("Nivel", profile.Nivel)
		player:SetAttribute("JefesProgreso", profile.JefesNivelActual)
		player:SetAttribute("JefesNecesarios", needed)

		Remotes.BossKilled:FireClient(player, {
			nivel = profile.Nivel,
			progreso = profile.JefesNivelActual,
			necesarios = needed,
		})
	end
end

function DataService.Init()
	Players.PlayerAdded:Connect(loadProfile)
	Players.PlayerRemoving:Connect(function(player)
		saveProfile(player)
		DataService.Profiles[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end

	-- autosave periódico
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				saveProfile(player)
			end
		end
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			saveProfile(player)
		end
	end)
end

return DataService
