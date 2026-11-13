# Cemaat voice generator: free text-to-speech with edge-tts (Microsoft neural voices). Saves MP3 + SRT subtitles.
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File gen-voice.ps1 -Text "Merhaba" -Out "C:\proje\audio\intro.mp3" [-Voice tr-TR-AhmetNeural] [-Rate "+0%"] [-Pitch "+0Hz"]
#   -TextFile instead of -Text for long scripts.
# Turkish voices: tr-TR-AhmetNeural (male), tr-TR-EmelNeural (female). List all: python -m edge_tts --list-voices
param(
  [string]$Text = "",
  [string]$TextFile = "",
  [Parameter(Mandatory = $true)][string]$Out,
  [string]$Voice = "tr-TR-AhmetNeural",
  [string]$Rate = "+0%",
  [string]$Pitch = "+0Hz"
)

$ErrorActionPreference = "Continue"
if (-not $Text -and -not $TextFile) {
  [Console]::Error.WriteLine("Give -Text or -TextFile.")
  exit 1
}
$dir = Split-Path -Parent $Out
if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$srt = [IO.Path]::ChangeExtension($Out, ".srt")

$args = @("-m", "edge_tts", "--voice", $Voice, "--rate=$Rate", "--pitch=$Pitch", "--write-media", $Out, "--write-subtitles", $srt)
if ($TextFile) { $args += @("--file", $TextFile) } else { $args += @("--text", $Text) }

& python @args
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $Out)) {
  [Console]::Error.WriteLine("TTS failed.")
  exit 1
}
"saved: $Out"
"subtitles: $srt"
