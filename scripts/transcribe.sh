#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/.env"
    set +a
fi

LOCK_DIR="/tmp/eleven-stt.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "Error: Another transcription is currently running. Please wait a moment." >&2
    exit 1
fi
cleanup_lock() { rmdir "$LOCK_DIR" 2>/dev/null || true; }
trap cleanup_lock EXIT

# ElevenLabs Speech-to-Text transcription script
# Usage: transcribe.sh <audio_file> [options]

show_help() {
    cat << EOF
Usage: $(basename "$0") <audio_file> [options]

Options:
  --diarize        Enable speaker diarization
  --lang CODE      ISO language code (e.g., en, pt, es, fr)
  --json           Output full JSON response
  --events         Tag audio events (laughter, music, etc.)
  --model MODEL    Specify the ElevenLabs model (default: scribe_v2)
  -h, --help       Show this help

Environment:
  ELEVENLABS_API_KEY  Required API key

Examples:
  $(basename "$0") voice_note.ogg
  $(basename "$0") meeting.mp3 --diarize --lang en --model flash_v2.5
  $(basename "$0") podcast.mp3 --json > transcript.json
EOF
    exit 0
}

# Defaults
DIARIZE="false"
LANG_CODE=""
JSON_OUTPUT="false"
TAG_EVENTS="false"
MODEL_ID="scribe_v2"
FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) show_help ;;
        --diarize) DIARIZE="true"; shift ;;
        --lang) LANG_CODE="$2"; shift 2 ;;
        --json) JSON_OUTPUT="true"; shift ;;
        --events) TAG_EVENTS="true"; shift ;;
        --model) MODEL_ID="$2"; shift 2 ;;
        -*) echo "Unknown option: $1" >&2; exit 1 ;;
        *) FILE="$1"; shift ;;
    esac
done

# Validate
if [[ -z "$FILE" ]]; then
    echo "Error: No audio file specified" >&2
    show_help
fi

if [[ ! -f "$FILE" ]]; then
    echo "Error: File not found: $FILE" >&2
    exit 1
fi

# API key (check env, then fall back to skill config)
API_KEY="${ELEVENLABS_API_KEY:-}"
if [[ -z "$API_KEY" ]]; then
    echo "Error: ELEVENLABS_API_KEY not set" >&2
    exit 1
fi

# Build curl command
CURL_ARGS=(
    -s
    -X POST
    "https://api.elevenlabs.io/v1/speech-to-text"
    -H "xi-api-key: $API_KEY"
    -F "file=@$FILE"
    -F "model_id=$MODEL_ID"
    -F "diarize=$DIARIZE"
    -F "tag_audio_events=$TAG_EVENTS"
)

if [[ -n "$LANG_CODE" ]]; then
    CURL_ARGS+=(-F "language_code=$LANG_CODE")
fi

# Make request
RESPONSE=$(curl "${CURL_ARGS[@]}")

# Check for errors
if echo "$RESPONSE" | grep -q '"detail"'; then
    echo "Error from API:" >&2
    echo "$RESPONSE" | jq -r '.detail.message // .detail' >&2
    exit 1
fi

# Output
if [[ "$JSON_OUTPUT" == "true" ]]; then
    echo "$RESPONSE" | jq .
else
    TEXT=$(echo "$RESPONSE" | jq -r '.text // empty')
    if [[ -n "$TEXT" ]]; then
        echo "$TEXT"
    else
        echo "$RESPONSE"
    fi
fi
