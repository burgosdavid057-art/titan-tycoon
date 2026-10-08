# export_roblox.py — Convierte un modelo (GLB/OBJ/FBX) a FBX listo para Roblox:
#   · Normaliza la escala a studs (1 stud ≈ 0.28 m; Roblox importa FBX en cm)
#   · Decima la malla si supera el límite de triángulos de Roblox (10k por MeshPart)
#   · Aplica transformaciones y centra el pivote en la base
#
# Uso:
#   blender --background --python blender/export_roblox.py -- entrada.glb salida.fbx [altura_en_studs]
#
# Ejemplo (titán jefe de 55 studs):
#   blender --background --python blender/export_roblox.py -- titan.glb titan_jefe.fbx 55

import bpy
import sys
import os

MAX_TRIS = 9500  # margen bajo el límite de 10k de Roblox

def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    if len(argv) < 2:
        print("Uso: blender --background --python export_roblox.py -- entrada salida.fbx [altura_studs]")
        sys.exit(1)

    src, dst = argv[0], argv[1]
    target_studs = float(argv[2]) if len(argv) > 2 else 10.0

    # limpiar escena
    bpy.ops.wm.read_factory_settings(use_empty=True)

    ext = os.path.splitext(src)[1].lower()
    if ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=src)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=src)
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=src)
    else:
        print(f"Formato no soportado: {ext}")
        sys.exit(1)

    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        print("No hay mallas en el archivo")
        sys.exit(1)

    # unir todo en un solo objeto
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active

    # aplicar transformaciones
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # decimar si excede el límite de triángulos
    tri_count = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"Triángulos: {tri_count}")
    if tri_count > MAX_TRIS:
        ratio = MAX_TRIS / tri_count
        mod = obj.modifiers.new("Decimate", "DECIMATE")
        mod.ratio = ratio
        bpy.ops.object.modifier_apply(modifier=mod.name)
        tri_count = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        print(f"Decimado a: {tri_count} tris (ratio {ratio:.2f})")

    # escalar a la altura deseada en studs (Roblox FBX: 1 stud = 28 cm → exportamos en m y usamos escala FBX)
    dims = obj.dimensions
    height_m = dims.z
    if height_m > 0:
        # 1 stud ≈ 0.28 m en la importación default de Roblox
        scale = (target_studs * 0.28) / height_m
        obj.scale = (scale, scale, scale)
        bpy.ops.object.transform_apply(scale=True)
        print(f"Escalado: altura {obj.dimensions.z:.2f} m ≈ {target_studs} studs")

    # pivote en la base (para que Position.Y = altura/2 funcione como en el código)
    bpy.ops.object.origin_set(type="ORIGIN_CENTER_OF_MASS", center="BOUNDS")

    bpy.ops.export_scene.fbx(
        filepath=dst,
        use_selection=False,
        apply_scale_options="FBX_SCALE_ALL",
        path_mode="COPY",
        embed_textures=True,
    )
    print(f"Exportado: {dst}")

if __name__ == "__main__":
    main()
