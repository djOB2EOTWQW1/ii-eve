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

# Sets global array ENC_ARGS. Software-only for now; Task 3 adds VAAPI.
resolve_encoder_args() {
    ENC_ARGS=(--pixel-format yuv420p -p "crf=$QUALITY")
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
