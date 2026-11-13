# Cemaat image generator: Routeway /v1/images/generations, saves PNG files.
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File gen-image.ps1 -Prompt "..." -Out "C:\proje\assets\hero.png" [-Model flux-1-schnell] [-Size 1024x1024] [-N 1]
# With -N > 1, files are saved as name-1.png, name-2.png, ...
param(
  [Parameter(Mandatory = $true)][string]$Prompt,
  [Parameter(Mandatory = $true)][string]$Out,
  [string]$Model = "flux-1-schnell",
  [string]$Size = "1024x1024",
  [int]$N = 1,
  [string]$NegativePrompt = ""
)

$ErrorActionPreference = "Stop"
$key = [Environment]::GetEnvironmentVariable("ROUTEWAY_API_KEY", "Process")
if (-not $key) { $key = [Environment]::GetEnvironmentVariable("ROUTEWAY_API_KEY", "User") }
if (-not $key) {
  [Console]::Error.WriteLine("ROUTEWAY_API_KEY is not set. Set it as a user environment variable and restart the Claude app.")
  exit 2
}

$body = @{ model = $Model; prompt = $Prompt; size = $Size; n = $N; response_format = "b64_json" }
if ($NegativePrompt) { $body.negative_prompt = $NegativePrompt }

try {
  $r = Invoke-RestMethod -Uri "https://api.routeway.ai/v1/images/generations" -Method Post `
    -ContentType "application/json" -Headers @{ Authorization = "Bearer $key" } `
    -Body ($body | ConvertTo-Json -Depth 5) -TimeoutSec 300
} catch {
  [Console]::Error.WriteLine("Image request failed: " + $_.Exception.Message + " " + $_.ErrorDetails.Message)
  exit 1
}

$dir = Split-Path -Parent $Out
if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$base = [IO.Path]::Combine($dir, [IO.Path]::GetFileNameWithoutExtension($Out))
$ext = [IO.Path]::GetExtension($Out); if (-not $ext) { $ext = ".png" }

$i = 0
foreach ($img in $r.data) {
  $i++
  $path = if ($r.data.Count -gt 1) { "$base-$i$ext" } else { "$base$ext" }
  if ($img.b64_json) {
    [IO.File]::WriteAllBytes($path, [Convert]::FromBase64String($img.b64_json))
  } elseif ($img.url) {
    Invoke-WebRequest -Uri $img.url -OutFile $path -UseBasicParsing
  } else {
    [Console]::Error.WriteLine("Image $i returned no data.")
    continue
  }
  "saved: $path"
}
