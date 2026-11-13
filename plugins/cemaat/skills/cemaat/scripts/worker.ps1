# Cemaat worker: runs a headless Claude Code process on a non-Claude model via an Anthropic-compatible gateway.
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File worker.ps1 -Model glm -Task "..." -Dir "C:\proje" [-Mode edit|read] [-Provider routeway|openrouter]
# -Model: alias from models.json (minimax, glm) or a full model ID of the provider.
# -Provider: overrides the alias's provider; for a raw model ID, defaults to defaultProvider in models.json.
# -Mode read: worker may only read files. -Mode edit: worker may also edit/create files. Bash is never allowed.
param(
  [Parameter(Mandatory = $true)][string]$Model,
  [Parameter(Mandatory = $true)][string]$Task,
  [string]$Dir = (Get-Location).Path,
  [ValidateSet("edit", "read")][string]$Mode = "edit",
  [int]$MaxTurns = 40,
  [int]$TimeoutMin = 20,
  [string]$Provider = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

# Resolve model alias and provider.
$config = Get-Content (Join-Path $root "models.json") -Raw | ConvertFrom-Json
$modelId = $Model
$providerName = $Provider
if ($config.models.PSObject.Properties.Name -contains $Model) {
  $modelId = $config.models.$Model.id
  if (-not $providerName) { $providerName = $config.models.$Model.provider }
}
if (-not $providerName) { $providerName = $config.defaultProvider }
if (-not ($config.providers.PSObject.Properties.Name -contains $providerName)) {
  [Console]::Error.WriteLine("Unknown provider '$providerName'. Add it to models.json.")
  exit 3
}
$prov = $config.providers.$providerName
$keyEnv = $prov.keyEnv

# API key: process env first, then the user-level env var.
$key = [Environment]::GetEnvironmentVariable($keyEnv, "Process")
if (-not $key) { $key = [Environment]::GetEnvironmentVariable($keyEnv, "User") }
if (-not $key) {
  [Console]::Error.WriteLine("$keyEnv is not set. Set it as a user environment variable and restart the Claude app.")
  exit 2
}

# Drop the host session's Claude/Anthropic variables so the worker is a clean, separate process.
$hostVars = @(Get-ChildItem env: | Where-Object { $_.Name -match '^(CLAUDE|ANTHROPIC)' } | ForEach-Object { $_.Name })
foreach ($name in $hostVars) {
  [Environment]::SetEnvironmentVariable($name, $null, "Process")
}

$env:ANTHROPIC_BASE_URL = $prov.baseUrl
$env:ANTHROPIC_AUTH_TOKEN = $key
$env:ANTHROPIC_API_KEY = ""
# Every model slot points to the worker model, so the worker never falls back to a paid Claude model.
$env:ANTHROPIC_MODEL = $modelId
$env:ANTHROPIC_DEFAULT_OPUS_MODEL = $modelId
$env:ANTHROPIC_DEFAULT_SONNET_MODEL = $modelId
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $modelId
$env:CLAUDE_CODE_SUBAGENT_MODEL = $modelId
# Non-Claude models are unknown to Claude Code's catalog; cap context at 200k (also keeps cost down).
$env:CLAUDE_CODE_MAX_CONTEXT_TOKENS = "200000"

if ($Mode -eq "read") {
  $toolArgs = @("--allowedTools", "Read,Grep,Glob", "--disallowedTools", "Edit,Write,Bash,NotebookEdit")
} else {
  $toolArgs = @("--permission-mode", "acceptEdits", "--allowedTools", "Read,Grep,Glob,Edit,Write", "--disallowedTools", "Bash,NotebookEdit")
}

# Logs live outside the plugin folder so plugin updates never delete them.
$logDir = Join-Path $HOME ".claude\cemaat\logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$safeAlias = ($Model -replace '[^A-Za-z0-9_-]', '_')
$log = Join-Path $logDir ((Get-Date -Format "yyyyMMdd-HHmmss") + "-" + $safeAlias + ".log")

$prompt = @"
You are a worker agent. Do only the task below, inside the current folder. Do not touch files outside the scope the task names.
When done, report: files changed (paths), what you did, anything you could not do.

TASK:
$Task
"@

Push-Location $Dir
# claude writes warnings to stderr; do not let PowerShell treat them as fatal.
$ErrorActionPreference = "Continue"
try {
  "MODEL: $modelId`nMODE: $Mode`nDIR: $Dir`nTASK:`n$Task`n----- OUTPUT -----" | Out-File -FilePath $log -Encoding utf8
  # Run in a job so a hung gateway (e.g. repeated 502 retries) cannot block forever.
  $job = Start-Job -ScriptBlock {
    param($dir, $prompt, $modelId, $maxTurns, $toolArgs)
    Set-Location $dir
    # claude prints UTF-8; without this, Windows PowerShell decodes it with the OEM code page (garbled dashes/Turkish letters).
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    & claude -p $prompt --model $modelId --max-turns $maxTurns --output-format text @toolArgs 2>&1 | ForEach-Object { "$_" }
    "__EXIT__$LASTEXITCODE"
  } -ArgumentList $Dir, $prompt, $modelId, $MaxTurns, $toolArgs
  $finished = Wait-Job $job -Timeout ($TimeoutMin * 60)
  $lines = @(Receive-Job $job)
  $code = 1
  foreach ($line in $lines) {
    if ($line -like "__EXIT__*") { $code = [int]($line.Substring(8)); continue }
    Add-Content -Path $log -Value $line -Encoding utf8
    $line
  }
  if (-not $finished) {
    Stop-Job $job
    $msg = "[worker timed out after $TimeoutMin min; likely gateway error for model $modelId]"
    Add-Content -Path $log -Value $msg -Encoding utf8
    $msg
    $code = 124
  }
  Remove-Job $job -Force
} finally {
  Pop-Location
}
"`n[worker exit code: $code, log: $log]"
exit $code
