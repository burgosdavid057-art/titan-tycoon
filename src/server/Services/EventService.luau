--!strict
-- EventService.luau — Eventos especiales por tiempo limitado (Config.Events):
--   · Invasión Anormal: oleadas solo de anormales + botín x2
--   · Titán Colosal: aparece un Jefe extra + botín x5
--   · Luna de Sangre: cielo rojo, solo anormales, botín x10
-- Solo un evento activo a la vez. Al terminar, todo vuelve a la normalidad.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TitanService = require(script.Parent.TitanService)

local EventService = {}

type ActiveEvent = {
	def: any,
	endsAt: number,
}

local active: ActiveEvent? = nil
local nextFire: { [string]: number } = {}

-- lighting original para restaurar tras Luna de Sangre
local savedLighting: { [string]: any }? = nil

----------------------------------------------------------------
-- Efectos por evento
----------------------------------------------------------------

local function applyBloodMoon()
	savedLighting = {
		ClockTime = Lighting.ClockTime,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		FogColor = Lighting.FogColor,
		FogEnd = Lighting.FogEnd,
	}
	Lighting.ClockTime = 0
	Lighting.Ambient = Color3.fromRGB(90, 25, 25)
	Lighting.OutdoorAmbient = Color3.fromRGB(130, 45, 45)
	Lighting.FogColor = Color3.fromRGB(120, 30, 30)
	Lighting.FogEnd = 700
end

local function restoreLighting()
	if savedLighting then
		for prop, value in savedLighting do
			(Lighting :: any)[prop] = value
		end
		savedLighting = nil
	end
end

local function startEvent(def: any)
	active = { def = def, endsAt = os.clock() + def.duracion }
	TitanService.SetLootMultiplier(def.multiplicadorLoot)

	if def.id == "InvasionAnormal" then
		TitanService.SetForceAnormal(true)
		for _ = 1, 4 do
			TitanService.Spawn("Anormal")
		end
	elseif def.id == "TitanColosal" then
		TitanService.Spawn("Jefe")
	elseif def.id == "LunaDeSangre" then
		TitanService.SetForceAnormal(true)
		applyBloodMoon()
		for _ = 1, 6 do
			TitanService.Spawn("Anormal")
		end
	end

	Remotes.EventStarted:FireAllClients({
		id = def.id,
		nombre = def.nombre,
		duracion = def.duracion,
		multiplicador = def.multiplicadorLoot,
	})
	print(("[EventService] Evento iniciado: %s (x%d loot, %ds)"):format(def.nombre, def.multiplicadorLoot, def.duracion))
end

local function endEvent()
	active = nil
	TitanService.SetLootMultiplier(1)
	TitanService.SetForceAnormal(false)
	restoreLighting()
	print("[EventService] Evento terminado")
end

----------------------------------------------------------------

function EventService.Init()
	local now = os.clock()
	for _, def in Config.Events do
		-- el primer disparo llega antes (25% del intervalo) para que se vean pronto
		nextFire[def.id] = now + def.intervaloMin * 0.25
	end

	task.spawn(function()
		while true do
			task.wait(5)
			local clock = os.clock()

			if active and clock >= active.endsAt then
				endEvent()
			end

			if not active then
				for _, def in Config.Events do
					if clock >= nextFire[def.id] then
						nextFire[def.id] = clock + def.intervaloMin
						startEvent(def)
						break -- solo uno a la vez
					end
				end
			end
		end
	end)

	print("[EventService] listo — primer evento en ~" .. math.floor(Config.Events[1].intervaloMin * 0.25) .. "s")
end

return EventService
