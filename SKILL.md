---
name: eleven-stt
description: Transcribe audio files with ElevenLabs Speech-to-Text (Scribe v2) from the local CLI. Use when you need local transcription via curl/jq with diarization, language hinting, or JSON output.
---

# ElevenLabs Speech-to-Text (Local CLI)

## Use

Run the script in `scripts/transcribe.sh` with an audio file path and optional flags.

Examples:

```bash
scripts/transcribe.sh /path/to/audio.mp3
scripts/transcribe.sh /path/to/audio.mp3 --diarize --lang en
scripts/transcribe.sh /path/to/audio.mp3 --json
scripts/transcribe.sh /path/to/audio.mp3 --model flash_v2.5
```

## Environment

Set `ELEVENLABS_API_KEY` in your shell or OpenClaw env before running.

## Notes

- Defaults to `scribe_v2` (the Speech-to-Text model) and uses a filesystem lock to avoid parallel requests.
- Requires `curl` and `jq`.
