# Cemaat transcriber: free local speech-to-text with faster-whisper (GPU if available, else CPU).
# Usage:
#   python transcribe.py <audio-or-video> <out-dir> [--model large-v3-turbo] [--lang tr]
# Writes <name>.srt, <name>.txt ("[hh:mm:ss] text" per segment) and <name>.json (segments with start/end).
import argparse, json, os, site, sys, glob


def add_cuda_dll_dirs():
    # pip's nvidia-* wheels put DLLs under site-packages/nvidia/*/bin; Windows needs them registered.
    if os.name != "nt":
        return
    roots = site.getsitepackages() + [site.getusersitepackages()]
    for root in roots:
        for d in glob.glob(os.path.join(root, "nvidia", "*", "bin")):
            try:
                os.add_dll_directory(d)
                os.environ["PATH"] = d + os.pathsep + os.environ.get("PATH", "")
            except OSError:
                pass


def ts(sec, srt=False):
    h, rem = divmod(sec, 3600)
    m, s = divmod(rem, 60)
    if srt:
        return f"{int(h):02d}:{int(m):02d}:{int(s):02d},{int((s % 1) * 1000):03d}"
    return f"{int(h):02d}:{int(m):02d}:{int(s):02d}"


def load_model(name):
    from faster_whisper import WhisperModel
    try:
        return WhisperModel(name, device="cuda", compute_type="float16"), "cuda"
    except Exception as e:
        print(f"GPU unavailable ({e.__class__.__name__}); using CPU", file=sys.stderr)
        return WhisperModel(name, device="cpu", compute_type="int8"), "cpu"


def main():
    p = argparse.ArgumentParser()
    p.add_argument("input")
    p.add_argument("outdir")
    p.add_argument("--model", default="large-v3-turbo")
    p.add_argument("--lang", default="tr")
    a = p.parse_args()

    add_cuda_dll_dirs()
    os.makedirs(a.outdir, exist_ok=True)
    name = os.path.splitext(os.path.basename(a.input))[0]
    model, device = load_model(a.model)
    print(f"model={a.model} device={device}", file=sys.stderr)

    # Decode with ffmpeg (16 kHz mono float32) instead of PyAV, which breaks across versions.
    import subprocess, numpy as np
    raw = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-i", a.input, "-f", "f32le", "-ac", "1", "-ar", "16000", "-"],
                         capture_output=True, check=True).stdout
    audio = np.frombuffer(raw, dtype=np.float32)
    segments, info = model.transcribe(audio, language=a.lang, vad_filter=True, beam_size=5)
    segs = []
    for s in segments:
        segs.append({"start": round(s.start, 2), "end": round(s.end, 2), "text": s.text.strip()})
        print(f"[{ts(s.start)}] {s.text.strip()}", file=sys.stderr)

    base = os.path.join(a.outdir, name)
    with open(base + ".json", "w", encoding="utf-8") as f:
        json.dump({"language": info.language, "duration": info.duration, "segments": segs}, f, ensure_ascii=False, indent=1)
    with open(base + ".txt", "w", encoding="utf-8") as f:
        f.writelines(f"[{ts(s['start'])}] {s['text']}\n" for s in segs)
    with open(base + ".srt", "w", encoding="utf-8") as f:
        for i, s in enumerate(segs, 1):
            f.write(f"{i}\n{ts(s['start'], True)} --> {ts(s['end'], True)}\n{s['text']}\n\n")
    print(f"saved: {base}.srt / .txt / .json  segments={len(segs)} duration={info.duration:.1f}s")


if __name__ == "__main__":
    main()
