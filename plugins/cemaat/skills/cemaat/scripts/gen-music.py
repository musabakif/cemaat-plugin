# Cemaat music generator: free local music with Meta MusicGen (transformers). GPU if available.
# Usage (run with the ML venv python):
#   "%USERPROFILE%\.claude\cemaat\venv-ml\Scripts\python.exe" gen-music.py "<prompt>" <out.wav> [--seconds 20] [--model small|medium] [--seed 1]
# Prompt in English works best, e.g. "calm ney flute and oud, meditative, no percussion".
# Max 30 s per call; for longer tracks generate several and join/loop them with ffmpeg (acrossfade).
import argparse, os, sys


def main():
    p = argparse.ArgumentParser()
    p.add_argument("prompt")
    p.add_argument("out")
    p.add_argument("--seconds", type=float, default=20)
    p.add_argument("--model", choices=["small", "medium"], default="small")
    p.add_argument("--seed", type=int, default=None)
    a = p.parse_args()

    import torch
    import numpy as np
    import scipy.io.wavfile as wav
    from transformers import AutoProcessor, MusicgenForConditionalGeneration

    device = "cuda" if torch.cuda.is_available() else "cpu"
    dtype = torch.float16 if device == "cuda" else torch.float32
    name = f"facebook/musicgen-{a.model}"
    print(f"model={name} device={device}", file=sys.stderr)

    if a.seed is not None:
        torch.manual_seed(a.seed)
    processor = AutoProcessor.from_pretrained(name)
    model = MusicgenForConditionalGeneration.from_pretrained(name, torch_dtype=dtype).to(device)

    seconds = max(1.0, min(a.seconds, 30.0))
    tokens = int(seconds * model.config.audio_encoder.frame_rate)
    inputs = processor(text=[a.prompt], padding=True, return_tensors="pt").to(device)
    with torch.inference_mode():
        audio = model.generate(**inputs, do_sample=True, guidance_scale=3.0, max_new_tokens=tokens)

    rate = model.config.audio_encoder.sampling_rate
    data = audio[0, 0].float().cpu().numpy()
    data = data / max(1e-6, float(np.abs(data).max())) * 0.9
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    wav.write(a.out, rate, (data * 32767).astype(np.int16))
    print(f"saved: {a.out} ({len(data) / rate:.1f}s, {rate} Hz)")


if __name__ == "__main__":
    main()
