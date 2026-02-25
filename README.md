# elevenlabs-stt-openclaw

OpenClaw local skill for ElevenLabs Speech-to-Text (Scribe v2).

## Usage

```bash
# From the skill folder
scripts/transcribe.sh /path/to/audio.ogg --lang en
scripts/transcribe.sh /path/to/audio.ogg --diarize --events --json
```

## Environment

Set `ELEVENLABS_API_KEY` before running.

## Notes

- Defaults to `scribe_v2` (the STT model).
- Uses a filesystem lock to prevent parallel requests.
- Requires `curl` and `jq`.
