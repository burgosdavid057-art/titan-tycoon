--!strict
-- MapService.luau — Mapa gris de pruebas (greybox) generado por código.
-- Diseñado como PARQUE DE GANCHO: muralla circular, torres de alturas variadas
-- y una zona de aldea. En fase 4 se reemplazan materiales por texturas reales.

local Workspace = game:GetService("Workspace")

local MapService = {}

local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

function MapService.Init()
	local map = Instance.new("Folder")
	map.Name = "Map"

	----------------------------------------------------------------
	-- Suelo
	----------------------------------------------------------------
	makePart({
		Name = "Suelo",
		Size = Vector3.new(1024, 4, 1024),
		Position = Vector3.new(0, -2, 0),
		Color = Color3.fromRGB(96, 130, 62),
		Material = Enum.Material.Grass,
		Parent = map,
	})

	-- Plaza central (spawn)
	makePart({
		Name = "Plaza",
		Size = Vector3.new(60, 1, 60),
		Position = Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(145, 140, 132),
		Material = Enum.Material.Cobblestone,
		Parent = map,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 1.5, 0)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Color = Color3.fromRGB(180, 180, 180)
	spawn.Parent = map

	----------------------------------------------------------------
	-- Muralla circular (16 segmentos) — el "muro" clásico para ganchear
	----------------------------------------------------------------
	local murallaFolder = Instance.new("Folder")
	murallaFolder.Name = "Muralla"
	murallaFolder.Parent = map

	local segments = 16
	local radius = 320
	local wallHeight = 70
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		local nextAngle = ((i + 0.5) / segments) * math.pi * 2
		local pos = Vector3.new(math.cos(angle) * radius, wallHeight / 2, math.sin(angle) * radius)
		local segLength = 2 * radius * math.sin(math.pi / segments) + 6
		local wall = makePart({
			Name = "MuroSeg" .. i,
			Size = Vector3.new(segLength, wallHeight, 14),
			CFrame = CFrame.new(pos, Vector3.new(0, wallHeight / 2, 0)),
			Color = Color3.fromRGB(140, 138, 130),
			Material = Enum.Material.Brick,
			Parent = murallaFolder,
		})
		-- almenas arriba para referencia visual
		if i % 2 == 0 then
			makePart({
				Name = "Almena" .. i,
				Size = Vector3.new(10, 8, 16),
				CFrame = wall.CFrame * CFrame.new(0, wallHeight / 2 + 4, 0),
				Color = Color3.fromRGB(120, 118, 112),
				Material = Enum.Material.Slate,
				Parent = murallaFolder,
			})
		end
		local _ = nextAngle
	end

	----------------------------------------------------------------
	-- Torres — parque de juegos para el gancho (alturas variadas)
	----------------------------------------------------------------
	local torresFolder = Instance.new("Folder")
	torresFolder.Name = "Torres"
	torresFolder.Parent = map

	-- posiciones deterministas (x, z, altura, ancho)
	local torres = {
		{ 60, 40, 55, 16 },
		{ -80, 70, 80, 18 },
		{ 120, -60, 45, 14 },
		{ -50, -110, 100, 20 },
		{ 180, 90, 65, 16 },
		{ -170, -40, 90, 18 },
		{ 40, 170, 120, 22 },
		{ -160, 115, 60, 15 },
		{ 220, -150, 75, 17 },
		{ -240, 80, 50, 14 },
		{ 60, -260, 110, 20 },
		{ -60, 250, 70, 16 },
	}
	for i, t in torres do
		local x, z, h, w = t[1], t[2], t[3], t[4]
		makePart({
			Name = "Torre" .. i,
			Size = Vector3.new(w, h, w),
			Position = Vector3.new(x, h / 2, z),
			Color = Color3.fromRGB(125 + (i * 7) % 30, 125, 130),
			Material = Enum.Material.Cobblestone,
			Parent = torresFolder,
		})
		-- plataforma superior
		makePart({
			Name = "TorreTop" .. i,
			Size = Vector3.new(w + 6, 2, w + 6),
			Position = Vector3.new(x, h + 1, z),
			Color = Color3.fromRGB(160, 160, 165),
			Material = Enum.Material.Slate,
			Parent = torresFolder,
		})
	end

	-- (las aldeas por jugador las construye VillageService en sus parcelas)

	map.Parent = Workspace
	print("[MapService] Mapa greybox generado")
end

return MapService
