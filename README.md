# Titan Tycoon (nombre provisional)

**Tycoon de defensa contra titanes para Roblox, con el gancho de maniobras como movimiento central.**

Defiendes tu aldea de oleadas de titanes, subes de nivel matando jefes, sacas
compañeros por rareza en una rueda, enfrentas eventos especiales y haces rebirth
para volver más fuerte. Escrito en Luau y sincronizado con Roblox Studio vía Rojo.

![Roblox](https://img.shields.io/badge/Roblox-Studio-000000?style=for-the-badge&logo=roblox&logoColor=white)
![Luau](https://img.shields.io/badge/Luau-typed-00A2FF?style=for-the-badge&logo=lua&logoColor=white)
![Rojo](https://img.shields.io/badge/Rojo-7.4.4-E13835?style=for-the-badge)
![Aftman](https://img.shields.io/badge/Aftman-toolchain-555555?style=for-the-badge)
![Blender](https://img.shields.io/badge/Blender-export-F5792A?style=for-the-badge&logo=blender&logoColor=white)

> Juego en desarrollo, inspirado en el estilo de *Attack on Titan*. No oficial.

---

## Mecánicas

- **Gancho doble con física de resorte** (izquierdo y derecho), recogida de cable y gas.
- **Titanes con IA**: Normal, Anormal y Jefe; persiguen a los jugadores o atacan la aldea.
- **Oleadas progresivas** con un **jefe cada 5 oleadas**.
- **Combate**: click = corte; la **nuca hace x8** (la parte roja detrás del cuello).
- **Recompensas** en monedas y esencia; el nivel sube matando jefes.
- **Aldea por jugador** (6 parcelas) con edificios que producen monedas/esencia y
  un muro con vida: si los titanes lo rompen, la producción se detiene.
- **Rueda gacha**: 6 rarezas, pity a las 50 tiradas, inventario de compañeros.
- **Compañeros equipables** (máx. 3) que orbitan al jugador y atacan titanes.
- **Eventos especiales**: Invasión Anormal (x2), Titán Colosal (x5) y Luna de
  Sangre (x10, cielo rojo).
- **Rebirth**: reinicia nivel, monedas y aldea a cambio de +25 % de recompensas
  permanentes por cada rebirth.
- **Leaderboard global** entre servidores, con tablero físico en la plaza.
- **Datos persistentes** con DataStore.
- **Mapa greybox generado por código**: muralla, 12 torres y zona de aldeas.

## Controles

| Tecla | Acción |
|---|---|
| `Q` | disparar / soltar gancho izquierdo (te jala solo) |
| `E` | disparar / soltar gancho derecho |
| `Shift` | **gas**: acelera hacia la cámara y recoge cable más rápido |
| `Espacio` | soltar ambos ganchos (sales volando con el impulso) |
| `W A S D` | control aéreo mientras cuelgas |
| **Click izq.** | corte de espada (apunta a la nuca: x8) |
| `B` | panel de aldea |
| `R` | rueda de compañeros |
| `H` | ayuda de controles |

El flujo: gancho a algo alto (`Q`), `Shift` para llegar volando, `Espacio` para
soltarte con el impulso, gancho al titán y corte a la nuca.

## Stack

- **Luau** con tipos (`globalTypes.d.luau`, `luau-lsp`).
- **Rojo 7.4.4** para sincronizar el código con Studio (`default.project.json`).
- **Aftman** para fijar versiones de herramientas (`aftman.toml`).
- **Blender**: script de exportación a Roblox (`blender/export_roblox.py`).
- Texturas PBR (adoquín, madera, pasto, piedra) generadas con herramientas de IA
  y aplicadas por `TextureService`.

## Estructura

```
titan-tycoon/
├── aftman.toml             rojo + luau-lsp
├── default.project.json    mapeo Rojo -> DataModel
├── globalTypes.d.luau
├── blender/export_roblox.py
├── assets/textures/        PNG y sets PBR (color, normal, roughness, ao...)
└── src/
    ├── shared/
    │   ├── Config.luau     todo el diseño del juego (gancho, titanes, rueda, aldea, rebirth...)
    │   ├── AssetIds.luau   IDs de texturas subidas a Roblox
    │   └── Remotes.luau
    ├── server/
    │   ├── init.server.luau
    │   └── Services/       Combat, Companion, Data, Event, Leaderboard, Map,
    │                       Rebirth, Texture, Titan, Village, Weapon
    └── client/
        ├── init.client.luau
        └── Controllers/    Animation, Combat, Grapple, UI, Wheel
```

## Cómo correrlo

1. Instala [Aftman](https://github.com/LPGhatguy/aftman) (`winget install LPGhatguy.Aftman`).
2. En la carpeta del proyecto:

   ```bash
   aftman install   # instala Rojo y luau-lsp
   rojo serve       # sincronización en vivo con Studio
   ```

3. En Roblox Studio instala el plugin de Rojo (Creator Store), abre un Baseplate
   vacío y dale **Connect**.
4. Play (`F5`).

Para generar un archivo de lugar en vez de sincronizar en vivo:

```bash
rojo build -o build.rbxlx
```

## Texturas en Roblox

Las texturas de `assets/textures/` hay que subirlas a Roblox una vez:

1. Studio → **View** → **Asset Manager** → **Bulk Import** con los PNG.
2. Tras la moderación, click derecho → **Copy Asset ID**.
3. Pega los IDs en `src/shared/AssetIds.luau`; el mapa, las aldeas y los titanes
   quedan texturizados automáticamente.

## Ajustar el "feel" del gancho

Todo está en `src/shared/Config.luau` → `Config.Grapple`: `Stiffness` (fuerza
del tirón), `Damping` (rebote), `ReelSpeed`, `GasForce`. Con `rojo serve`
activo los cambios se aplican en vivo.

## Pendiente

- Subir texturas y pegar sus IDs en `AssetIds.luau`.
- Animaciones reales (IDs en `Config.Animations`).
- Modelo 3D del titán jefe (pipeline Blender → Studio).

## Autor

**David Burgos**, desarrollador full-stack + IA, Medellín.

- Portafolio: https://davidburgos.dev
- GitHub: https://github.com/burgosdavid057-art
- LinkedIn: https://www.linkedin.com/in/david-burgos-ab673433a/
