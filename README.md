# Titan Tycoon (nombre provisional)

Tycoon de defensa contra titanes con gancho de maniobras como movimiento central.
Subes de nivel matando jefes, sacas compañeros por rareza en una rueda, hay
eventos especiales y una aldea que defender.

## Estado — Fase 3 (tycoon + UI)

- ✅ Proyecto Rojo + estructura cliente/servidor/compartido
- ✅ Mapa greybox generado por código (muralla, 12 torres, zona de aldea)
- ✅ Gancho doble con física de resorte (Q/E), recogida de cable y gas
- ✅ Datos de jugador con DataStore (perfil ya preparado para fases futuras)
- ✅ Config central con rarezas, rueda, eventos y aldea ya definidos
- ✅ Titanes con IA (Normal / Anormal / Jefe) que persiguen jugadores o la aldea
- ✅ Oleadas progresivas + Jefe cada 5 oleadas
- ✅ Combate: click = corte, la **nuca hace x8** (parte roja atrás del cuello)
- ✅ Recompensas: monedas + esencia; nivel sube matando jefes
- ✅ Aldeas por jugador (6 parcelas): edificios que producen monedas/esencia
- ✅ Muro de aldea con vida: los titanes lo atacan; roto = producción parada
- ✅ HUD (monedas, esencia, nivel, oleadas) + panel de aldea (tecla **B**)
- ✅ Rueda gacha (tecla **R**): 6 rarezas, pity a 50, inventario de compañeros
- ✅ Compañeros equipables (máx 3) que orbitan al jugador y atacan titanes
- ✅ Texturas IA generadas (assets/textures/) + sistema para aplicarlas
- ✅ Pipeline Blender→Roblox (blender/export_roblox.py)
- ✅ Eventos especiales: Invasión Anormal (x2) · Titán Colosal (x5) · **Luna de Sangre** (x10, cielo rojo)
- ✅ Rebirth: reinicia nivel/monedas/aldea a cambio de +25% recompensas permanente por rebirth
- ✅ Leaderboard global (entre servidores) con tablero físico en la plaza
- ⬜ Subir texturas a Roblox y pegar IDs en src/shared/AssetIds.luau ← **TU TURNO**
- ⬜ Animaciones reales (subir y pegar IDs en Config.Animations)
- ⬜ Titán jefe 3D (Higgsfield generate_3d → Blender → Studio)

## Subir las texturas (5 minutos, lo haces tú)

1. Abre Studio → pestaña **View** → **Asset Manager**
2. Botón **Bulk Import** → selecciona los 4 PNG de `assets/textures/`
3. Espera la moderación (1-2 min) → click derecho en cada una → **Copy Asset ID**
4. Pega los 4 números en `src/shared/AssetIds.luau`
5. Con eso el mapa, las aldeas y los titanes quedan texturizados automáticamente

## Cómo correrlo

1. Instalar [Aftman](https://github.com/LPGhatguy/aftman): `winget install LPGhatguy.Aftman`
2. En esta carpeta: `aftman install` (instala Rojo)
3. `rojo serve`
4. En Roblox Studio: instalar el plugin de Rojo (Creator Store), abrir un
   Baseplate vacío y darle **Connect** en el plugin
5. Play (F5)

## Controles

| Tecla | Acción |
|---|---|
| **Q** | Disparar/soltar gancho izquierdo (toggle — **te jala solo**) |
| **E** | Disparar/soltar gancho derecho |
| **Shift** | **GAS**: acelera hacia la cámara y recoge el cable x1.7 |
| **Espacio** | Soltar ambos ganchos (sales volando con el impulso) |
| **WASD** | Control aéreo mientras cuelgas |
| **Click izq.** | Corte de espada (apunta a la **nuca** para daño x8) |
| **B** | Panel de aldea · **R** Rueda · **H** ayuda de controles |

El flujo del anime: gancho a algo alto (Q), Shift para llegar volando,
Espacio para soltarte con el impulso, gancho al titán, corte a la nuca.

## Estructura

```
src/
  shared/    Config (todo el diseño del juego) + Remotes
  server/    init + Services (Map, Data)
  client/    init + Controllers (Grapple, Animation)
```

## Ajustar el "feel" del gancho

Todo está en `src/shared/Config.luau` → `Config.Grapple`:
Stiffness (fuerza del tirón), Damping (rebote), ReelSpeed, GasForce.
Cambia valores con `rojo serve` activo y se actualizan en vivo.
