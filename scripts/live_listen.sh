#!/usr/bin/env bash
set -euo pipefail

# Live Listener: mic → ElevenLabs realtime STT → optional TTS response
# Requires: ffmpeg, websocat, python3

MODE="always"   # always | push
TTS_ENGINE="elevenlabs"  # elevenlabs | say | none
DEVICE=":0"     # avfoundation device string (macOS)
LANG_CODE=""    # optional language code
VOICE_ID="${ELEVENLABS_VOICE_ID:-WNxHBFUm0NC5fojx98kr}"
PUSH_KEY="ENTER" # when --mode push, wait for this key (e.g., Q)

while [[ $# -gt 0 ]]; do
  case $1 in
    --mode) MODE="$2"; shift 2 ;;
    --tts) TTS_ENGINE="$2"; shift 2 ;;
    --device) DEVICE="$2"; shift 2 ;;
    --lang) LANG_CODE="$2"; shift 2 ;;
    --voice-id) VOICE_ID="$2"; shift 2 ;;
    --key) PUSH_KEY="$2"; shift 2 ;;
    -h|--help)
      cat << EOF2
Usage: $(basename "$0") [options]

Options:
  --mode always|push        Always-on or push-to-talk (default: always)
  --tts elevenlabs|say|none TTS engine (default: elevenlabs)
  --device DEVICE           Mic device for ffmpeg (default: :0)
  --lang CODE               Language code hint (optional)
  --voice-id ID             ElevenLabs voice ID for TTS
  --key KEY                 Push-to-talk key (default: ENTER)

Examples:
  $(basename "$0") --mode always --tts elevenlabs
  $(basename "$0") --mode push --tts say
EOF2
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if ! command -v websocat >/dev/null 2>&1; then
  echo "Error: websocat is required. Install: brew install websocat" >&2
  exit 1
fi
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Error: ffmpeg is required. Install: brew install ffmpeg" >&2
  exit 1
fi
if [[ -z "${ELEVENLABS_API_KEY:-}" ]]; then
  echo "Error: ELEVENLABS_API_KEY not set" >&2
  exit 1
fi

if [[ "$MODE" == "push" ]]; then
  if [[ "$PUSH_KEY" == "ENTER" ]]; then
    echo "Press ENTER to start listening..." >&2
    read -r
  else
    echo "Press $PUSH_KEY to start listening..." >&2
    while true; do
      IFS= read -r -n1 -s key
      if [[ "${key^^}" == "${PUSH_KEY^^}" ]]; then
        break
      fi
    done
  fi
fi

MODEL_ID="scribe_v2_realtime"
AUDIO_FORMAT="pcm_16000"
WS_URL="wss://api.elevenlabs.io/v1/speech-to-text/realtime?model_id=${MODEL_ID}&audio_format=${AUDIO_FORMAT}&include_timestamps=true"
if [[ -n "$LANG_CODE" ]]; then
  WS_URL+="&language_code=${LANG_CODE}"
fi

python3 - <<'PY' "$DEVICE" "$WS_URL" "$TTS_ENGINE" "$VOICE_ID"
import sys, json, base64, subprocess, threading, queue, os, tempfile

DEVICE, WS_URL, TTS_ENGINE, VOICE_ID = sys.argv[1:5]
API_KEY = os.environ.get("ELEVENLABS_API_KEY", "")

sample_rate = 16000
bytes_per_sample = 2
chunk_ms = 200
bytes_per_ms = int(sample_rate * bytes_per_sample / 1000)
chunk_bytes = bytes_per_ms * chunk_ms

# ffmpeg mic capture
ffmpeg_cmd = [
    "ffmpeg", "-hide_banner", "-loglevel", "error",
    "-f", "avfoundation", "-i", DEVICE,
    "-ac", "1", "-ar", str(sample_rate), "-f", "s16le", "pipe:1"
]
ffmpeg = subprocess.Popen(ffmpeg_cmd, stdout=subprocess.PIPE)

# websocat websocket
ws = subprocess.Popen([
    "websocat", WS_URL, "-t", "-H", f"xi-api-key: {API_KEY}"
], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)

# Reader thread for websocket output
q = queue.Queue()

def reader():
    for line in ws.stdout:
        q.put(line.strip())

threading.Thread(target=reader, daemon=True).start()

# TTS helpers

def tts_say(text):
    subprocess.Popen(["say", text])


def tts_elevenlabs(text):
    if not VOICE_ID:
        return
    # Stream TTS to temp mp3 then play
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".mp3")
    tmp.close()
    tts_cmd = [
        "curl", "-s", "-X", "POST",
        f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}/stream",
        "-H", f"xi-api-key: {API_KEY}",
        "-H", "Content-Type: application/json",
        "-d", json.dumps({"text": text})
    ]
    with open(tmp.name, "wb") as f:
        subprocess.run(tts_cmd, stdout=f, stderr=subprocess.DEVNULL)
    subprocess.Popen(["afplay", tmp.name])


def speak(text):
    if not text:
        return
    if TTS_ENGINE == "say":
        tts_say(text)
    elif TTS_ENGINE == "elevenlabs":
        tts_elevenlabs(text)

# Stream audio chunks
chunk = ffmpeg.stdout.read(chunk_bytes)
while chunk:
    next_chunk = ffmpeg.stdout.read(chunk_bytes)
    commit = False if next_chunk else True
    b64 = base64.b64encode(chunk).decode("ascii")
    msg = {
        "message_type": "input_audio_chunk",
        "audio_base_64": b64,
        "commit": commit,
        "sample_rate": sample_rate,
    }
    ws.stdin.write(json.dumps(msg) + "\n")
    ws.stdin.flush()

    # Read any responses
    while not q.empty():
        line = q.get()
        try:
            data = json.loads(line)
        except Exception:
            continue
        mtype = data.get("message_type", "")
        if mtype in ("committed_transcript", "committed_transcript_with_timestamps"):
            text = data.get("text", "")
            if text:
                print(text, flush=True)
                speak(text)
    chunk = next_chunk
PY
