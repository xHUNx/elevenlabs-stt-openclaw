#!/usr/bin/env bash
set -euo pipefail

# Live Listener: mic → ElevenLabs realtime STT → optional response/TTS
# Requires: ffmpeg, websocat, python3

MODE="toggle"          # toggle | always
TTS_ENGINE="elevenlabs" # elevenlabs | say | none
PUSH_KEY="Q"            # key to toggle start/stop
DEVICE=":0"            # avfoundation device string (macOS)
LANG_CODE=""           # optional language code
VOICE_ID="${ELEVENLABS_VOICE_ID:-WNxHBFUm0NC5fojx98kr}"
ON_TRANSCRIPT=""        # optional command to run with transcript

while [[ $# -gt 0 ]]; do
  case $1 in
    --mode) MODE="$2"; shift 2 ;;
    --tts) TTS_ENGINE="$2"; shift 2 ;;
    --key) PUSH_KEY="$2"; shift 2 ;;
    --device) DEVICE="$2"; shift 2 ;;
    --lang) LANG_CODE="$2"; shift 2 ;;
    --voice-id) VOICE_ID="$2"; shift 2 ;;
    --on-transcript) ON_TRANSCRIPT="$2"; shift 2 ;;
    -h|--help)
      cat << EOF2
Usage: $(basename "$0") [options]

Options:
  --mode toggle|always        Toggle start/stop or always-on (default: toggle)
  --tts elevenlabs|say|none   TTS engine (default: elevenlabs)
  --key KEY                   Toggle key (default: Q)
  --device DEVICE             Mic device for ffmpeg (default: :0)
  --lang CODE                 Language code hint (optional)
  --voice-id ID               ElevenLabs voice ID for TTS
  --on-transcript CMD         Run command with transcript (as $TEXT)

Examples:
  $(basename "$0") --mode toggle --tts elevenlabs --key Q
  $(basename "$0") --mode always --tts say
EOF2
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

for bin in websocat ffmpeg python3; do
  command -v "$bin" >/dev/null 2>&1 || { echo "Error: $bin is required" >&2; exit 1; }
done

if [[ -z "${ELEVENLABS_API_KEY:-}" ]]; then
  echo "Error: ELEVENLABS_API_KEY not set" >&2
  exit 1
fi

MODEL_ID="scribe_v2_realtime"
AUDIO_FORMAT="pcm_16000"
WS_URL="wss://api.elevenlabs.io/v1/speech-to-text/realtime?model_id=${MODEL_ID}&audio_format=${AUDIO_FORMAT}&include_timestamps=true"
if [[ -n "$LANG_CODE" ]]; then
  WS_URL+="&language_code=${LANG_CODE}"
fi

python3 - <<'PY' "$MODE" "$PUSH_KEY" "$DEVICE" "$WS_URL" "$TTS_ENGINE" "$VOICE_ID" "$ON_TRANSCRIPT"
import sys, os, json, base64, subprocess, threading, queue, termios, tty, time, tempfile

MODE, PUSH_KEY, DEVICE, WS_URL, TTS_ENGINE, VOICE_ID, ON_TRANSCRIPT = sys.argv[1:8]
API_KEY = os.environ.get("ELEVENLABS_API_KEY", "")

sample_rate = 16000
bytes_per_sample = 2
chunk_ms = 200
bytes_per_ms = int(sample_rate * bytes_per_sample / 1000)
chunk_bytes = bytes_per_ms * chunk_ms

stop_event = threading.Event()


def tts_say(text):
    subprocess.Popen(["say", text])


def tts_elevenlabs(text):
    if not VOICE_ID:
        return
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
    if os.path.getsize(tmp.name) > 0:
        subprocess.Popen(["afplay", tmp.name])


def speak(text):
    if not text:
        return
    if TTS_ENGINE == "say":
        tts_say(text)
    elif TTS_ENGINE == "elevenlabs":
        tts_elevenlabs(text)


def on_transcript(text):
    if not ON_TRANSCRIPT:
        return
    env = os.environ.copy()
    env["TEXT"] = text
    subprocess.Popen(ON_TRANSCRIPT, shell=True, env=env)


def stream_once():
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

    q = queue.Queue()

    def reader():
        for line in ws.stdout:
            q.put(line.strip())

    threading.Thread(target=reader, daemon=True).start()

    chunk = ffmpeg.stdout.read(chunk_bytes)
    while chunk and not stop_event.is_set():
        next_chunk = ffmpeg.stdout.read(chunk_bytes)
        commit = False if next_chunk else True
        b64 = base64.b64encode(chunk).decode("ascii")
        msg = {
            "message_type": "input_audio_chunk",
            "audio_base_64": b64,
            "commit": commit,
            "sample_rate": sample_rate,
        }
        try:
            ws.stdin.write(json.dumps(msg) + "\n")
            ws.stdin.flush()
        except Exception:
            break

        while not q.empty():
            try:
                data = json.loads(q.get())
            except Exception:
                continue
            mtype = data.get("message_type", "")
            if mtype in ("committed_transcript", "committed_transcript_with_timestamps"):
                text = data.get("text", "")
                if text:
                    print(text, flush=True)
                    on_transcript(text)
                    speak(text)

        chunk = next_chunk

    # cleanup
    try:
        ws.terminate()
    except Exception:
        pass
    try:
        ffmpeg.terminate()
    except Exception:
        pass


def get_keypress():
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        ch = sys.stdin.read(1)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)
    return ch


if MODE == "always":
    stream_once()
else:
    print(f"Press {PUSH_KEY} to start/stop. Ctrl+C to exit.")
    listening = False
    while True:
        key = get_keypress()
        if key.upper() == PUSH_KEY.upper():
            if not listening:
                stop_event.clear()
                t = threading.Thread(target=stream_once)
                t.daemon = True
                t.start()
                listening = True
            else:
                stop_event.set()
                listening = False
PY
