---
name: eleven-stt
description: Transcribe audio files with ElevenLabs Speech-to-Text (Scribe v2) from the local CLI. Supports diarization, events, JSON output, webhooks, and advanced STT options.
metadata: {"openclaw":{"requires":{"bins":["curl","jq","python3","ffmpeg","websocat"],"env":["ELEVENLABS_API_KEY"]}}}
---

# ElevenLabs Speech-to-Text (Local CLI)

## Quick start

```bash
# Local file (requires ALLOW_LOCAL_FILE=true)
ALLOW_LOCAL_FILE=true scripts/transcribe.sh /path/to/audio.mp3

# Cloud URL
scripts/transcribe.sh --url https://example.com/audio.mp3 --lang en
```

## Common options

```bash
scripts/transcribe.sh /path/to/audio.mp3 --diarize --lang en
scripts/transcribe.sh /path/to/audio.mp3 --json
scripts/transcribe.sh /path/to/audio.mp3 --webhook --webhook-metadata '{"job":"call-001"}'
```

## Environment

- `ELEVENLABS_API_KEY` (required)
- `ALLOW_LOCAL_FILE=true` (required for local file paths)

## Notes

- Default model: `scribe_v2` (file‑based STT).
- Realtime: `scripts/realtime.sh` (uses `scribe_v2_realtime`).
- Live listener: `scripts/live_listen.sh` (toggle/always‑on, optional TTS).
- Async: use `--webhook` (+ `--webhook-id`, `--webhook-metadata`).
