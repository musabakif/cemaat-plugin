# Cemaat: installs the free tools the plugin needs (Windows).
# Run in PowerShell:  powershell -ExecutionPolicy Bypass -File install-tools.ps1
$ErrorActionPreference = "Continue"

function Has($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

Write-Host "== Cemaat tool setup ==" -ForegroundColor Cyan

if (-not (Has winget)) { Write-Host "winget not found. Install 'App Installer' from Microsoft Store, then run again." -ForegroundColor Red; exit 1 }

if (-not (Has node)) { winget install --id OpenJS.NodeJS.LTS -e --source winget --accept-package-agreements --accept-source-agreements }
if (-not (Has python)) { winget install --id Python.Python.3.12 -e --source winget --accept-package-agreements --accept-source-agreements }
if (-not (Has ffmpeg)) { winget install --id Gyan.FFmpeg -e --source winget --accept-package-agreements --accept-source-agreements }
if (-not (Test-Path "C:\Program Files\Blender Foundation")) { winget install --id BlenderFoundation.Blender -e --source winget --accept-package-agreements --accept-source-agreements }

# Reload PATH so freshly installed tools are visible.
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

if (-not (Has claude)) { npm install -g @anthropic-ai/claude-code }
python -m pip install --user edge-tts "rembg[cpu]"

Write-Host ""
Write-Host "== Done ==" -ForegroundColor Green
if (-not [Environment]::GetEnvironmentVariable("ROUTEWAY_API_KEY", "User")) {
  Write-Host "Last step: get an API key at https://routeway.ai and run (with YOUR key):" -ForegroundColor Yellow
  Write-Host '  [Environment]::SetEnvironmentVariable("ROUTEWAY_API_KEY", "your-key", "User")'
  Write-Host "Then fully restart the Claude app."
}
