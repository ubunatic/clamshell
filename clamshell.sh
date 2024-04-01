#!/usr/bin/env bash
#
#   Copyright 2024 Uwe Jugel (@ubunatic)
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
#   The source code is hosted at https://github.com/ubunatic/clamshell.
#   Please report issues and suggestions at https://github.com/ubunatic/clamshell/issues.
#

clamshell-help() { cat <<-EOF
Usage: clamshell [OPTION] [COMMAND]

The clamshell CLI helps putting your MacBook to sleep and keeping it asleep when the lid is closed.
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
    docs                doc      Explain what clamshell mode is and how it works
    log                 log      Tail the clamshelld log file
    version             v        Show the current clamshell version

Daemon Commands:
    daemon     dm    Runs the sleep command every second
    install    in    Install a launchd service to run clamshelld
    uninstall  un    Uninstall the launchd service
    status     st    Check the status of the launchd service
    load       ld    Start the launchd service (alias: start)
    unload     ul    Stop the launchd service (alias: stop)
    pid        id    Show the launchd service PID
    kill       k     Kill all clamshell processes

EOF

    if test -n "$CLAMSHELL_DEBUG"
    then cat <<-EOF
Developer Commands:
    selftest    self    Run a selftest to check if all commands work as expected
    binary      bin     Compile the clamshell script to a clamshelld binary
    assertions  asn     Show the pmset assertions that prevent sleep
    complete    co      Print the zsh completion function
    source      src     Print the source of the script
    vars        va      Print clamshell variables

EOF
    fi
}

CLAMSHELL_DEBUG="${CLAMSHELL_DEBUG:-}"

# Installation Paths
# v1.x.x share the same prefix, we do not want to have multiple versions installed
clamshelld_prefix="$HOME/Library/Clamshell/v1"
clamshelld_bin="$clamshelld_prefix/bin/clamshelld"

# Launchd Service Configuration
clamshelld_service="com.github.ubunatic.clamshell.clamshelld.plist"
clamshelld_plist="$HOME/Library/LaunchAgents/$clamshelld_service"
clamshelld_log="$HOME/Library/Logs/clamshelld.log"

# Runtime Variables
clamshell_version="v1.0.0"
clamshell_source="$(realpath "$0")"
clamshell_path="$(dirname "$0")"
clamshell_share="$(dirname "$clamshell_path")/share/clamshell/clamshell.md"

second_ns=1000000000

clamshell-vars() {
    echo "clamshelld_service: $clamshelld_service"
    echo "clamshelld_prefix:  $clamshelld_prefix  ($( exists "$clamshelld_prefix" ))"
    echo "clamshelld_bin:     $clamshelld_bin  ($(    exists "$clamshelld_bin"    ))"
    echo "clamshelld_plist:   $clamshelld_plist  ($(  exists "$clamshelld_plist"  ))"
    echo "clamshelld_log:     $clamshelld_log  ($(    exists "$clamshelld_log"    ))"
    echo
    echo "clamshell_path:     $clamshell_path  ($(    exists "$clamshell_path"    ))"
    echo "clamshell_share:    $clamshell_share  ($(   exists "$clamshell_share"   ))"
}


# Clamshell Daemon
# ================
# This is the main function that runs in the background as a Launchd service.
# Make sure any changes to this function are well tested.
# Do not use `echo` and use `logger` only in a non-noisy way.
# Make sure not to create a busy loop and give the system enough time to sleep.

# clamshell-daemon continuously checks the clamshell state
# and puts the system to sleep when the clamshell mode is active.
clamshell-daemon() {
    logger "starting clamshell daemon"
    trap "logger 'clamshell daemon stopped'; exit 0" INT TERM

    local t0
    local n=0
    local elapsed=0
    local sleeping_since=0
    local awake_since=0
    local sleeping_for=0
    local awake_for=0
    local idle_seconds=0
    local last_exit=0

    t0="$(date +%s)"
    while sleep 1; do
        (( n++ ))

        # Log Rotation
        # ============
        # Update elapsed time (once per minute), and rotate log every 24h.
        if (( n % 60 == 0 ))
        then (( elapsed = $(date +%s) - t0 ))
        elif (( elapsed > 86400 )); then
            clamshell-log-rotate
            t0="$(date +%s)"
            elapsed=0
        fi

        # Sleep Check
        # ===========
        # If the system is sleeping, no action is taken.
        if clamshell-sleeping
        then
            awake_since=0
            if (( sleeping_since == 0 ))
            then
                sleeping_since="$(date +%s)"
                logger "system entered sleep mode"
            elif (( n % 600 == 0 ))
            then
                (( sleeping_for = $(date +%s) - sleeping_since ))
                logger "system has been sleeping for ${sleeping_for}s"
            fi
            # stop here and wait for the system to wake up
            continue
        fi

        # Awake Log
        # =========
        sleeping_since=0
        if (( awake_since == 0 ))
        then
            awake_since="$(date +%s)"
            logger "system became awake"
        elif (( n % 600 == 0 ))
        then
            (( awake_for = $(date +%s) - awake_since ))
            logger "system has been awake for ${awake_for}s"
        fi

        # Clamshell Check
        # ===============
        if clamshell-yes
        then logger "clamshell mode detected, checking idle time"
        else continue
        fi

        # Circut Breaker 1
        # ================
        # A misconfigured loop calling `clamshell-sleep` can be dangerous. If Apple changes the
        # behavior of MacOS, this could put the system to sleep permanently. To prevent this,
        # clamshell-daemon does an additional idle check, looking at HIDIdleTime in ioreg.
        #
        # .------------------------------------------------------.
        # |  As a circut breaker for keeping the system awake,   |
        # |  move the mouse or press keyboard keys continuously. |
        # '------------------------------------------------------'
        #
        (( idle_seconds = $(clamshell-idle-ns) / second_ns ))
        if test -z "$idle_seconds"
        then logger "failed to get idle time, not initiating sleep, stopping daemon"
             return 1
        elif (( idle_seconds < 3 ))
        then
            logger "system is idle for less than 3s (${idle_seconds}s), waiting for idle"
            continue
        else logger "system is idle for ${idle_seconds}s and in clamshell mode, initiating sleep"
        fi

        # Try to Sleep
        # ============
        # This will put the system to sleep if clamshell mode is active.
        # As a circut breaker for the breaking a misconfgured system,
        # the sleep command is only run every 15 seconds.
        # This will allow the user to open the lid and stop the daemon.
        if clamshell-sleep; then
            last_exit=$?
            sleeping_since="$(date +%s)"
            awake_since=0
            logger "system sleep initated successfully"
        else
            last_exit=$?
            logger "failed to initiate sleep (last_exit=$last_exit), waiting for next sleep attempt"
        fi

        # CircleBreaker 2
        # ===============
        # Indepent of the result of an attempted sleep, the daemon will wait for 30 seconds.
        # This will allow the user to open the lid or activate the system to stop the daemon.
        logger "waiting 30s after sleep attempt, run 'clamshell unload' to stop daemon"
        sleep 30
    done
}

# Utility Functions
# =================

logger-n()   { echo -n -e "\r$(date '+%Y-%m-%d %H:%M:%S'): $*, output="; }  # log without newline
logger()     { echo    -e "\r$(date '+%Y-%m-%d %H:%M:%S'): $*"; }           # log with newline
echo-pmset() { echo "/usr/bin/pmset $*"; }                                  # debug pmset command
sudo-mkdir() { sudo mkdir -p "$1"   && sudo chmod 755 "$1"; }               # sudo mkdir with permissions
sudo-cp()    { sudo cp -f "$1" "$2" && sudo chmod 755 "$2"; }               # sudo cp with permissions
sudo-rm()    { rm -f "$@" 2> /dev/null || sudo rm -f "$@" 2> /dev/null; }   # rm with sudo fallback
exists()     { test -e "$1" && echo "exists" || echo "not found"; }       # print file status

# shellcheck disable=SC2317,SC2207
# bash/zsh command completion
_clamshell() {
    local commands
    commands="$(clamshell help | grep '^    .*' | tr -s ' ' | cut -d' ' -f2 | sort -u)"
    COMPREPLY=($(compgen -W "$commands" -- "${COMP_WORDS[COMP_CWORD]}"))
}


# Wrapped MacOS Commands
# ======================

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

# clamshell-idle returns the idle time in nanoseconds of the system.
# In case of an error, it returns 1 to prevent sleep.
clamshell-idle-ns() { ioreg -c IOHIDSystem | grep "HIDIdleTime" | grep -oE "\d+" || echo 1; }

# clamshell-idle-check prints the idle time in milliseconds every second.
clamshell-idle-check() {
    while ns="$(clamshell-idle-ns)"; do
        (( s = ns / 1000000 ))
        echo "${s}ms"
        sleep 1
    done
}

# Clamshell Commands
# ==================

clamshell-complete() { declare -f _clamshell; echo "complete -F _clamshell clamshell"; }
clamshell-log()      { tail -F "$clamshelld_log"; }
clamshell-log-rotate() {
    logger "clamshell daemon running for 24h, saving log as $clamshelld_log.old"
    cp -f "$clamshelld_log" "$clamshelld_log.old"
    echo -n > "$clamshelld_log"
    logger "log rotated after 24h, see $clamshelld_log.old for previous log"
}

# clamshell-summary displays a summary of the main clamshell checks
clamshell-summary() {
    echo "ARCH: $(uname -m)"
    echo
    clamshell-vars
    echo
    echo "clamshell-yes:         $(clamshell-yes         && echo Yes || echo No)"
    echo "clamshell-has-display: $(clamshell-has-display && echo Yes || echo No)"
    echo "clamshell-has-legacy:  $(clamshell-has-legacy  && echo Yes || echo No)"
    echo "clamshell-sleeping:    $(clamshell-sleeping    && echo Yes || echo No)"
    echo "clamshell-pid:         $(clamshell-pid || echo No)"
    echo "clamshell-proxy-num:   $(clamshell-proxy-num)"
    echo "clamshell-sleep:       $(CLAMSHELL_DEBUG=1 clamshell-sleep)"
}

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
            logger "failed to sleep, $pmset sleepnow exited with code=$code"
        fi
        return $code

    elif test -n "$CLAMSHELL_DEBUG"; then
        echo noop "(no clamshell)"
    fi
    return 1
}


# Clampshell Installation
# =======================
# The `clamshell` binary can install itself as a Launchd service to run in the background.
# All required steps are directly implemented in the script instead of a Homebrew Formula
# to give users more control over the installation process.

# clamshell-binary finds location of used clamshell binary.
clamshell-source() {
    local here="$clamshell_path"
    for f in "$here/clamshell.sh" "$here/clamshell"; do
        test -e "$f" && realpath "$f" && return 0
    done
    return 1
}

# clamshell-docs finds the location of the clamshell documentation.
clamshell-docs() {
    local here="$clamshell_path"
    for d in "$here/../share/clamshell" "$here"; do
    for f in "$d/clamshell.md" "$d/README.md"; do
        test -e "$f" && realpath "$f" && return 0
    done
    done
    return 1
}

# clamshell-install installs a Launchd service to run clamshelld in the background.
clamshell-install() {
    echo "Installing clamshell binary at $clamshelld_bin"
    if clamshell-install-binary
    then echo "clamshell binary installed at $clamshelld_bin"
    else echo "clamshell binary failed to install at $clamshelld_bin"; return 1
    fi

    echo "Installing clamshell launchd service at $clamshelld_plist"
    if clamshell-install-plist
    then echo "clamshell launchd service installed at $clamshelld_plist"
    else echo "clamshell launchd service failed to install at $clamshelld_plist"; return 1
    fi

    echo "Starting clamshelld service"
    if pkill clamshelld 2> /dev/null
    then echo "clamshelld process stopped"
    else echo "no clamshelld instances running"
    fi
    local pid
    pid="$(clamshell-pid)" 2>/dev/null
    if test -n "$pid"
    then
        echo "stopping exiting service (PID=$pid)"
        clamshell-ctl unload || echo "Failed to unload clamshelld service"
    fi
    clamshell-ctl load
}

clamshell-install-binary() {
    local src
    src="$(clamshell-source)" &&
    sudo-mkdir "$clamshelld_prefix/bin" &&
    sudo-cp "$src" "$clamshelld_bin" &&
    grep -q "clamshell-main()" "$clamshelld_bin"
}

clamshell-install-plist() {
    sudo tee "$clamshelld_plist" >/dev/null <<EOF &&
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$clamshelld_service</string>
    <key>ProgramArguments</key>
    <array>
        <string>$clamshelld_bin</string>
        <string>daemon</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF
    sudo chmod 755 "$clamshelld_plist" 2> /dev/null
}

# clamshell-uninstall removes the Launchd service and the clamshelld files from the system.
clamshell-uninstall() {
    clamshell-ctl unload 1>/dev/null 2> /dev/null

    if test -e "$clamshelld_plist" && sudo-rm "$clamshelld_plist"
    then echo "Launchd service $clamshelld_service uninstalled from $clamshelld_plist"
    else echo "Launchd service $clamshelld_service not installed from $clamshelld_plist"
    fi

    if test -e "$clamshelld_bin" && sudo-rm "$clamshelld_bin"
    then echo "clamshell binary uninstalled from $clamshelld_bin"
    else echo "clamshell binary not found at $clamshelld_bin"
    fi

    if sudo rmdir "$clamshelld_prefix/bin" 2> /dev/null
    then echo "clamshell bin dir removed"
    else echo "clamshell bin dir not found $clamshelld_prefix/bin"
    fi

    if sudo-rm "$clamshelld_log" "$clamshelld_log.old" 2> /dev/null
    then echo "clamshell log files removed"
    else echo "clamshell log files not found"
    fi
}

clamshell-pid() {
    launchctl list "$clamshelld_service" 2>/dev/null | grep -E '"PID"' | grep -oE '\d+'
}

clamshell-kill() {
    echo "Unloading clamshelld service"
    clamshell-ctl unload
    echo "Killing clamshelld processes"
    local pid sig
    for sig in TERM KILL; do
    for pid in $(sudo ps aux | grep clamshelld | grep -v grep | awk '{print $2}')
    do echo "killing $pid with signal $sig"; sudo kill -$sig "$pid"
    done
    sleep 1  # wait for processes to exit
    done
}

# clamshell-ctl runs a launchctl command (load|unload) with the Launchd plist file
clamshell-ctl() {
    local code=1
    if test -e "$clamshelld_plist"
    then
        launchctl "$1" -w "$clamshelld_plist" 2>/dev/null; code=$?
        if test "$code" -eq 0
        then echo "Launchd service $1: OK"
        else echo "Launchd service $1: FAILED (code=$code)"
        fi
    else
        echo "Launchd service $clamshelld_service not installed"
    fi
    return $code
}

clamshell-status() {
    local code plist="$clamshelld_plist"
    printf "\nLaunchd Status:\n";      launchctl list "$clamshelld_service" 2>/dev/null; code=$?
    printf "\nLogfile:\n";             tail -n 10 "$clamshelld_log"
    printf "\nLaunchd PList File:\n";  test -e "$plist" && echo "found at $plist" || echo "not found at $plist"
    printf "\nPgrep clamshelld:\n";    pgrep clamshelld || echo "no clamshelld process found (try sudo pgrep)"
    printf "\nLaunchd Status Code: %s\n" $code
    return $code
}

clamshell-selftest() {(
    exec 2>&1  # redirect stderr to stdout for error checking

    local err=""
    err()       { err="$err\n$*"; }
    noerr()     { wc -l | grep -qE '^\s*0' || err "$@"; }
    nobasherr() { grep -E '^(bash:|clamshell[\.sh]*:)' && err "$@"; }

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
    clamshell-docs             | nobasherr "clamshell help failed"
    clamshell-status           | nobasherr "clamshell status failed"
    clamshell-ctl load         | nobasherr "clamshell ctl load failed"
    clamshell-ctl unload       | nobasherr "clamshell ctl unload failed"

    if test -z "$err"
    then echo "clamshell selftest: OK"
    else echo -e "$err"; echo "clamshell selftest: FAILED"
    fi
)}

# clamshell manages sleep behavior when the lid is closed.
# See `clamshell help` for more information.
clamshell-main() {
    if test $# -eq 0
    then clamshell-help; return 1
    fi

    # run one-time commands and set flags
    local flag
    for flag in "$@"
    do case "$flag" in
        -d|--debug)    export CLAMSHELL_DEBUG=1 ;;
        -h|--help|h*)  clamshell-help; return 0 ;;
        doc*|man*)     (clamshell-help; clamshell-docs) | less; return 0 ;;
        v*|--v*)       echo "clamshell version $clamshell_version ($clamshell_source)"; return 0 ;;
        -*)            echo "Unknown option: $1"; return 1 ;;
    esac
    done

    # run chained commands sequentially
    # NOTE: Use `shellcheck` linter to find incompatible pattern overloads!
    local cmd
    for cmd in "$@"
    do case "$cmd" in
        -*)            ;;  # ignore flags (parsed above)
        y*|c|ch*)      clamshell-yes ;;
        n|no*)         clamshell-no ;;
        di*|has-d*)    clamshell-has-display ;;
        ldi*|has-l*)   clamshell-has-legacy ;;
        dp|dev*)       clamshell-proxy-num ;;
        sleepi*|sln*)  clamshell-sleeping ;;
        sl*)           clamshell-sleep ;;
        aw*)           clamshell-awake ;;
        su*)           clamshell-summary ;;
        d|da*)         clamshell-daemon | tee -i -a "$clamshelld_log" ;;
        co*)           clamshell-complete ;;
        in*)           clamshell-install ;;
        un|uni*)       clamshell-uninstall ;;
        st|stat*)      clamshell-status ;;
        pid*|id)       clamshell-pid ;;
        log*)          clamshell-log ;;
        as*)           clamshell-assertions ;;
        ld|lo*|start*) clamshell-ctl load ;;
        ul|unl*|stop*) clamshell-ctl unload ;;
        self*)         clamshell-selftest ;;
        var*)          clamshell-vars ;;
        k*)            clamshell-kill ;;
        idle*)         clamshell-idle-check ;;
        *)             echo "Unknown command: $1"; return 1 ;;
    esac
    done
}

clamshell-main "$@"
