#!/system/bin/sh

# Shevery may replace the inherited environment with module-only variables.
# Recover only Android runtime variables from the same-identity parent chain.
brevent_runtime_ready() {
    [ -n "${ANDROID_ROOT:-}" ] &&
    [ -n "${ANDROID_DATA:-}" ] &&
    [ -n "${ANDROID_ART_ROOT:-}" ] &&
    [ -n "${ANDROID_I18N_ROOT:-}" ] &&
    [ -n "${ANDROID_TZDATA_ROOT:-}" ] &&
    [ -n "${BOOTCLASSPATH:-}" ]
}

brevent_parent_pid() {
    while read -r _brevent_key _brevent_value _brevent_rest; do
        if [ "$_brevent_key" = "PPid:" ]; then
            printf '%s\n' "$_brevent_value"
            return 0
        fi
    done < "/proc/$1/status" 2>/dev/null
    return 1
}

if ! brevent_runtime_ready; then
    _brevent_env_pid=$PPID
    _brevent_env_depth=0
    while [ "$_brevent_env_depth" -lt 16 ]; do
        case "$_brevent_env_pid" in
            ''|0|*[!0-9]*) break ;;
        esac

        if [ -r "/proc/$_brevent_env_pid/environ" ]; then
            {
                # Android's /system/bin/sh supports NUL-delimited read.
                # Keep this loop in the current shell so exports survive it.
                while IFS= read -r -d '' _brevent_env_entry; do
                    case "$_brevent_env_entry" in
                        PATH=*|ANDROID_ROOT=*|ANDROID_DATA=*|ANDROID_ART_ROOT=*|ANDROID_I18N_ROOT=*|ANDROID_TZDATA_ROOT=*|ANDROID_ASSETS=*|ANDROID_STORAGE=*|BOOTCLASSPATH=*|DEX2OATBOOTCLASSPATH=*)
                            export "$_brevent_env_entry"
                            ;;
                    esac
                done < "/proc/$_brevent_env_pid/environ"
            } 2>/dev/null
        fi

        if brevent_runtime_ready; then
            printf 'Auto Brevent Starter: restored Android runtime environment from parent PID %s\n' "$_brevent_env_pid"
            break
        fi

        _brevent_next_pid=$(brevent_parent_pid "$_brevent_env_pid") || break
        [ "$_brevent_next_pid" != "$_brevent_env_pid" ] || break
        _brevent_env_pid=$_brevent_next_pid
        _brevent_env_depth=$((_brevent_env_depth + 1))
    done
fi

if ! brevent_runtime_ready; then
    printf '%s\n' 'Auto Brevent Starter: cannot recover Android runtime environment from parent processes; Brevent was not started.' >&2
    exit 1
fi

output=$(pm path me.piebridge.brevent); export CLASSPATH=${output#*:}; app_process /system/bin me.piebridge.brevent.server.BreventServer bootstrap; /system/bin/sh /data/local/tmp/brevent.sh
