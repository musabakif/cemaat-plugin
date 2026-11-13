# Cemaat 3D builder: runs a Blender Python script headless, exports GLB and renders a preview PNG.
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File make-3d.ps1 -Script "C:\proje\3d\tree.py" -Out "C:\proje\assets\tree.glb"
# The script builds the scene only (meshes, materials). This wrapper clears the default scene first,
# then after the script: exports all mesh objects to GLB and renders <name>.preview.png with an auto-framed camera.
# Template for workers: blender-template.py next to this file.
param(
  [Parameter(Mandatory = $true)][string]$Script,
  [Parameter(Mandatory = $true)][string]$Out,
  [int]$Resolution = 768
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$blender = Get-ChildItem "C:\Program Files\Blender Foundation" -Recurse -Filter blender.exe -ErrorAction SilentlyContinue |
  Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
if (-not $blender) {
  [Console]::Error.WriteLine("Blender not found. Install: winget install --id BlenderFoundation.Blender -e")
  exit 2
}
if (-not (Test-Path $Script)) {
  [Console]::Error.WriteLine("Script not found: $Script")
  exit 1
}

$dir = Split-Path -Parent $Out
if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$preview = [IO.Path]::ChangeExtension($Out, ".preview.png")

$ErrorActionPreference = "Continue"
& $blender -b --factory-startup --python (Join-Path $root "blender-runner.py") -- $Script $Out $preview $Resolution 2>&1 |
  Where-Object { "$_" -match 'CEMAAT|Error|Traceback|line \d+' } | ForEach-Object { "$_" }

if (-not (Test-Path $Out)) {
  [Console]::Error.WriteLine("Export failed: $Out was not created. See errors above.")
  exit 1
}
"model: $Out"
if (Test-Path $preview) { "preview: $preview" }
