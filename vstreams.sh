#!/bin/bash

# TekLabs TekBase - Video Streams Controller Script (Screen + Docker)
# Maintainer: Christian Frankenstein (TekLab)
# Website: teklab.de / teklab.net

VAR_A="$1"  # Action
VAR_B="$2"  # User
VAR_C="$3"  # Stream ID
VAR_D="$4"  # Path
VAR_E="$5"  # App name OR Docker container name
VAR_F="$6"  # Start script (for screen)
VAR_G="$7"  # Base port

# Setup logging
LOGP=$(cd "$(dirname "$0")" && pwd)
LOGF=$(date +"%Y_%m")
LOGFILE="$LOGP/logs/$LOGF.txt"
RESTART_PATH="$LOGP/restart"

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

get_container_name() {
    echo "${VAR_E#docker-}"
}

[ -z "$VAR_A" ] && ./tekbase && exit 0

if [ "$VAR_A" = "start" ]; then
    restart_script="$RESTART_PATH/$VAR_B-vstreams-$VAR_C"
    rm -f "$restart_script"

    cat <<EOF > "$restart_script"
#!/bin/bash
$(is_docker && echo "check=\$(docker ps | grep -i \$(get_container_name))" || echo "check=\$(pgrep -f \"screen.*vstreams$VAR_C-X\")")
if [ -z "\$check" ]; then
    cd "$LOGP"
    sudo -u "$VAR_B" ./vstreams start "$VAR_B" "$VAR_C" "$VAR_D" "$VAR_E" "$VAR_F" "$VAR_G"
fi
exit 0
EOF
    chmod 0755 "$restart_script"

    if is_docker; then
        container=$(get_container_name)
        docker start "$container"
        sleep 2
        if docker ps | grep -q "$container"; then
            log_msg "Docker stream container '$container' was started"
            echo "ID1"
        else
            log_msg "Docker stream container '$container' failed to start"
            echo "ID2"
        fi
    else
        cd "/home/$VAR_B/vstreams/$VAR_D" || exit 1
        pkill -f "screen.*$VAR_F$VAR_B-X"
        screen -wipe

        if ! pgrep -f "screen.*$VAR_F$VAR_B-X" > /dev/null; then
            let httpp=VAR_G+40
            let httpsp=VAR_G+30
            let rtmptp=VAR_G+20
            let mrtmpp=VAR_G+10
            let proxyp=VAR_G+1

            cd conf || exit 1
            sed -i.bak -e "s/^http.port=.*/http.port=$httpp/" \
                       -e "s/^rtmp.port=.*/rtmp.port=$VAR_G/" \
                       -e "s/^rtmpt.port=.*/rtmpt.port=$rtmptp/" \
                       -e "s/^mrtmp.port=.*/mrtmp.port=$mrtmpp/" \
                       -e "s/^proxy.source_port=.*/proxy.source_port=$proxyp/" \
                       -e "s/^proxy.destination_port=.*/proxy.destination_port=$VAR_G/" \
                       -e "s/^https.port=.*/https.port=$httpsp/" red5.properties

            cd "/home/$VAR_B/vstreams/$VAR_D" || exit 1
            screen -A -m -d -S "vstreams$VAR_C-X" "$VAR_F"
            if pgrep -f "screen.*vstreams$VAR_C-X" > /dev/null; then
                log_msg "Screen-based stream /home/$VAR_B/vstreams/$VAR_D was started ($VAR_F)"
                echo "ID1"
            else
                log_msg "Screen-based stream /home/$VAR_B/vstreams/$VAR_D failed to start ($VAR_F)"
                echo "ID2"
            fi
        else
            log_msg "Stream already running, could not restart ($VAR_F)"
            echo "ID3"
        fi
    fi
fi

if [ "$VAR_A" = "stop" ]; then
    rm -f "$RESTART_PATH/$VAR_B-vstreams-$VAR_C"

    if is_docker; then
        container=$(get_container_name)
        docker stop "$container"
        sleep 1
        if ! docker ps | grep -q "$container"; then
            log_msg "Docker stream container '$container' was stopped"
            echo "ID1"
        else
            log_msg "Docker stream container '$container' could not be stopped"
            echo "ID2"
        fi
    else
        pkill -f "screen.*vstreams$VAR_C-X"
        screen -wipe
        if ! pgrep -f "screen.*vstreams$VAR_C-X" > /dev/null; then
            log_msg "Stream /home/$VAR_B/vstreams/$VAR_D was stopped"
            echo "ID1"
        else
            log_msg "Stream /home/$VAR_B/vstreams/$VAR_D could not be stopped"
            echo "ID2"
        fi
    fi
fi

if [ "$VAR_A" = "content" ]; then
    cd "/home/$VAR_B/vstreams/$VAR_D" || exit 1
    if [ -f "$VAR_E" ]; then
        while IFS= read -r LINE; do
            echo "$LINE%TEND%"
        done < "$VAR_E"
    else
        echo "File not found: $VAR_E"
    fi
fi

exit 0