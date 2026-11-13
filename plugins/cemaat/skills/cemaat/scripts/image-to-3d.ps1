# Cemaat image-to-3D: free local TripoSR (single image -> textured-by-vertex-color mesh), then GLB + Blender preview.
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File image-to-3d.ps1 -Image "C:\proje\assets\hero.png" -Out "C:\proje\assets\hero.glb" [-Resolution 256]
# Best input: one character/object, centered, plain or transparent background (gen-sprite.ps1 output works).
# Needs the ML setup: %USERPROFILE%\.claude\cemaat\venv-ml and %USERPROFILE%\.claude\cemaat\TripoSR (see install-ml.ps1).
param(
  [Parameter(Mandatory = $true)][string]$Image,
  [Parameter(Mandatory = $true)][string]$Out,
  [int]$Resolution = 256
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$py = Join-Path $HOME ".claude\cemaat\venv-ml\Scripts\python.exe"
$tsr = Join-Path $HOME ".claude\cemaat\TripoSR"
if (-not (Test-Path $py) -or -not (Test-Path "$tsr\run.py")) {
  [Console]::Error.WriteLine("ML setup missing. Run install-ml.ps1 from the cemaat-plugin repo.")
  exit 2
}
if (-not (Test-Path $Image)) { [Console]::Error.WriteLine("Image not found: $Image"); exit 1 }

$work = Join-Path $env:TEMP ("cemaat-tsr-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
$device = & $py -c "import torch; print('cuda:0' if torch.cuda.is_available() else 'cpu')"

Push-Location $tsr
& $py run.py $Image --output-dir $work --model-save-format glb --mc-resolution $Resolution --device $device 2>&1 |
  Where-Object { "$_" -notmatch 'it/s|%\|' } | ForEach-Object { "$_" }
Pop-Location

$mesh = Join-Path $work "0\mesh.glb"
if (-not (Test-Path $mesh)) { [Console]::Error.WriteLine("TripoSR failed: no mesh produced."); exit 1 }

# Re-import in Blender: normalize (stand on ground, centered), export final GLB, render preview.
$imp = Join-Path $work "import.py"
@"
import bpy
from mathutils import Vector
import math
bpy.ops.import_scene.gltf(filepath=r'$mesh')
objs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
# TripoSR writes Z-up data into a Y-up GLB; rotate -90 deg on X so the model stands upright (verified visually).
# (glTF import uses quaternion rotation mode, so rotate the world matrix of top-level objects.)
from mathutils import Matrix
rot = Matrix.Rotation(math.radians(-90), 4, 'X')
for o in bpy.context.scene.objects:
    if o.parent is None:
        o.matrix_world = rot @ o.matrix_world
bpy.context.view_layer.update()
pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
shift = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
for o in objs:
    o.location += shift
"@ | Set-Content -Path $imp -Encoding utf8

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "make-3d.ps1") -Script $imp -Out $Out
$code = $LASTEXITCODE
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
exit $code
