# Cemaat optional ML tools (Windows): MusicGen (music) and TripoSR (image -> 3D). ~5 GB download.
# An NVIDIA GPU is strongly recommended; on CPU both work but are very slow.
# Run in PowerShell:  powershell -ExecutionPolicy Bypass -File install-ml.ps1
$ErrorActionPreference = "Continue"
$base = Join-Path $HOME ".claude\cemaat"
$venv = Join-Path $base "venv-ml"
$py = Join-Path $venv "Scripts\python.exe"
New-Item -ItemType Directory -Force -Path $base | Out-Null

Write-Host "== Python venv ==" -ForegroundColor Cyan
if (-not (Test-Path $py)) { python -m venv $venv }
& $py -m pip install --upgrade pip

Write-Host "== PyTorch (CUDA 12.6 build; falls back to CPU without NVIDIA) ==" -ForegroundColor Cyan
& $py -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126

Write-Host "== MusicGen + TripoSR dependencies ==" -ForegroundColor Cyan
# transformers is pinned: TripoSR's weights do not load with transformers 5.x (renamed ViT layers).
& $py -m pip install "transformers==4.46.3" scipy omegaconf einops trimesh rembg onnxruntime huggingface-hub "imageio[ffmpeg]" PyMCubes xatlas moderngl

Write-Host "== TripoSR code ==" -ForegroundColor Cyan
$tsr = Join-Path $base "TripoSR"
if (-not (Test-Path (Join-Path $tsr "run.py"))) {
  git clone --depth 1 https://github.com/VAST-AI-Research/TripoSR.git $tsr
}
# torchmcubes needs a CUDA/MSVC build on Windows; replace it with a PyMCubes shim.
@'
# Drop-in replacement for torchmcubes (which needs a CUDA/MSVC build on Windows), using PyMCubes on CPU.
import mcubes
import numpy as np
import torch


def marching_cubes(vol: torch.Tensor, thresh: float):
    v, f = mcubes.marching_cubes(vol.detach().float().cpu().numpy(), float(thresh))
    v = v[:, [2, 1, 0]].astype(np.float32)
    f = f.astype(np.int64)
    dev = vol.device
    return torch.from_numpy(v).to(dev), torch.from_numpy(f).to(dev)
'@ | Set-Content -Path (Join-Path $tsr "torchmcubes.py") -Encoding utf8

& $py -c "import torch; print('torch', torch.__version__, 'cuda:', torch.cuda.is_available())"
Write-Host "== Done. Models download on first use (MusicGen ~2-6 GB, TripoSR ~1.7 GB). ==" -ForegroundColor Green
