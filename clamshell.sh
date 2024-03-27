#!/usr/bin/env bash

# clamshelld starts a daemon that manages sleep behavior when the lid is closed.
clamshelld() { clamshell "$@" daemon; }

if test -n "${BASH_SOURCE[0]}"
then clamshell_source="${BASH_SOURCE[0]}"
else clamshell_source="$0"
fi
clamshell_source="$(realpath "$clamshell_source")"
clamshell_arg0="$0"

# shellcheck disable=SC2317,SC2207
# bash/zsh command completion
_clamshell() {
    local commands
    commands="$(clamshell help | grep '^    .*' | tr -s ' ' | cut -d' ' -f2 | sort -u)"
    COMPREPLY=($(compgen -W "$commands" -- "${COMP_WORDS[COMP_CWORD]}"))
}

# clamshell manages sleep behavior when the lid is closed.
# See `clamshell help` for more information.
clamshell() {(
# SUBSHELL START
# Run everything in a subshell to avoid polluting the environment.
# This also allows safe use of exec to replace the current shell with clamshelld

clamshell-help() { cat <<-EOF
Usage: clamshell [OPTION] [COMMAND]

The clamshell CLI helps you put your MacBook to sleep and keep it asleep when the lid is closed.
See 'clamshell docs' to learn why you need it and how it works.

Options:
    --debug  -d    Enable debug mode
    --help   -h    Display this help

Commands:
    sleep               sl       Enter sleep using 'pmset sleepnow' when in clamshell mode

Queries:
    help                h        Display this help
    check               c        Check if clamshell mode is active (returns 0 if yes)
    has-display         disp     Check if the external display is connected (returns 0 if yes)
    has-legacy-display  ldisp    Check if the legacy display is awake (returns 0 if yes)
    device-proxy        dp       Return the powerstate number of DCPDPDeviceProxy (should return 1 or 4)
    sleeping            sln      Check if the system is sleeping (returns 0 if yes)
    awake               aw       Check if the system is awake (returns 0 if yes)
    summary             sm       Display a summary of all checks
    manual              man      Explain what clamshell mode is and how it works

Daemon Commands:
    daemon     dm    Runs the sleep command every second (also see clamshelld)
    install    in    Install a launchd service to run clamshelld
    uninstall  un    Uninstall the launchd service
    status     st    Check the status of the launchd service
    load       ld    Start the launchd service (alias: start)
    unload     ul    Stop the launchd service (alias: stop)
    pid        id    Show the launchd service PID

Developer Commands:
    selftest    self    Run a selftest to check if all commands work as expected
    log         log     Tail the clamshelld log file
    binary      bin     Compile the clamshell script to a clamshelld binary
    assertions  asn     Show the pmset assertions that prevent sleep
    complete    co      Print the zsh completion function

EOF
}

# Launchd service variables
clamshelld_prefix="$HOME/Library/Clamshell/1.0.0"
clamshelld_bin="$clamshelld_prefix/bin/clamshelld"
clamshelld_service="com.github.ubunatic.clamshell.plist"
clamshelld_plist="$HOME/Library/LaunchAgents/$clamshelld_service"
clamshelld_log="$HOME/Library/Logs/clamshell.log"
clamshell_md="$clamshelld_prefix/share/clamshell.md"

# main function to parse flags and run commands
clamshell-main() {
    # parse flags

    if test $# -eq 0
    then clamshell-help; return 0
    fi

    # run one-time commands
    local flag
    for flag in "$@"
    do case "$flag" in
        -d|--debug)    export CLAMSHELL_DEBUG=1 ;;
        -h|--help|h*)  clamshell-help; return 0 ;;
        man*|doc*)     (clamshell-help; clamshell-manual) | less; return 0 ;;
        -*)            echo "Unknown option: $1"; return 1 ;;
    esac
    done

    # run chained commands sequentially
    local cmd
    for cmd in "$@"
    do case "$cmd" in
        -*)            ;;  # ignore flags (parsed above)
        y*|c|ch*)      clamshell-yes ;;
        n|no*)         clamshell-no ;;
        di*|has-d*)    clamshell-has-display ;;
        ldi*|has-l*)   clamshell-has-legacy ;;
        dp|de*)        clamshell-proxy-num ;;
        sleepi*|sln*)  clamshell-sleeping ;;
        sl*)           clamshell-sleep ;;
        aw*)           clamshell-awake ;;
        su*)           clamshell-summary ;;
        da*)           exec -a clamshelld clamshell-daemon | tee -i -a "$clamshelld_log" ;;
        bin*|compi*)   clamshell-binary ;;
        co*)           clamshell-complete ;;
        in*)           clamshell-install ;;
        un|uni*)       clamshell-uninstall ;;
        st|stat*)      clamshell-status ;;
        pid*|id*)      clamshell-pid ;;
        log*)          clamshell-log ;;
        as*)           clamshell-assertions ;;
        ld|lo*|start*) clamshell-ctl load ;;
        ul|unl*|stop*) clamshell-ctl unload ;;
        self*)         clamshell-selftest ;;
        sourced*)      clamshell-sourced ;;
        *)             echo "Unknown command: $1"; return 1 ;;
    esac
    done
}

# clamshell-daemon runs a loop to detect clamshell mode and initiate sleep
# shellcheck disable=SC2317
clamshell-daemon() {
    logger "Starting clamshell daemon"
    trap "logger 'Clamshell daemon stopped'; exit 0" INT TERM

    local t0
    local n=0
    local elapsed=0
    local sleeping_since=0
    local awake_since=0
    local sleeping_for=0
    local awake_for=0

    t0="$(date +%s)"
    while sleep 1; do
        # Log Rotation
        # ============
        (( n++ ))
        (( elapsed = $(date +%s) - t0 ))
        if (( elapsed > 86400 )); then
            t0="$(date +%s)"
            logger "clamshell daemon running for 24h, saving log as $clamshelld_log.old"
            cp -f "$clamshelld_log" "$clamshelld_log.old"
            echo -n > "$clamshelld_log"
            logger "log rotated after 24h, see $clamshelld_log.old for previous log"
        fi

        # Keep Sleeping
        # =============
        if clamshell-sleeping; then
            (( sleeping_for = $(date +%s) - sleeping_since ))
            if (( n % 600 == 0 )); then
                # log every 10 minutes
                logger "system has been sleeping for ${sleeping_for}s"
            fi
            sleep 10
            continue
        fi

        # Try to Sleep
        # ============
        if clamshell-sleep; then
            sleeping_since="$(date +%s)"
            awake_since=0
            logger "system sleep initated, waiting 5s to reach sleep state"
            sleep 5
            continue
        fi

        # Awaking
        # =======
        if (( awake_since == 0 )); then
            awake_since="$(date +%s)"
            logger "clamshell became awake"
            continue
        fi

        # Stay Awake
        # ==========
        (( awake_for = $(date +%s) - awake_since ))
        if (( n % 600 == 0 )); then
            # log every 10 minutes
            logger "system has been awake for ${awake_for}s"
            continue
        fi
    done
}

clamshell-binary() {
    mkdir -p "$clamshelld_prefix/bin"
    echo "Compacting clamshell script to clamshelld binary in prefix $clamshelld_prefix"
    (
        echo "#!/usr/bin/env zsh" &&
        which clamshell &&
        echo 'clamshell daemon'
    ) > "$clamshelld_bin" &&
    chmod +x "$clamshelld_bin" &&
    echo "clamshelld binary created at $clamshelld_bin"
}

# -------------------------------------------------------------------------------------------------
# Development Notes: How to convince powerd to sleep better?
# -------------------------------------------------------------------------------------------------
# Also see 'man pmset' for more details.
#
# Testing pmset changes:
# sudo pmset -a tcpkeepalive 0   # changes setting, shows a warning
# sudo pmset -a ttyskeepawake 0  # changes setting
# sudo pmset -a acwake 0         # has no effect
# sudo pmset -a sleep 1          # does not change the exclusions for powerd  and bluetoothd
# sudo pmset -a ring 0           # has no effect
# -------------------------------------------------------------------------------------------------
# pmset -g before:                                                   # pmset -g after:
#  System-wide power settings:                                       #  System-wide power settings:
#   SleepDisabled          0                                         #   SleepDisabled          0
#   DestroyFVKeyOnStandby  1                                         #   DestroyFVKeyOnStandby  1
#  Currently in use:                                                 #  Currently in use:
#   standby               1                                          #   standby               1
#   Sleep On Power Button 1                                          #   Sleep On Power Button 1
#   hibernatefile        /var/vm/sleepimage                          #   hibernatefile        /var/vm/sleepimage
#   powernap             1                                           #   powernap             1
#   networkoversleep     0                                           #   networkoversleep     0
#   disksleep            10                                          #   disksleep            10
#   sleep                1 (sleep prevented by powerd, bluetoothd)   #   sleep                1 (sleep prevented by powerd, bluetoothd)
#   hibernatemode        3                                           #   hibernatemode        3
#   ttyskeepawake        1                                           #   ttyskeepawake        0
#   displaysleep         90                                          #   displaysleep         90
#   tcpkeepalive         1                                           #   tcpkeepalive         0
#   lowpowermode         0                                           #   lowpowermode         0
#   womp                 0                                           #   womp                 0
# -------------------------------------------------------------------------------------------------

clamshell-manual() {
    local here
    here="$(dirname "$0")"
    for f in "$clamshell_md" "$DOTFILES/shell/clamshell.md" "$here/clamshell.md" "$here/README.md"; do
        test -e "$f" && cat "$f" && return 0
    done
}

clamshell-complete()    { echo "complete -F _clamshell clamshell"; }
clamshell-log()         { tail -F "$clamshelld_log"; }
clamshell-yes()         { ioreg -r -k AppleClamshellState | grep AppleClamshellState | grep -q "Yes"; }
clamshell-no()          { ! clamshell-yes; }
clamshell-sleeping()    { pmset -g assertions | grep -qE '^\s*PreventUserIdleSystemSleep\s*0'; }
clamshell-awake()       { pmset -g assertions | grep -qE '^\s*PreventUserIdleSystemSleep\s*1'; }
clamshell-assertions()  { pmset -g assertions | grep -E  'PreventUserIdleSystemSleep'; }
clamshell-proxy-num()   { pmset -g powerstate | grep -cE 'DCPDPDeviceProxy'; }
clamshell-has-display() { test "$(clamshell-proxy-num)" -lt 4; }
clamshell-has-legacy() {
    pmset -g powerstate | grep AppleDisplay      | grep -q USEABLE &&
    pmset -g powerstate | grep IODisplayWrangler | grep -q USEABLE
}

# clamshell-summary displays a summary of all checks
clamshell-summary() {
    echo "ARCH: $(uname -m)"
    echo "clamshell-yes:         $(clamshell-yes         && echo Yes || echo No)"
    echo "clamshell-has-display: $(clamshell-has-display && echo Yes || echo No)"
    echo "clamshell-has-legacy:  $(clamshell-has-legacy  && echo Yes || echo No)"
    echo "clamshell-sleeping:    $(clamshell-sleeping    && echo Yes || echo No)"
    echo "clamshell-pid:         $(clamshell-pid || echo No)"
    echo "clamshell-proxy-num:   $(clamshell-proxy-num)"
    echo "clamshell-sleep:       $(CLAMSHELL_DEBUG=1 clamshell-sleep)"
}

logger-n()     { echo -n -e "\r$(date '+%Y-%m-%d %H:%M:%S'): $*, output="; }  # log without newline
logger()       { echo    -e "\r$(date '+%Y-%m-%d %H:%M:%S'): $*"; }           # log with newline

# shellcheck disable=SC2317
echo-pmset() { echo "/usr/bin/pmset $*"; }

# clamshell-sleep initiates sleep if clamshell mode is active and returns 0 on success.
# It does not wait for sleep to complete or for clamshell mode to change. Use clamshell-daemon for that.
clamshell-sleep() {
    local pmset code
    if test -n "$CLAMSHELL_DEBUG"
    then pmset="echo-pmset"
    else pmset="/usr/bin/pmset"
    fi

    if clamshell-yes; then
        code=0
        if clamshell-has-display; then
            logger-n "clamshell detected, display found, initating sleep cmd=$pmset arg=sleepnow"
            $pmset sleepnow
            code=$?
        elif clamshell-has-legacy; then
            logger-n "clamshell detected, legacy display found, initating sleep cmd=$pmset arg=sleepnow"
            $pmset sleepnow
            code=$?
        elif test -n "$CLAMSHELL_DEBUG"; then
            # echo a noop command to stdout as sleep command output for testing
            echo noop "(lid open or display asleep)"
        fi

        if test $code -gt 0; then
            logger "Failed to sleep, $pmset sleepnow exited with code=$code"
        fi
        return $code

    elif test -n "$CLAMSHELL_DEBUG"; then
        echo noop "(no clamshell)"
    fi
    return 1
}

# clamshell-install installs a Launchd service to run clamshelld in the background.
clamshell-install() {
    local svc="$clamshelld_service" dst="$clamshelld_plist" md="$clamshell_md"

    if ! clamshell-binary
    then echo "Failed to create clamshelld binary"; return 1
    fi

    # request permission to create the launchd service
    if touch "$dst" 2> /dev/null; then
        echo "Created empty plist file $dst"
    else
        echo "Requesting permission to create launchd service $svc at $dst"
        if sudo touch "$dst" && sudo chown "$USER" "$dst"
        then echo "Created empty plist file $dst"
        else echo "Failed to create empty plist file $dst"; return 1
        fi
    fi

    mkdir -p "$clamshelld_prefix/share"
    local manual
    manual="$(clamshell-manual)"
    if echo "$manual" > "$md"
    then echo "Saved manual to $md"
    else echo "Failed to save manual to $md"
    fi

    # create a launchd plist file
    cat > "$dst" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$svc</string>
    <key>ProgramArguments</key>
    <array>
        <string>$clamshelld_bin</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF
    local code=$?
    if test "$code" -gt 0; then
        echo "Failed to install launchd service $svc at $dst err=$code"
        return 1
    fi

    echo "Launchd service $svc installed at $dst with binary '$clamshelld_bin'"
    echo "Stopping clamshelld instances and reloading clamshelld service"
    if pkill clamshelld 2> /dev/null
    then echo "clamshelld process stopped"
    else echo "no clamshelld instances running"
    fi
    local pid
    pid="$(clamshell-pid)"
    if test -n "$pid"
    then
        echo "stopping exiting service (PID=$pid)"
        clamshell-ctl unload || echo "Failed to unload clamshelld service"
    fi
    clamshell-ctl load
}

# clamshell-uninstall removes the Launchd service that runs clamshelld in the background.
clamshell-uninstall() {
    local svc="$clamshelld_service" dst="$clamshelld_plist"

    if test -e "$dst"; then
        clamshell-ctl unload
        rm -f "$dst" 2> /dev/null || sudo rm -f "$dst" 2> /dev/null
        echo "Launchd service $svc uninstalled from $dst"
    else
        echo "Launchd service $svc not installed from $dst"
    fi
}

clamshell-pid() {
    launchctl list "$clamshelld_service" 2>/dev/null | grep -E '"PID"' | grep -oE '\d+'
}

# clamshell-ctl runs a launchctl command (load|unload) with the Launchd plist file
clamshell-ctl() {
    local code=1 svc="$clamshelld_service" dst="$clamshelld_plist"
    if test -e "$dst"
    then
        launchctl "$1" -w "$dst"; code=$?
        if test "$code" -eq 0
        then echo "Launchd service $1: OK"
        else echo "Launchd service $1: FAILED"
        fi
    else
        echo "Launchd service $svc not installed"
    fi
    return $code
}

clamshell-status() {
    local code svc="$clamshelld_service" dst="$clamshelld_plist"
    printf "\nLaunchd Status:\n";      launchctl list "$svc" 2>/dev/null; code=$?
    printf "\nLogfile:\n";             tail -n 10 "$clamshelld_log"
    printf "\nLaunchd PList File:\n";  test -e "$dst" && echo "found at $dst" || echo "not found at $dst"
    printf "\nPgrep clamshelld:\n";    pgrep clamshelld || echo "no clamshelld process found (try sudo pgrep)"
    printf "\nLaunchd Status Code: %s\n" $code
    return $code
}

# shellcheck disable=SC2317
clamshell-selftest() {(
    exec 2>&1  # redirect stderr to stdout for error checking

    local err=""
    err()       { err="$err\n$*"; }
    noerr()     { wc -l | grep -qE '^\s*0' || err "$@"; }
    nobasherr() { grep -E '^(bash:|clamshell*:)' && err "$@"; }

    clamshell-yes || clamshell-no  || err "clamshell yes/no failed"
    clamshell-complete  >/dev/null || err "clamshell complete failed"
    clamshell-proxy-num >/dev/null || err "clamshell proxy-num failed"
    clamshell-awake                || err "clamshell awake failed"
    ! clamshell-sleeping           || err "clamshell sleeping failed"
    # commands without output should not show any errors
    # do not run these tests in clamshell mode
    clamshell-has-display | noerr "clamshell has-display failed"
    clamshell-has-legacy  | noerr "clamshell has-legacy failed"
    clamshell-sleep       | noerr "clamshell sleep failed"
    clamshell-pid         | noerr "clamshell pid failed"
    # commands with output should not show any bash errors
    clamshell-summary          | nobasherr "clamshell summary failed"
    clamshell-help             | nobasherr "clamshell help failed"
    clamshell-manual           | nobasherr "clamshell help failed"
    clamshell-status           | nobasherr "clamshell status failed"
    clamshell-ctl load         | nobasherr "clamshell ctl load failed"
    clamshell-ctl unload       | nobasherr "clamshell ctl unload failed"

    bash -itc "source $clamshell_source; clamshell sourced" || err "$clamshell_source: bash sourced check failed"
    bash -itc "! $clamshell_source sourced"                 || err "$clamshell_source: bash executed check failed"
    zsh  -itc "source $clamshell_source; clamshell sourced" || err "$clamshell_source: zsh sourced check failed"
    zsh  -itc "! $clamshell_source sourced"                 || err "$clamshell_source: zsh executed check failed"

    if test -z "$err"
    then echo "clamshell selftest: OK"
    else echo -e "$err"; echo "clamshell selftest: FAILED"
    fi
)}

clamshell-sourced() {
    # DEBUG: uncomment to see the source of the script
    # echo "0: $0, ARG0: $clamshell_arg0, SRC: $clamshell_source"
    # echo "0: $(basename "$0"), BASE0: $(basename "$clamshell_arg0"), BASE: $(basename "$clamshell_source")"
    # echo "BASH_SOURCE: ${BASH_SOURCE[*]}"
    # echo "ZSH_EVAL_CONTEXT: $ZSH_EVAL_CONTEXT"

    { test -n "$ZSH_VERSION" && test -n "$ZSH_EVAL_CONTEXT"; } ||
    { test -n "$BASH_VERSION" && test "$(basename "$clamshell_arg0")" != "$(basename "$clamshell_source")"; }
}

clamshell-main "$@"

# SUBSHHELL END
)}

# check if clamshell is sourced on bash or zsh on MacOS
if clamshell sourced >/dev/null
then test "$(uname -s)" = "Darwin" && eval "$(clamshell complete)"
else clamshell "$@"
fi
