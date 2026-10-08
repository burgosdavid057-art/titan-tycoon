--!strict
-- AssetIds.luau — IDs de assets subidos a Roblox.
--
-- Las texturas son sets PBR CC0 (Poly Haven / ambientCG), validados con QA
-- visual. Lo que se sube a Roblox es el `color.png` de cada set.
--
-- CÓMO LLENARLO (opción A, manual — 5 min):
--   Studio → View → Asset Manager → Bulk Import → los 5 PNG de abajo
--   → click derecho → Copy Asset ID → pegar aquí
--
-- CÓMO LLENARLO (opción B, automática):
--   1. Crea una API key en create.roblox.com/dashboard/credentials
--      (permiso: Assets → Read+Write)
--   2. Ponla en la variable de entorno ROBLOX_API_KEY
--   3. Dile a Claude "sube las texturas" — el resto es automático

return {
	Texturas = {
		Piedra = 0,     -- assets/textures/piedra_pbr/color.png   (muralla, muros de aldea)
		Madera = 0,     -- assets/textures/madera_pbr/color.png   (edificios de aldea)
		Pasto = 0,      -- assets/textures/pasto_pbr/color.png    (suelo del mapa y parcelas)
		Adoquin = 0,    -- assets/textures/adoquin_pbr/color.png  (plaza central)
		PielTitan = 0,  -- assets/textures/piel_titan.png         (IA — cuerpo de titanes)
	},
}
