---
name: cemaat
description: Multi-model orchestration. Use when the user gives a task and asks to split it across agents/workers, or says "cemaat", "/cemaat", "ajanlara dağıt", "işçilere ver", "minimax", "mimo", "deepseek", "gemma". Claude (the current session) is the orchestrator; MiniMax, MiMo, DeepSeek and Gemma run as headless worker agents via Routeway (or OpenRouter). Claude plans, dispatches, verifies, fixes and delivers.
---

# Cemaat

You are the orchestrator. Workers are cheaper non-Claude models. You own the result: nothing is delivered until you verified it.

Save the user's Claude usage: workers do the writing, you plan and check. Do not write large code yourself when a worker can. When verifying, start with `git diff --stat` and worker reports, then read only the changed parts; run tests instead of reading code line by line where possible.

Scripts: the `scripts` folder in this skill's base directory (shown when the skill loads). In every PowerShell command below, `$S` means that folder: start the command with `$S = "<base directory>\scripts";`.
Worker script: `$S\worker.ps1`
Models and providers: `$S\models.json` (aliases `mimo`, `deepseek`, `minimax`, `gemma`; a full model ID also works, with `-Provider routeway|openrouter`)
Routeway free models (`:free`): 20 requests/minute, 200 requests/day, reset 00:00 UTC. One worker run uses many requests (one per tool turn). Keep free-model tasks small and few; do not run more than 2 free workers in parallel.
Worker logs: `$HOME\.claude\cemaat\logs\`

## 1. Understand
- Restate the goal in one or two sentences. If a decision only the user can make blocks the plan, ask once. Otherwise proceed.
- Find the project folder. If it is a git repo, run `git status`; note uncommitted changes so worker changes can be told apart. If it is not a repo and the task edits files, suggest `git init` + an initial commit so changes can be reviewed and reverted.

## 2. Plan and split
- Break the task into subtasks. Each subtask: one clear goal, an explicit list of files it may touch, a done condition.
- Two parallel subtasks must never touch the same file.
- Routing (Routeway workers priced per 1M tokens in/out):
  - Code: Routeway workers first, to save the user's Claude plan usage: `mimo` for most code, `deepseek` (0.20/0.65) for hard bugs and second opinions. Use your own subagents (Agent tool, `model: haiku` / `model: sonnet`) only when a task needs shell commands, or a Routeway worker failed twice. They count against the user's Claude Pro plan limit.
  - Games, plugins/extensions, Blender 3D scripts: `mimo` (mimo-v2.6-flash, 0.14/0.28), `-Mode edit`.
  - Video editing: `minimax` (minimax-m3.1-flash, 0.15/0.60). Workers cannot see video files and cannot run commands. You extract frames with ffmpeg (`ffmpeg -i in.mp4 -vf fps=1 frames/%04d.png`); the worker reads the PNGs and writes the edit plan and the ffmpeg/Python script; you run the script and check the output (duration, frames at cut points).
  - Writing and small read-only tasks (free): `gemma` (gemma-4-26b-a4b-it-luminous:free). Video scripts, voice-over text, game dialogue, descriptions, summaries. Not for code. 62k context, so give it few files. Limit 20 requests/minute, 200/day: at most 2 `gemma` workers in parallel, keep tasks small (`-MaxTurns 10`). Its text goes through you before use: fix weak writing yourself.
  - Do not use `minimax-free` or `deepseek-v4.1-flash:free`: Routeway's `/v1/messages` returns 502 for them (tested 2026-11-13).
  - Motion graphics / animated video: code, not a video model. `mimo` writes Remotion, HTML/CSS/canvas or Manim code; you render it to MP4 and check frames.
  - Images: `gen-image.ps1` (Routeway), not a worker. Pick a model from `imageModels` in models.json: `draft` for many variations, `general` for game assets, `hq` for final quality, `graphic` for logos/icons, `edit` for edits, `text` for readable text. Start with drafts, show the user, then render the final with a better model.
    `powershell -NoProfile -ExecutionPolicy Bypass -File "$S\gen-image.ps1" -Model z-image-turbo -Size 1024x1024 -Prompt "<prompt>" -Out "<project>\assets\name.png"`
    Look at every image you generate before using it.
  - 2D game sprites/characters (transparent PNG): `gen-sprite.ps1` = Routeway image + rembg background removal. `-Style pixel|flat|painted|anime|none`. Raw image kept as `<name>.raw.png`.
    `powershell -NoProfile -ExecutionPolicy Bypass -File "$S\gen-sprite.ps1" -Style pixel -Prompt "<subject, pose, view>" -Out "<project>\assets\hero.png"`
    Same character in many poses: generate the first, then use the `edit` image model with the first as reference. Image models add unrequested symbols (e.g. crosses on shields): say what you want on items explicitly and check every sprite.
  - 3D models (GLB): no AI 3D model on Routeway. `mimo` writes a Blender Python script following `$S\blender-template.py` (scene building only: meshes + materials); you run `make-3d.ps1`, which exports GLB and renders `<name>.preview.png`. Look at the preview; send fixes back to the worker. Good for low-poly props, buildings, environments, simple characters; weak for detailed organic characters (tell the user).
    `powershell -NoProfile -ExecutionPolicy Bypass -File "$S\make-3d.ps1" -Script "<project>\3d\tree.py" -Out "<project>\assets\tree.glb"`
  - Voice-over (TTS): `gen-voice.ps1` (edge-tts, free; writes MP3 + SRT subtitles). Turkish voices: `tr-TR-AhmetNeural`, `tr-TR-EmelNeural`.
    `powershell -NoProfile -ExecutionPolicy Bypass -File "$S\gen-voice.ps1" -Voice tr-TR-EmelNeural -Text "<text>" -Out "<project>\audio\vo.mp3"` (long scripts: `-TextFile`)
  - Transcription (speech-to-text, free, local): `transcribe.py` (faster-whisper `large-v3-turbo`, GPU if available). Writes `<name>.srt`, `<name>.txt` (`[hh:mm:ss] text` lines) and `<name>.json` (segments). Use it first on any talk/interview/sermon video: chapters, titles, overlay timing and subtitles all come from the transcript. Roughly 3-6 min per hour of audio on GPU, much slower on CPU (run long files with `run_in_background`).
    `python "$S\transcribe.py" "<video or audio>" "<project>\transcript" --lang tr`
    Chaptering: give the `.txt` to `minimax` (or `gemma` for short files; it has a 62k context, so split long transcripts) to propose chapters with start times and short titles; check them against the transcript yourself.
  - ffmpeg/ffprobe are installed (winget, Gyan.FFmpeg). If not on PATH in an old shell, reload PATH from Machine+User.
  - AI-generated video and music: Routeway has none. Nim plugin can do video if the user connects it via /mcp. Otherwise tell the user; do not sign up for services yourself.
  - Yourself: architecture, cross-cutting or risky changes, anything security-sensitive, anything a worker failed twice.
- Show the user the plan as the task list (update_plan), with the worker named on each step.

## 3. Dispatch
Run each worker with the PowerShell tool. Independent workers go out in parallel with `run_in_background: true`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$S\worker.ps1" -Model mimo -Mode edit -Dir "<project path>" -Task "<self-contained task: goal, files allowed, done condition, constraints>"
```

- Task text must be self-contained: the worker sees nothing of this conversation.
- Workers cannot run shell commands. You run builds and tests.
- Do not use `glm` (glm-5.3-flash): Routeway `/v1/messages` returns 502 for it (tested 2026-11-13). Exit code 124 = worker timed out (default 20 min, `-TimeoutMin`); usually a gateway error: re-route to another model.
- Exit code 2 = provider key missing (`ROUTEWAY_API_KEY` or `OPENROUTER_API_KEY`, named in the error): stop and tell the user how to set it (user environment variable, then restart the Claude app). Never ask for the key in chat.
- Rate limit (429) / model not found: tell the user. List valid Routeway IDs with `Invoke-RestMethod https://api.routeway.ai/v1/models`. Change models.json only if the user confirms, or do that subtask yourself.

## 4. Verify (mandatory)
For every worker result:
- Read its report and the log. Check the actual diff (`git diff` in a repo, otherwise read the files).
- Confirm it stayed inside its allowed files. Revert anything outside scope.
- Run the project's build, linter and tests if they exist.
- On a defect: fix small ones yourself; re-dispatch bigger ones once with a precise correction; after a second failure, do it yourself.

## 5. Deliver
Tell the user, in their language:
- What was done, per subtask, and which model did it.
- What you verified (commands run, results). State failures plainly.
- What is not done or not verified.
Do not commit or push unless the user asks.
