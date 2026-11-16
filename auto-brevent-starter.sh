#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

readonly STATE_DIR="$HOME/.local/state/auto_brevent"
readonly LOG_FILE="$STATE_DIR/script.log"
readonly LOCK_FILE="$STATE_DIR/script.lock"
readonly RISH_PATH="$HOME/.local/bin/rish"
# This path belongs to the remote shell, not Termux's permission context.
readonly BREVENT_SCRIPT_PATH="/data/local/tmp/brevent.sh"

readonly MAX_LOG_LINES=200
readonly POLL_INTERVAL_SECONDS=2
readonly SHIZUKU_WAIT_TIMEOUT_MINUTES=5
readonly BREVENT_LAUNCH_TIMEOUT_SECONDS=60
readonly LOG_THROTTLE_COUNT=15

readonly E_UNAVAILABLE=69
readonly E_SOFTWARE=70
readonly E_SETUP_ERROR=73
readonly E_TIMEOUT=78
readonly E_CONCURRENT=99
readonly E_LOG_UNWRITABLE=100

rish_pid=""
tmp_output=""
wake_locked=0

log_msg() {
    # Bash supplies the timestamp; failed diagnostics must not stop startup.
    printf '%(%Y-%m-%d %H:%M:%S)T - %s\n' -1 "$1" >> "$LOG_FILE" || true
}

require_commands() {
    local cmd
    for cmd; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            printf 'FATAL: Required command not found or not executable: %s\n' "$cmd" >&2
            return "$E_UNAVAILABLE"
        fi
    done
}

rotate_log() {
    local rotated
    rotated=$(mktemp "$STATE_DIR/.log.XXXXXX") || return
    if tail -n "$MAX_LOG_LINES" "$LOG_FILE" > "$rotated" &&
        mv "$rotated" "$LOG_FILE"; then
        return 0
    fi
    rm -f "$rotated"
    return 1
}

cleanup() {
    local status=$?
    trap - EXIT INT TERM

    if [[ -n "$rish_pid" ]]; then
        # GNU timeout leads a local process group. Never target the remote server.
        kill -KILL -- "-$rish_pid" 2>/dev/null || true
        # Also handles a signal arriving before timeout creates its group.
        kill -KILL "$rish_pid" 2>/dev/null || true
        wait "$rish_pid" 2>/dev/null || true
    fi
    [[ -z "$tmp_output" ]] || rm -f "$tmp_output"
    if (( wake_locked )); then
        termux-wake-unlock || true
    fi

    log_msg "Finished (exit code: $status)."
    rotate_log || log_msg "WARNING: Log rotation failed; the log may exceed its line limit."
    exit "$status"
}

wait_for_shizuku() {
    log_msg "Waiting for Shizuku (timeout: ${SHIZUKU_WAIT_TIMEOUT_MINUTES}m)..."
    local deadline=$((SECONDS + SHIZUKU_WAIT_TIMEOUT_MINUTES * 60))
    local remaining status counter=0

    while (( (remaining = deadline - SECONDS) > 0 )); do
        # Run asynchronously so INT/TERM can interrupt wait and trigger cleanup.
        # Each invocation is bounded by the remaining overall deadline.
        timeout --kill-after=1 "$remaining" "$RISH_PATH" -c true 9>&- >/dev/null 2>&1 &
        rish_pid=$!
        status=0
        wait "$rish_pid" || status=$?
        rish_pid=""

        if (( status == 0 )); then
            log_msg "Shizuku is ready."
            return 0
        fi
        if (( status == 126 || status == 127 )); then
            log_msg "FATAL: Cannot execute rish or timeout (exit code: $status)."
            return "$E_UNAVAILABLE"
        fi

        ((++counter))
        if (( counter == 1 || counter % LOG_THROTTLE_COUNT == 0 )); then
            log_msg "Shizuku not ready (exit code: $status); retrying..."
        fi
        remaining=$((deadline - SECONDS))
        (( remaining > 0 )) || break
        sleep "$((remaining < POLL_INTERVAL_SECONDS ? remaining : POLL_INTERVAL_SECONDS))"
    done

    log_msg "FATAL: Timed out waiting for Shizuku."
    return "$E_TIMEOUT"
}

launch_brevent() {
    log_msg "Starting Brevent (timeout: ${BREVENT_LAUNCH_TIMEOUT_SECONDS}s)..."
    timeout --kill-after=1 "$BREVENT_LAUNCH_TIMEOUT_SECONDS" \
        "$RISH_PATH" -c "/system/bin/sh \"$BREVENT_SCRIPT_PATH\"" \
        9>&- > "$tmp_output" 2>&1 &
    rish_pid=$!

    # rish's exit code does not reliably reflect the remote command's status.
    while kill -0 "$rish_pid" 2>/dev/null && ! grep -qi 'success' "$tmp_output"; do
        sleep "$POLL_INTERVAL_SECONDS"
    done
    # Check once more: the process may have written success immediately before exit.
    if grep -qi 'success' "$tmp_output"; then
        log_msg "Brevent launch successful."
        return 0
    fi

    log_msg "FATAL: Brevent exited or timed out without reporting success."
    tail -n "$MAX_LOG_LINES" "$tmp_output" >> "$LOG_FILE" || true
    return "$E_SOFTWARE"
}

# Bootstrap failures go to stderr; no log or instance lock is available yet.
require_commands mkdir flock
mkdir -p "$STATE_DIR" || exit "$E_SETUP_ERROR"

# Take the lock before touching logs or wake-lock state. A losing instance
# simply exits; it must not run the owner's cleanup or unlink the lock file.
exec 9> "$LOCK_FILE"
flock -n -E "$E_CONCURRENT" 9

if ! : >> "$LOG_FILE"; then
    printf 'Cannot write log: %s\n' "$LOG_FILE" >&2
    exit "$E_LOG_UNWRITABLE"
fi

# Check remaining dependencies before acquiring resources that need cleanup.
require_commands timeout grep mktemp tail mv rm sleep \
    termux-wake-lock termux-wake-unlock "$RISH_PATH" 2>> "$LOG_FILE"

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

log_msg "Startup lock acquired."
termux-wake-lock
wake_locked=1
tmp_output=$(mktemp "$STATE_DIR/.output.XXXXXX")

wait_for_shizuku
launch_brevent
