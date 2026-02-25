# ElevenLabs STT for OpenClaw

A clean, local OpenClaw skill that transcribes audio with ElevenLabs Speech‑to‑Text (Scribe v2). It supports diarization, audio‑event tagging, JSON output, and optional webhook‑based async processing so users can choose how they want to run it.

---

## ✨ Features

- **Scribe v2** transcription (default model)
- **Speaker diarization** (`--diarize`)
- **Audio event tags** (`--events`) — e.g., `[laughing]`, `[chuckles]`
- **Word‑level JSON output** (`--json`)
- **Language hinting** (`--lang en`, `--lang hu`, etc.)
- **Async webhooks** (`--webhook`, `--webhook-id`, `--webhook-metadata`)
- **Cloud URL input** (`--url https://...`) for hosted files
- **Advanced controls**: timestamps granularity, entity detection, keyterms, multi‑channel
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

## 🛰️ Webhooks (Async)

Use webhooks if you want the job to run asynchronously and receive results later.

```bash
scripts/transcribe.sh /path/to/audio.ogg --webhook
scripts/transcribe.sh /path/to/audio.ogg --webhook --webhook-id abc123 \
  --webhook-metadata '{"job":"call-001","owner":"dan"}'
```

---

## ☁️ Cloud URL Input

Transcribe from a public HTTPS URL instead of uploading a file:

```bash
scripts/transcribe.sh --url https://example.com/audio.mp3 --lang en
```

---

## 🔧 Advanced Flags

```bash
--timestamps none|word|character   # word is default
--num-speakers N                   # 1–32
--diarization-threshold X          # 0–1
--use-multi-channel                # split multi‑channel audio
--entity-detection MODE            # e.g. all|pii|phi|pci|offensive_language
--keyterms "a,b,c"                  # bias key terms
--enable-logging true|false        # default true
```

---

## 🔒 Concurrency Safety

The script uses a lock to prevent parallel requests. If you see:

```
Error: Another transcription is currently running. Please wait a moment.
```

…just wait for the prior request to finish and retry.

---

## Troubleshooting

- **422 Invalid model** → use only the Scribe models above.
- **429 Too Many Requests** → you hit rate limits; wait or reduce usage.
- **503 Service Unavailable** → ElevenLabs outage; retry later.

---

## Files

- `SKILL.md` — OpenClaw skill manifest
- `scripts/transcribe.sh` — transcription CLI

---

If you want realtime streaming (WebSocket) or auto‑registration of webhooks, I can add those too.
