# ElevenLabs STT for OpenClaw

A clean, local OpenClaw skill that transcribes audio with ElevenLabs Speech‑to‑Text (Scribe v2). It’s built for simple CLI use, with diarization, audio‑event tagging, and JSON output when you need structured data.

---

## ✨ Features

- **Scribe v2** transcription (default model)
- **Speaker diarization** (`--diarize`)
- **Audio event tags** (`--events`) — e.g., `[laughing]`, `[chuckles]`
- **Word‑level JSON output** (`--json`)
- **Language hinting** (`--lang en`, `--lang hu`, etc.)
- **Concurrency‑safe** via a filesystem lock (no parallel requests)

---

## ✅ Requirements

- `curl`
- `jq`
- ElevenLabs API key set in environment:

```bash
export ELEVENLABS_API_KEY="sk_..."
```

---

## 🚀 Usage

From inside the skill folder:

```bash
# Basic transcription
scripts/transcribe.sh /path/to/audio.ogg

# Diarization + language hint
scripts/transcribe.sh /path/to/audio.ogg --diarize --lang en

# JSON output with word timings
scripts/transcribe.sh /path/to/audio.ogg --json

# Audio‑event tagging
scripts/transcribe.sh /path/to/audio.ogg --events
```

### Model override
The valid Speech‑to‑Text models are:

- `scribe_v1`
- `scribe_v1_experimental`
- `scribe_v2` (default)

Example:

```bash
scripts/transcribe.sh /path/to/audio.ogg --model scribe_v1_experimental
```

---

## 🔒 Concurrency Safety

The script uses a lock to prevent parallel requests. If you see:

```
Error: Another transcription is currently running. Please wait a moment.
```

…just wait for the prior request to finish and retry.

---

## 🧪 Suggested Tests

- **Two‑speaker clip** → verify diarization
- **Laughter / music** → verify audio event tagging
- **Longer clip** → verify JSON timings

---

## Troubleshooting

- **422 Invalid model** → use only the Scribe models above.
- **429 Too Many Requests** → you hit rate limits; wait or reduce parallel usage.
- **503 Service Unavailable** → ElevenLabs outage; retry later.

---

## Files

- `SKILL.md` — OpenClaw skill manifest
- `scripts/transcribe.sh` — transcription CLI

---

If you want extra features (webhooks, realtime streaming, multi‑channel), tell me and I’ll extend the skill.
