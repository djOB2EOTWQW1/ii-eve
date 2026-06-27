#!/usr/bin/env bash

CONFIG_FILE="$HOME/.config/illogical-impulse/config.json"
STATE_FILE="$HOME/.local/state/quickshell/states.json"
STATE_JSON_PATH=".screenRecord.active"

cfg() { jq -r "$1 // empty" "$CONFIG_FILE" 2>/dev/null; }

CUSTOM_PATH="$(cfg '.screenRecord.savePath')"
ENCODER="$(cfg '.screenRecord.encoder')";       ENCODER="${ENCODER:-auto}"
DEVICE_CFG="$(cfg '.screenRecord.device')"
FRAMERATE="$(cfg '.screenRecord.framerate')";   FRAMERATE="${FRAMERATE:-60}"
QUALITY="$(cfg '.screenRecord.quality')";        QUALITY="${QUALITY:-24}"
AUDIO_CODEC="$(cfg '.screenRecord.audioCodec')"

RECORDING_DIR="${CUSTOM_PATH:-$HOME/Videos}"

TIMER_PID=""
SECONDS_ELAPSED=-1

start_timer() {
    if [[ -n "$TIMER_PID" ]]; then
        kill "$TIMER_PID" 2>/dev/null
    fi

    (
        while true; do
            SECONDS_ELAPSED=$((SECONDS_ELAPSED + 1))
            jq ".screenRecord.seconds = $SECONDS_ELAPSED" "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
            sleep 1
        done
    ) &
    TIMER_PID=$!
}
stop_timer() {
    if [[ -n "$TIMER_PID" ]]; then
        kill "$TIMER_PID" 2>/dev/null
        wait "$TIMER_PID" 2>/dev/null
        TIMER_PID=""
        jq ".screenRecord.seconds = 0" "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
    fi
}

trap stop_timer EXIT

getdate() {
    date '+%Y-%m-%d_%H.%M.%S'
}

getaudiooutput() {
    pactl list sources | grep 'Name' | grep 'monitor' | cut -d ' ' -f2 | head -n1
}
getactivemonitor() {
    hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name'
}

updatestate() {
    local state_value=$1
    jq "$STATE_JSON_PATH = $state_value" "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
    if [[ "$state_value" == "true" ]]; then
        start_timer
    else
        stop_timer
    fi
}

_enc_fail() {
    notify-send "Recording cancelled" "$1" -a 'Recorder' & disown
    updatestate false
    exit 1
}

probe_vaapi_node() {
    local node="$1"
    [[ -e "$node" ]] || return 1
    ffmpeg -loglevel error -vaapi_device "$node" \
        -f lavfi -i color=black:s=256x256:d=0.1 \
        -vf 'format=nv12,hwupload' -c:v h264_vaapi -f null - </dev/null >/dev/null 2>&1
}

probe_nvenc() {
    ffmpeg -loglevel error \
        -f lavfi -i color=black:s=256x256:d=0.1 \
        -c:v h264_nvenc -f null - </dev/null >/dev/null 2>&1
}

detect_vaapi_node() {
    if [[ -n "$DEVICE_CFG" ]]; then
        probe_vaapi_node "$DEVICE_CFG" && { echo "$DEVICE_CFG"; return 0; }
        return 1
    fi
    local node
    for node in /dev/dri/renderD12*; do
        probe_vaapi_node "$node" && { echo "$node"; return 0; }
    done
    return 1
}

# Sets global array ENC_ARGS based on $ENCODER (auto|hardware|software|vaapi|nvenc).
# auto: VAAPI -> NVENC -> software. hardware: VAAPI -> NVENC -> abort.
resolve_encoder_args() {
    local node=""
    case "$ENCODER" in
        software)
            ENC_ARGS=(--pixel-format yuv420p -p "crf=$QUALITY")
            ;;
        vaapi)
            node="$(detect_vaapi_node)" || _enc_fail "No working VAAPI device"
            ENC_ARGS=(-c h264_vaapi -d "$node" -p "qp=$QUALITY")
            ;;
        nvenc)
            probe_nvenc || _enc_fail "NVENC not available"
            ENC_ARGS=(-c h264_nvenc -p "qp=$QUALITY")
            ;;
        hardware|*)
            if node="$(detect_vaapi_node)"; then
                ENC_ARGS=(-c h264_vaapi -d "$node" -p "qp=$QUALITY")
            elif probe_nvenc; then
                ENC_ARGS=(-c h264_nvenc -p "qp=$QUALITY")
            elif [[ "$ENCODER" == "hardware" ]]; then
                _enc_fail "No working hardware encoder (VAAPI/NVENC)"
            else
                ENC_ARGS=(--pixel-format yuv420p -p "crf=$QUALITY")
            fi
            ;;
    esac
}

mkdir -p "$RECORDING_DIR"
cd "$RECORDING_DIR" || exit

# parse flags without consuming $@ ordering
ARGS=("$@")
MANUAL_REGION=""
SOUND_FLAG=0
FULLSCREEN_FLAG=0
for ((i=0;i<${#ARGS[@]};i++)); do
    if [[ "${ARGS[i]}" == "--region" ]]; then
        if (( i+1 < ${#ARGS[@]} )); then
            MANUAL_REGION="${ARGS[i+1]}"
        else
            notify-send "Recording cancelled" "No region specified for --region" -a 'Recorder' & disown
            updatestate false
            exit 1
        fi
    elif [[ "${ARGS[i]}" == "--sound" ]]; then
        SOUND_FLAG=1
    elif [[ "${ARGS[i]}" == "--fullscreen" ]]; then
        FULLSCREEN_FLAG=1
    fi
done

if pgrep -x wf-recorder > /dev/null; then
    notify-send "Recording Stopped" "Stopped" -a 'Recorder' &
    updatestate false
    pkill -INT -x wf-recorder
else
    FILENAME="recording_$(getdate).mp4"

    GEO_ARGS=()
    if [[ $FULLSCREEN_FLAG -ne 1 ]]; then
        if [[ -n "$MANUAL_REGION" ]]; then
            region="$MANUAL_REGION"
        else
            if ! region="$(slurp 2>&1)"; then
                notify-send "Recording cancelled" "Selection was cancelled" -a 'Recorder' & disown
                updatestate false
                exit 1
            fi
        fi
        pos="${region%% *}"      # x,y
        size="${region##* }"     # WxH
        x="${pos%,*}"
        y="${pos#*,}"
        GEO_ARGS=(--geometry "${x},${y} ${size}")
    fi

    RATE_ARGS=()
    if [[ "$FRAMERATE" =~ ^[0-9]+$ ]] && (( FRAMERATE > 0 )); then
        RATE_ARGS=(-r "$FRAMERATE")
    fi

    AUDIO_ARGS=()
    if [[ $SOUND_FLAG -eq 1 ]]; then
        AUDIO_ARGS=(--audio="$(getaudiooutput)")
        [[ -n "$AUDIO_CODEC" ]] && AUDIO_ARGS+=(-C "$AUDIO_CODEC")
    fi

    resolve_encoder_args

    notify-send "Starting recording" "$FILENAME" -a 'Recorder' & disown
    updatestate true

    cmd=(wf-recorder -o "$(getactivemonitor)" -f "./$FILENAME"
         "${ENC_ARGS[@]}" "${RATE_ARGS[@]}" "${GEO_ARGS[@]}" "${AUDIO_ARGS[@]}")
    "${cmd[@]}"
fi
