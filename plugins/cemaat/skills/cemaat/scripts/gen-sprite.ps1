# Cemaat 2D sprite generator: Routeway image + rembg background removal -> transparent PNG.
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File gen-sprite.ps1 -Prompt "knight character, side view" -Out "C:\proje\assets\knight.png" [-Style pixel|flat|painted|anime] [-Model z-image-turbo] [-Size 1024x1024] [-N 1]
# Keeps the raw image next to the output as <name>.raw.png.
param(
  [Parameter(Mandatory = $true)][string]$Prompt,
  [Parameter(Mandatory = $true)][string]$Out,
  [ValidateSet("pixel", "flat", "painted", "anime", "none")][string]$Style = "flat",
  [string]$Model = "z-image-turbo",
  [string]$Size = "1024x1024",
  [int]$N = 1
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

$styleText = @{
  pixel   = "pixel art game sprite, 32-bit style, crisp pixels, limited palette"
  flat    = "2D game sprite, flat vector style, clean outlines"
  painted = "2D game asset, hand-painted style"
  anime   = "2D anime style game character art, cel shading"
  none    = ""
}[$Style]
$fullPrompt = "$Prompt, $styleText, single subject, full body, centered, isolated on plain solid white background, no shadow, no text"

$dir = Split-Path -Parent $Out
if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$name = [IO.Path]::GetFileNameWithoutExtension($Out)
$raw = Join-Path $dir "$name.raw.png"

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "gen-image.ps1") -Model $Model -Size $Size -N $N -Prompt $fullPrompt -Out $raw
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$raws = if ($N -gt 1) { 1..$N | ForEach-Object { Join-Path $dir "$name.raw-$_.png" } } else { @($raw) }
$i = 0
foreach ($r in $raws) {
  $i++
  if (-not (Test-Path $r)) { continue }
  $o = if ($N -gt 1) { Join-Path $dir "$name-$i.png" } else { $Out }
  & python -c "import sys; from rembg import remove; from PIL import Image; remove(Image.open(sys.argv[1])).save(sys.argv[2])" $r $o
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $o)) {
    [Console]::Error.WriteLine("Background removal failed for $r")
    exit 1
  }
  "sprite: $o"
}
