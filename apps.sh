#!/bin/bash

# TekLabs TekBase - Unified App Control Script
# Maintainer: Christian Frankenstein (TekLab)
# Website: teklab.de / teklab.net

VAR_A="$1"  # Action
VAR_B="$2"  # User
VAR_C="$3"  # ID
VAR_D="$4"  # Path
VAR_E="$5"  # Shortcut or container name (e.g., docker-minecraft)
VAR_F="$6"  # Start command
VAR_G="$7"  # PID file (optional)
VAR_H="$8"  # Process name for PID (optional)

# Setup
LOGP=$(cd "$(dirname "$0")" && pwd)
LOGF=$(date +"%Y_%m")
LOGFILE="$LOGP/logs/$LOGF.txt"
RESTART_PATH="$LOGP/restart"
INCLUDES_PATH="$LOGP/includes/stop"

mkdir -p "$LOGP/logs" "$RESTART_PATH"
chmod 0777 "$LOGP/logs" "$RESTART_PATH"
touch "$LOGFILE"
chmod 0666 "$LOGFILE"

log_msg() {
    echo "$(date) - $1" >> "$LOGFILE"
}

is_docker() {
    [[ "$VAR_E" == docker-* ]]
}

kill_process() {
    if is_docker; then
        docker stop "${VAR_E#docker-}" >/dev/null 2>&1
    elif [ -n "$VAR_G" ] && [ -f "$VAR_G" ]; then
        check=$(ps -p "$(cat "$VAR_G")" | grep -i "$VAR_H")
        [ -n "$check" ] && kill -9 "$(cat "$VAR_G")" && rm -f "$VAR_G"
    else
        pkill -f "screen.*apps$VAR_C-X"
        screen -wipe > /dev/null 2>&1
    fi
}

start_process() {
    cd "/home/$VAR_B/apps/$VAR_D" || exit 1

    if is_docker; then
        docker start "${VAR_E#docker-}" >/dev/null 2>&1
        sleep 2
        check=$(docker ps | grep "${VAR_E#docker-}")
    elif [ -z "$VAR_G" ]; then
        pkill -f "screen.*apps$VAR_C-X"
        screen -wipe
        screen -A -m -d -S "apps$VAR_C-X" $VAR_F
        check=$(ps aux | grep -v grep | grep -i "apps$VAR_C-X")
    else
        $VAR_F
        sleep 2
        check=$( [ -f "$VAR_G" ] && ps -p "$(cat "$VAR_G")" | grep -i "$VAR_H" )
    fi

    if [ -n "$check" ]; then
        log_msg "App /home/$VAR_B/apps/$VAR_D was started ($VAR_F)"
        echo "ID1"
    else
        log_msg "App /home/$VAR_B/apps/$VAR_D failed to start ($VAR_F)"
        echo "ID2"
    fi
}

stop_process() {
    if [ -f "$INCLUDES_PATH/$VAR_E" ]; then
        check=$("$INCLUDES_PATH/$VAR_E" "$VAR_B" "$VAR_C" "$VAR_D" "$VAR_E" "$VAR_F" "$VAR_G" "$VAR_H")
    else
        kill_process
        if is_docker; then
            check=$(docker ps | grep "${VAR_E#docker-}")
        else
            check=$(pgrep -f "apps$VAR_C-X")
        fi
    fi

    if [ -z "$check" ]; then
        log_msg "App /home/$VAR_B/apps/$VAR_D was stopped"
        echo "ID1"
    else
        log_msg "App /home/$VAR_B/apps/$VAR_D failed to stop"
        echo "ID2"
    fi
}

create_restart_script() {
    local restart_file="$RESTART_PATH/$VAR_B-apps-$VAR_C"
    cat <<EOF > "$restart_file"
#!/bin/bash
$( is_docker && echo "check=\$(docker ps | grep '${VAR_E#docker-}')" || \
   [ -z "$VAR_G" ] && echo "check=\$(pgrep -f 'screen.*apps$VAR_C-X')" || \
   echo "if [ -f /home/$VAR_B/apps/$VAR_C/$VAR_G ]; then check=\$(ps -p \$(cat /home/$VAR_B/apps/$VAR_C/$VAR_G)); fi" )
if [ -z "\$check" ]; then
    cd "$LOGP"
    sudo -u "$VAR_B" ./apps start "$VAR_B" "$VAR_C" "$VAR_D" "$VAR_E" "$VAR_F" "$VAR_G" "$VAR_H"
fi
exit 0
EOF
    chmod 0755 "$restart_file"
}

case "$VAR_A" in
    "")
        ./tekbase
        ;;

    "start")
        rm -f "$RESTART_PATH/$VAR_B-apps-$VAR_C"
        create_restart_script
        start_process
        ;;

    "stop")
        rm -f "$RESTART_PATH/$VAR_B-apps-$VAR_C"
        cd "/home/$VAR_B/apps/$VAR_D" || exit 1
        stop_process
        ;;

    "content")
        cd "/home/$VAR_B/apps/$VAR_D" || exit 1
        while IFS= read -r LINE; do
            echo "$LINE%TEND%"
        done < "$VAR_E"
        ;;

    "update")
        if ! pgrep -f "screen.*$VAR_B$VAR_D-X" > /dev/null; then
            screen -A -m -d -S "b$VAR_B$VAR_D-X" ./apps updaterun "$VAR_B" "$VAR_C" "$VAR_D" "$VAR_E"
            echo "ID1"
        else
            log_msg "Update of /home/$VAR_B/apps/$VAR_D could not be installed (already running)"
            echo "ID2"
        fi
        ;;

    "updaterun")
        cd "/home/$VAR_B/apps/$VAR_D" || exit 1
        IFS=';' read -ra commands <<< "$VAR_E"
        for cmd in "${commands[@]}"; do
            [ -n "$cmd" ] && eval "$cmd"
        done
        log_msg "Update of /home/$VAR_B/apps/$VAR_D was installed"
        ;;

    "online")
        if is_docker; then
            docker ps | grep -q "${VAR_E#docker-}" && echo "ID1" || echo "ID2"
        else
            pgrep -f "screen.*apps$VAR_C-X" >/dev/null && echo "ID1" || echo "ID2"
        fi
        ;;

    "status")
        if is_docker; then
            docker ps | grep -q "${VAR_E#docker-}" && echo "ID2" || echo "ID1"
        else
            pgrep -f "screen.*$VAR_E$VAR_B$VAR_D-X" >/dev/null || echo "ID1"
        fi
        ;;

    *)
        echo "Unknown action: $VAR_A"
        exit 1
        ;;
esac

exit 0