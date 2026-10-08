--!strict
-- TextureService.luau — aplica las texturas de AssetIds a lo ya construido.
-- Si un ID está en 0 no hace nada (el juego se ve greybox, nunca falla).
-- Corre DESPUÉS de MapService; VillageService y TitanService la usan para
-- texturizar lo que construyen en runtime.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetIds = require(ReplicatedStorage.Shared.AssetIds)

local TextureService = {}

local SIDE_FACES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

-- Aplica una textura repetida a las caras dadas de un part
function TextureService.Apply(part: BasePart, assetId: number, faces: { Enum.NormalId }, studsPerTile: number)
	if assetId == 0 then
		return
	end
	for _, face in faces do
		local tex = Instance.new("Texture")
		tex.Texture = "rbxassetid://" .. assetId
		tex.Face = face
		tex.StudsPerTileU = studsPerTile
		tex.StudsPerTileV = studsPerTile
		tex.Parent = part
	end
end

function TextureService.ApplyStone(part: BasePart)
	TextureService.Apply(part, AssetIds.Texturas.Piedra, SIDE_FACES, 24)
end

function TextureService.ApplyWood(part: BasePart)
	TextureService.Apply(part, AssetIds.Texturas.Madera, SIDE_FACES, 12)
end

function TextureService.ApplyGrass(part: BasePart)
	TextureService.Apply(part, AssetIds.Texturas.Pasto, { Enum.NormalId.Top }, 20)
end

function TextureService.ApplyCobble(part: BasePart)
	TextureService.Apply(part, AssetIds.Texturas.Adoquin, { Enum.NormalId.Top }, 14)
end

function TextureService.ApplyTitanSkin(part: BasePart)
	TextureService.Apply(part, AssetIds.Texturas.PielTitan, SIDE_FACES, 10)
end

-- Texturiza el mapa greybox ya generado por MapService
function TextureService.Init()
	local map = Workspace:FindFirstChild("Map")
	if not map then
		return
	end

	local suelo = map:FindFirstChild("Suelo")
	if suelo then
		TextureService.ApplyGrass(suelo :: BasePart)
	end

	local plaza = map:FindFirstChild("Plaza")
	if plaza then
		TextureService.ApplyCobble(plaza :: BasePart)
	end

	local muralla = map:FindFirstChild("Muralla")
	if muralla then
		for _, part in muralla:GetChildren() do
			if part:IsA("BasePart") then
				TextureService.ApplyStone(part)
			end
		end
	end

	local torres = map:FindFirstChild("Torres")
	if torres then
		for _, part in torres:GetChildren() do
			if part:IsA("BasePart") then
				TextureService.ApplyStone(part)
			end
		end
	end

	if AssetIds.Texturas.Piedra ~= 0 or AssetIds.Texturas.Pasto ~= 0 then
		print("[TextureService] texturas aplicadas al mapa")
	else
		print("[TextureService] sin IDs de textura aún (modo greybox) — ver src/shared/AssetIds.luau")
	end
end

return TextureService
