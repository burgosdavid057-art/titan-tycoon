--!strict
-- Config.luau — Toda la configuración de diseño del juego en un solo lugar.
-- Fase 1 usa Grapple y Map; el resto ya queda definido para las fases siguientes.

local Config = {}

----------------------------------------------------------------
-- GANCHO (mecánica central de movimiento, estilo equipo de maniobras)
----------------------------------------------------------------
Config.Grapple = {
	MaxDistance = 350,       -- studs de alcance del raycast
	Stiffness = 650,         -- rigidez del resorte (más = tirón más fuerte)
	Damping = 30,            -- amortiguación (más = menos rebote)
	ReelSpeed = 100,         -- studs/seg de atracción AUTOMÁTICA hacia el anclaje
	GasReelMult = 1.8,       -- con Shift (gas) la atracción es x1.8 más rápida
	MinLength = 8,           -- largo mínimo del cable al recoger
	GasForce = 10000,        -- fuerza del impulso de gas (Shift)
	GasUpFactor = 0.25,      -- componente vertical extra del gas
	AirControlForce = 1400,  -- control WASD en el aire mientras cuelgas
	RopeColor = Color3.fromRGB(240, 240, 240),
	RopeWidth = 0.35,
}

----------------------------------------------------------------
-- COMBATE — espadas; el punto débil es la NUCA (como debe ser)
----------------------------------------------------------------
Config.Combat = {
	Damage = 50,            -- daño base por corte
	NapeMultiplier = 8,     -- multiplicador al golpear la nuca
	Cooldown = 0.45,        -- segundos entre cortes
	Range = 18,             -- alcance del corte (validación del servidor)
	RayLength = 60,         -- largo del raycast del cliente (los titanes son grandes)
}

----------------------------------------------------------------
-- TITANES — tipos, tamaños y recompensas
----------------------------------------------------------------
Config.Titans = {
	Normal = {
		nombre = "Titán",
		altura = 28, vida = 200, velocidad = 8, dano = 15,
		monedas = 25, esencia = 0,
		color = Color3.fromRGB(205, 170, 140),
	},
	Anormal = {
		nombre = "Titán Anormal",
		altura = 22, vida = 350, velocidad = 17, dano = 25,
		monedas = 75, esencia = 1,
		color = Color3.fromRGB(160, 120, 100),
	},
	Jefe = {
		nombre = "Titán Jefe",
		altura = 55, vida = 2500, velocidad = 6, dano = 40,
		monedas = 500, esencia = 10,
		color = Color3.fromRGB(120, 80, 70),
	},
}

Config.Waves = {
	Interval = 40,        -- segundos entre oleadas
	BaseCount = 2,        -- titanes en la oleada 1
	CountGrowth = 0.5,    -- titanes extra por oleada (redondeado)
	AnormalChance = 0.2,  -- probabilidad de que un spawn sea Anormal
	BossEvery = 5,        -- cada N oleadas aparece un Jefe
	MaxAlive = 10,        -- tope de titanes vivos a la vez
	SpawnRadiusMin = 150,
	SpawnRadiusMax = 270,
	SafeZoneRadius = 85,  -- los titanes NO entran a la plaza central (anti spawn-camping)
}

----------------------------------------------------------------
-- NIVELES — subes de nivel matando JEFES
----------------------------------------------------------------
Config.Levels = {
	MaxLevel = 100,
}

-- Jefes necesarios para pasar del nivel `level` al siguiente (curva exponencial suave)
function Config.Levels.bossesForLevel(level: number): number
	return math.floor(2 + level ^ 1.35)
end

----------------------------------------------------------------
-- RAREZAS de compañeros (rueda gacha) — pesos = probabilidad relativa
----------------------------------------------------------------
Config.Rarities = {
	{ id = "Comun",      nombre = "Común",      peso = 54.0, color = Color3.fromRGB(170, 170, 170) },
	{ id = "Raro",       nombre = "Raro",       peso = 26.0, color = Color3.fromRGB(80, 160, 255) },
	{ id = "Epico",      nombre = "Épico",      peso = 12.0, color = Color3.fromRGB(170, 80, 255) },
	{ id = "Legendario", nombre = "Legendario", peso = 5.5,  color = Color3.fromRGB(255, 180, 40) },
	{ id = "Mitico",     nombre = "Mítico",     peso = 2.0,  color = Color3.fromRGB(255, 60, 60) },
	{ id = "Secreto",    nombre = "Secreto",    peso = 0.5,  color = Color3.fromRGB(20, 20, 20) },
}

Config.Wheel = {
	CostoTirada = 250,        -- monedas por giro
	CostoTirada10 = 2250,     -- pack x10 con descuento
	PityLegendario = 50,      -- garantizado Legendario+ cada N tiradas sin sacar uno
}

----------------------------------------------------------------
-- COMPAÑEROS — pelean contigo; salen de la rueda
----------------------------------------------------------------
Config.Companions = {
	MaxEquipados = 3,
	AttackRange = 80,         -- studs alrededor del jugador donde buscan titanes
	AttackTick = 1,           -- segundos entre golpes
	Pool = {
		Comun = {
			{ id = "Recluta", nombre = "Recluta", dps = 5 },
			{ id = "Cadete", nombre = "Cadete", dps = 7 },
		},
		Raro = {
			{ id = "Veterano", nombre = "Soldado Veterano", dps = 16 },
			{ id = "Arquera", nombre = "Arquera", dps = 20 },
		},
		Epico = {
			{ id = "Capitana", nombre = "Capitana", dps = 45 },
			{ id = "Berserker", nombre = "Berserker", dps = 55 },
		},
		Legendario = {
			{ id = "Comandante", nombre = "Comandante", dps = 130 },
			{ id = "Valquiria", nombre = "Valquiria", dps = 150 },
		},
		Mitico = {
			{ id = "Alado", nombre = "Guerrero Alado", dps = 350 },
		},
		Secreto = {
			{ id = "Devorador", nombre = "EL DEVORADOR", dps = 900 },
		},
	},
}

-- helper: entrada de rareza por id
function Config.getRarity(id: string): any?
	for _, r in Config.Rarities do
		if r.id == id then
			return r
		end
	end
	return nil
end

----------------------------------------------------------------
-- EVENTOS ESPECIALES (fase 5) — aparecen titanes raros por tiempo limitado
----------------------------------------------------------------
Config.Events = {
	{ id = "InvasionAnormal", nombre = "Invasión Anormal", intervaloMin = 900,  duracion = 180, multiplicadorLoot = 2 },
	{ id = "TitanColosal",    nombre = "Titán Colosal",    intervaloMin = 3600, duracion = 300, multiplicadorLoot = 5 },
	{ id = "LunaDeSangre",    nombre = "Luna de Sangre",   intervaloMin = 7200, duracion = 600, multiplicadorLoot = 10 },
}

----------------------------------------------------------------
-- REBIRTH — reiniciar progreso a cambio de multiplicador permanente
----------------------------------------------------------------
Config.Rebirth = {
	NivelMinimo = 10,            -- nivel requerido para el primer rebirth
	IncrementoPorRebirth = 5,    -- cada rebirth sube el requisito +5 niveles
	MultiplicadorPorRebirth = 0.25, -- +25% monedas y esencia por rebirth
}

----------------------------------------------------------------
-- ALDEA (fase 3/5) — base del jugador que hay que defender
----------------------------------------------------------------
Config.Village = {
	MaxMuroNivel = 10,
	MuroVidaBase = 1500,         -- vida del muro nivel 1 (calibrado en playtest: 500 caía en segundos)
	MuroVidaGrowth = 1.6,        -- vida x1.6 por nivel de muro
	MuroCostoBase = 500,         -- costo de mejorar muro nivel 1→2
	MuroCostoGrowth = 2,         -- costo x2 por nivel
	RepairCostPerHP = 0.4,       -- monedas por punto de vida reparado
	CuartelReduccion = 0.08,     -- -8% daño al muro por nivel de Cuartel (tope 50%)
	CostoGrowth = 2,             -- costo edificio = costoBase * 2^nivel
	MaxNivelEdificio = 15,
	-- baseRate: Monedas = por segundo · Esencia = por MINUTO
	Edificios = {
		{ id = "Granja",   nombre = "Granja",    produce = "Monedas",  baseRate = 2,  costoBase = 100 },
		{ id = "Mina",     nombre = "Mina",      produce = "Monedas",  baseRate = 6,  costoBase = 450 },
		{ id = "Altar",    nombre = "Altar",     produce = "Esencia",  baseRate = 1,  costoBase = 2000 },
		{ id = "Cuartel",  nombre = "Cuartel",   produce = "Defensa",  baseRate = 0,  costoBase = 800 },
	},
}

----------------------------------------------------------------
-- MONEDAS
----------------------------------------------------------------
Config.Currencies = {
	Monedas = { nombre = "Monedas", icono = "" },
	Esencia = { nombre = "Esencia de Titán", icono = "" }, -- moneda rara (jefes/eventos)
}

----------------------------------------------------------------
-- ANIMACIONES — IDs se llenan en fase 4 cuando se suban a Roblox
-- (deja "rbxassetid://0" = sin animación todavía, el juego no falla)
----------------------------------------------------------------
Config.Animations = {
	GrappleFire = "rbxassetid://0",   -- disparar gancho
	GrappleSwing = "rbxassetid://0",  -- colgado / balanceo
	GasBoost = "rbxassetid://0",      -- impulso de gas
	SlashLeft = "rbxassetid://0",     -- ataque espada izq (fase 2)
	SlashRight = "rbxassetid://0",    -- ataque espada der (fase 2)
}

return Config
