#!/data/data/com.termux/files/usr/bin/bash

# =============================================================================
#
# auto_brevent.sh
#
# A Termux:Boot script designed to reliably start the Brevent service via
# Shizuku after a device boot.
# It waits for Shizuku to become available
# and then executes the Brevent server start script.
#
# Features:
# - Ensures only one instance runs at a time using flock.
# - Waits for Shizuku to be ready before attempting to launch Brevent.
# - Manages a self-rotating log file for diagnostics.
# - Uses Termux Wake Lock to prevent the system from sleeping during startup.
# - Robust cleanup of child processes and temporary files on exit.
#
# =============================================================================

# Halt script on any error, undefined variable, or pipe failure.
set -euo pipefail

### ----------------------------------------------------------------
### GLOBAL CONFIGURATION & CONSTANTS
### ----------------------------------------------------------------

# --- Directory & File Paths ---
readonly STATE_DIR="$HOME/.local/state/auto_brevent"
readonly LOG_FILE="$STATE_DIR/script.log"
readonly LOCK_FILE="$STATE_DIR/script.lock"

# Path to the Shizuku remote shell executable.
readonly RISH_PATH="$HOME/.local/bin/rish"
# Path to the Brevent server script to be executed via rish.
readonly BREVENT_SCRIPT_PATH="/data/local/tmp/brevent.sh"

# --- Behavior Tuning ---
readonly MAX_LOG_LINES=200
readonly POLL_INTERVAL_SECONDS=2 # General polling frequency.
readonly SHIZUKU_WAIT_TIMEOUT_MINUTES=5 # Max time to wait for Shizuku.
readonly BREVENT_LAUNCH_TIMEOUT_SECONDS=60 # Max time to wait for Brevent to start.
# Number of wait cycles before logging a "still waiting" message.
readonly LOG_THROTTLE_COUNT=15

# File descriptor to use for flock. Must be > 2.
LOCK_FD=200

# --- Exit Codes ---
readonly E_UNAVAILABLE=69 # Dependency not found.
readonly E_TIMEOUT=78 # Operation timed out.
readonly E_SOFTWARE=70 # Internal software error (e.g., Brevent script failed).
readonly E_SETUP_ERROR=73 # Cannot create required files/dirs for startup.
readonly E_CONCURRENT=99 # Another instance is already running.
readonly E_LOG_UNWRITABLE=100 # Log file cannot be written to.

### ----------------------------------------------------------------
### UTILITY FUNCTIONS
### ----------------------------------------------------------------

##
# Logs a timestamped message to the script's log file.
# @param1 Message string to log.
##
log_msg() {
    local timestamp
    # Use LC_ALL=C to ensure a consistent, locale-independent timestamp format.
    timestamp=$(LC_ALL=C date '+%Y-%m-%d %H:%M:%S') ||
        timestamp="<date_failed>"
    
    # The '|| true' ensures the script won't exit if 'printf' or
    # redirection fails (e.g., disk full).
    printf '%s - %s\n' "$timestamp" "$1" >> "$LOG_FILE" ||
        true
}


##
# Trims the log file to MAX_LOG_LINES to prevent infinite growth.
# Uses an atomic move for safety.
##
rotate_log() {
    # Do nothing if the log file is empty.
    if [[ ! -s "$LOG_FILE" ]];
    then
        return 0
    fi

    local tmp_log
    tmp_log=$(mktemp)

    # Atomically replace the old log with the tailed new one.
    if tail -n "$MAX_LOG_LINES" "$LOG_FILE" > "$tmp_log" && \
       mv "$tmp_log" "$LOG_FILE";
    then
        : # Success
    else
        log_msg "WARNING: Log rotation failed. Check permissions."
        rm -f "$tmp_log"
        return 1
    fi
}

### ----------------------------------------------------------------
### CORE LOGIC FUNCTIONS
### ----------------------------------------------------------------

##
# Verifies that all required external commands and files are available.
#
# @return 0 on success, E_UNAVAILABLE otherwise.
##
check_dependencies() {
    log_msg "Checking dependencies..."
    
    local commands=(
        "flock"
        "termux-wake-lock"
        "termux-wake-unlock"
        "mktemp"
        "grep"
        "pkill"
        "tail"
        "mv"
        "sed"
        "date"
        "rm"
        "mkdir"
        "touch"
        "sleep"
    )

    for cmd in "${commands[@]}";
    do
        if ! command -v "$cmd" &>/dev/null;
        then
            log_msg "FATAL: Required command '$cmd' not found in PATH."
            return "$E_UNAVAILABLE"
        fi
    done

    if [[ ! -x "$RISH_PATH" ]]; then
        log_msg "FATAL: rish executable '$RISH_PATH' not found or not executable."
        return "$E_UNAVAILABLE"
    fi

    if [[ ! -r "$BREVENT_SCRIPT_PATH" ]];
    then
        log_msg "FATAL: Brevent script '$BREVENT_SCRIPT_PATH' not found or not readable."
        return "$E_UNAVAILABLE"
    fi

    log_msg "All dependencies satisfied."
    return 0
}

##
# Stage 1: Waits for the Shizuku service to become responsive.
# Polls by executing a simple 'true' command via rish.
#
# @return 0 if Shizuku is ready, E_TIMEOUT if timeout is reached.
##
wait_for_shizuku() {
    log_msg "Stage 1: Waiting for Shizuku (Timeout: ${SHIZUKU_WAIT_TIMEOUT_MINUTES}m)..."

    local end_time=$(( $(date +%s) + (SHIZUKU_WAIT_TIMEOUT_MINUTES * 60) ))
    local wait_counter=0
    local rish_status=0

    # Perform an initial check.
    "$RISH_PATH" -c true >/dev/null 2>&1 || rish_status=$?

    if [[ "$rish_status" -eq 0 ]]; then
        log_msg "Shizuku is ready. Proceeding to Stage 2."
        return 0
    fi

    # If not ready, log the initial failure and start polling.
    local throttle_interval_s=$((LOG_THROTTLE_COUNT * POLL_INTERVAL_SECONDS))
    log_msg "Shizuku not ready (code: ${rish_status}). Retrying... (Logs will update every ${throttle_interval_s}s)"

    while [[ $(date +%s) -lt $end_time ]]; do
        sleep "$POLL_INTERVAL_SECONDS"

        if "$RISH_PATH" -c true >/dev/null 2>&1; then
            log_msg "Shizuku is ready. Proceeding to Stage 2."
            return 0
        fi

        # Throttle "still waiting" messages to avoid log spam.
        ((wait_counter++)) || true
        if (( wait_counter % LOG_THROTTLE_COUNT == 0 )); then
            log_msg "Still waiting for Shizuku..."
        fi
    done

    log_msg "FATAL: Timed out waiting for Shizuku after ${SHIZUKU_WAIT_TIMEOUT_MINUTES} minutes."
    return "$E_TIMEOUT"
}


##
# Stage 2: Executes the Brevent start script via rish.
# Monitors the script's output for a "success" string.
#
# @return 0 on success, E_SOFTWARE on failure or timeout.
##
launch_brevent() {
    log_msg "Stage 2: Executing Brevent start command..."

    # Execute rish in the background, redirecting its output to a temp file.
    # {LOCK_FD}>&- : Critically, this closes our flock file descriptor
    # for the child process, so it doesn't inherit the lock.
    "$RISH_PATH" -c "/system/bin/sh \"$BREVENT_SCRIPT_PATH\"" >"$tmp_output" 2>&1 {LOCK_FD}>&- &
    rish_pid=$!
    disown "$rish_pid" # Detach from terminal, hide job messages.
    log_msg "Brevent command sent (PID: $rish_pid). Polling for success (Timeout: ${BREVENT_LAUNCH_TIMEOUT_SECONDS}s)..."

    local launch_end_time=$(( $(date +%s) + BREVENT_LAUNCH_TIMEOUT_SECONDS ))

    # Poll the temp output file for the "success" string.
    while [[ $(date +%s) -lt $launch_end_time ]]; do
        if grep -q -i "success" "$tmp_output";
        then
            log_msg "Brevent launch successful (found 'success' in output)."
            return 0
        fi
        sleep "$POLL_INTERVAL_SECONDS"
    done

    # Loop finished, which means we timed out without seeing "success".
    log_msg "FATAL: Brevent command did not report success within ${BREVENT_LAUNCH_TIMEOUT_SECONDS} seconds."
    log_msg "--- Last Captured Output ---"

    # Dump the contents of the output file to the log for debugging.
    # Use 'sed' to indent the output for readability.
    sed 's/^/  /' "$tmp_output" >> "$LOG_FILE" ||
        true

    log_msg "--- End Output ---"
    return "$E_SOFTWARE"
}


##
# Main coordinator function.
# Executes the startup sequence in stages.
##
main() {
    # Stage 1: Wait for Shizuku.
    # 'set -e' will cause the script to exit if wait_for_shizuku
    # returns a non-zero exit code (i.e., timeout).
    wait_for_shizuku

    # Stage 2: Launch Brevent.
    # 'set -e' will also handle failures here.
    launch_brevent
}


### ----------------------------------------------------------------
### SCRIPT ENTRYPOINT & CLEANUP
### ----------------------------------------------------------------

##
# Global cleanup handler, triggered by TRAP on EXIT, INT, TERM.
# This function is responsible for releasing all resources.
##
script_cleanup() {
    # Capture the script's exit code or the signal number that caused termination.
    local exit_code="$?"
    # Disable all traps to prevent recursion.
    trap - EXIT INT TERM

    # --- 1. Clean up child processes and temp files ---
    # These variables are set in the main subshell block.
    if [[ -n "${rish_pid:-}" && "$rish_pid" -gt 0 ]]; then
        log_msg "Cleaning up background process (PID: $rish_pid)..."
        # Politely ask all children of rish to terminate.
        pkill -P "$rish_pid" 2>/dev/null || true
        # Forcefully kill the main rish process.
        kill -9 "$rish_pid" 2>/dev/null || true
        log_msg "Cleanup commands sent."
    fi

    if [[ -n "${tmp_output:-}" && -f "${tmp_output}" ]];
    then
        rm -f "$tmp_output"
    fi

    # --- 2. Release system resources ---
    termux-wake-unlock
    log_msg "Termux wake lock released."

    # --- 3. Log final status based on the actual exit code ---
    if [[ "$exit_code" -eq "$E_CONCURRENT" ]]; then
        log_msg "Instance already running. Exiting."
    elif [[ "$exit_code" -eq 0 ]]; then
        log_msg "Script finished successfully."
    else
        log_msg "Script exited with error code: ${exit_code}"
    fi
    log_msg "-------------------"

    # Finally, exit the script with the original code.
    exit "$exit_code"
}

# --- Script Execution Starts Here ---

# 1. Ensure state directory exists.
if ! mkdir -p "$STATE_DIR";
then
    # Cannot use log_msg here, as state dir might be the problem.
    printf '%s - FATAL: Cannot create state directory "%s".\n' \
        "$(LC_ALL=C date '+%Y-%m-%d %H:%M:%S')" "$STATE_DIR" >&2
    exit "$E_SETUP_ERROR"
fi

# 2. Check if log file is writable (Fail Fast).
if ! (touch "$LOG_FILE" && [[ -w "$LOG_FILE" ]]); then
    printf '%s - FATAL: Log file "%s" is not writable.\n' \
        "$(LC_ALL=C date '+%Y-%m-%d %H:%M:%S')" "$LOG_FILE" >&2
    exit "$E_LOG_UNWRITABLE"
fi

# 3. Check dependencies (Fail Fast, *before* getting lock).
# The function logs its own errors, and 'set -e' will handle exit on failure.
check_dependencies


# 4. Acquire instance lock via subshell.
# The entire rest of the script runs inside this subshell,
# which holds an exclusive lock on LOCK_FILE.
(
    # Variables that the trap handler needs to access.
    declare tmp_output=""
    declare -i rish_pid=0

    # Set the single point of exit.
    trap script_cleanup EXIT INT TERM

    # Try to acquire a non-blocking lock. If it fails, flock exits with
    # E_CONCURRENT. 'set -e' catches this and triggers the trap immediately.
    flock -n -E "$E_CONCURRENT" "$LOCK_FD"

    # --- Lock Acquired, Main Execution Begins ---

    rotate_log
    log_msg "Lock acquired. Script starting."

    termux-wake-lock
    log_msg "Termux wake lock acquired."

    # Create the temp file for rish output.
    tmp_output=$(mktemp)

    # Run the main logic. Its final exit code will be passed to the 'exit'
    # command at the end of the subshell, triggering the trap.
    main
    
) {LOCK_FD}>"$LOCK_FILE" # Redirect the subshell's FD 200 to the lock file.

