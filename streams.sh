#!/bin/bash

# TekLabs TekBase - Stream Management Script (Modernized)
# Maintainer: Christian Frankenstein
# Supports: Screen + Docker, Symlinks for base stream setups

VAR_A="$1"   # Action
VAR_B="$2"   # User
VAR_C="$3"   # Stream ID
VAR_D="$4"   # Stream type (e.g. radio1)
VAR_E="$5"   # Stream engine (e.g. sc_serv, sc_trans, icecast, docker-sc_serv)
VAR_F="$6"   # Binary or command
VAR_G="$7"   # Port or config value
VAR_H="$8"   # Max clients / bitrate
VAR_I="$9"   # Admin port or setting
VAR_J="${10}" # DJ port or extra option

# Paths
LOGP=$(cd "$(dirname "$0")" && pwd)
LOGF=$(date +"%Y_%m")
LOGFILE="$LOGP/logs/$LOGF.txt"
RESTART_PATH="$LOGP/restart"
STREAM_DIR="/home/$VAR_B/streams/$VAR_D"
BASE_IMAGE="/home/server/streams/$VAR_E"

mkdir -p "$LOGP/logs" "$RESTART_PATH"
chmod -R 0777 "$LOGP/logs" "$RESTART_PATH"
touch "$LOGFILE"
chmod 0666 "$LOGFILE"

log_msg() {
    echo "$(date) - $1" >> "$LOGFILE"
}

is_docker() {
    [[ "$VAR_E" == docker-* ]]
}

docker_image() {
    echo "${VAR_E#docker-}"
}
########################
# START STREAM
########################
if [ "$VAR_A" = "start" ]; then
    restart_file="$RESTART_PATH/$VAR_B-$VAR_E-$VAR_C"
    rm -f "$restart_file"

    cat <<EOF > "$restart_file"
#!/bin/bash
if [ -f /home/$VAR_B/streams/$VAR_D/$VAR_E.pid ]; then
    pid=\$(cat /home/$VAR_B/streams/$VAR_D/$VAR_E.pid)
    check=\$(ps -p \$pid | grep "$VAR_E")
fi
if [ -z "\$check" ]; then
    cd "$LOGP"
    sudo -u "$VAR_B" ./streams.sh start "$VAR_B" "$VAR_C" "$VAR_D" "$VAR_E" "$VAR_F" "$VAR_G" "$VAR_H" "$VAR_I" "$VAR_J"
fi
exit 0
EOF
    chmod 0755 "$restart_file"

    # Ensure stream directory exists
    if [ ! -d "$STREAM_DIR" ]; then
        mkdir -p "$STREAM_DIR"
        chmod 755 "$STREAM_DIR"
        if [ -d "$BASE_IMAGE" ]; then
            ln -s "$BASE_IMAGE"/* "$STREAM_DIR/"
        else
            log_msg "Missing base image for $VAR_E in $BASE_IMAGE"
            echo "ID2"
            exit 1
        fi
    fi

    cd "$STREAM_DIR" || exit 1

    # Stop existing PID
    [ -f "$VAR_E.pid" ] && kill -9 "$(cat "$VAR_E.pid")" 2>/dev/null && rm -f "$VAR_E.pid"

    if is_docker; then
        dockername="stream_${VAR_B}_${VAR_C}_${VAR_E}"
        docker run -d --rm --name "$dockername" \
            -v "$STREAM_DIR":/data \
            -p "$VAR_G:$VAR_G/udp" \
            "$(docker_image)" >/dev/null
        sleep 2
        if docker ps | grep -q "$dockername"; then
            log_msg "Docker stream $dockername started on $VAR_G"
            echo "ID1"
        else
            log_msg "Docker stream $dockername failed to start"
            echo "ID2"
        fi
    else
        # Apply config replacements for known engines
        case "$VAR_E" in
            sc_serv)
                sed -i "s/^PortBase=.*/PortBase=$VAR_G/" sc_serv.conf
                sed -i "s/^MaxUser=.*/MaxUser=$VAR_H/" sc_serv.conf
                ;;
            sc_trans)
                DJ_PORT2=$((VAR_J + 5))
                sed -i "s/^ServerPort=.*/ServerPort=$VAR_G/" sc_trans.conf
                sed -i "s/^AdminPort=.*/AdminPort=$VAR_I/" sc_trans.conf
                sed -i "s/^DjPort=.*/DjPort=$VAR_J/" sc_trans.conf
                sed -i "s/^DjPort2=.*/DjPort2=$DJ_PORT2/" sc_trans.conf
                ;;
            icecast)
                sed -i "s/<port>.*<\/port>/<port>$VAR_G<\/port>/" icecast.xml
                sed -i "s/<clients>.*<\/clients>/<clients>$VAR_H<\/clients>/" icecast.xml
                ;;
            ices)
                sed -i "s/<port>.*<\/port>/<port>$VAR_G<\/port>/" ices.xml
                sed -i "s/<bitrate>.*<\/bitrate>/<bitrate>$VAR_H<\/bitrate>/" ices.xml
                ;;
            ices2)
                sed -i "s/<Port>.*<\/Port>/<Port>$VAR_G<\/Port>/" ices2.xml
                sed -i "s/<nominal-bitrate>.*<\/nominal-bitrate>/<nominal-bitrate>$VAR_H<\/nominal-bitrate>/" ices2.xml
                ;;
        esac

        $VAR_F &
        echo $! > "$VAR_E.pid"

        if [ -f "$VAR_E.pid" ]; then
            log_msg "Stream $VAR_E for $VAR_B/$VAR_D started on port $VAR_G"
            echo "ID1"
        else
            log_msg "Stream $VAR_E for $VAR_B/$VAR_D failed to start"
            echo "ID2"
        fi
    fi
fi
########################
# STOP STREAM
########################
if [ "$VAR_A" = "stop" ]; then
    rm -f "$RESTART_PATH/$VAR_B-$VAR_E-$VAR_C"
    cd "$STREAM_DIR" || exit 1

    if is_docker; then
        dockername="stream_${VAR_B}_${VAR_C}_${VAR_E}"
        docker stop "$dockername" >/dev/null
        sleep 1
        if ! docker ps | grep -q "$dockername"; then
            log_msg "Docker stream $dockername stopped"
            echo "ID1"
        else
            log_msg "Failed to stop docker stream $dockername"
            echo "ID2"
        fi
    else
        if [ -f "$VAR_E.pid" ]; then
            kill -9 "$(cat "$VAR_E.pid")" 2>/dev/null
            rm -f "$VAR_E.pid"
        fi
        if ! pgrep -f "$VAR_E" > /dev/null; then
            log_msg "Stream $VAR_E on $VAR_B/$VAR_D stopped"
            echo "ID1"
        else
            log_msg "Failed to stop stream $VAR_E on $VAR_B/$VAR_D"
            echo "ID2"
        fi
    fi
fi

########################
# STREAM STATUS
########################
if [ "$VAR_A" = "status" ]; then
    if is_docker; then
        dockername="stream_${VAR_B}_${VAR_C}_${VAR_E}"
        if docker ps | grep -q "$dockername"; then
            echo "ID2"
        else
            echo "ID1"
        fi
    else
        if pgrep -f "$VAR_E" > /dev/null; then
            echo "ID2"
        else
            echo "ID1"
        fi
    fi
fi

########################
# REWRITE CONFIG LINE
########################
if [ "$VAR_A" = "rewrite" ]; then
    cd "$STREAM_DIR" || exit 1
    if [ -n "$VAR_F" ]; then
        sed -i "/$VAR_F/Ic\\$VAR_G" "$VAR_E"
        if ! grep -iq "$VAR_G" "$VAR_E"; then
            echo "$VAR_G" >> "$VAR_E"
        fi
        log_msg "Rewrote $VAR_F to $VAR_G in $VAR_E"
    fi
fi

########################
# UPDATE STREAM
########################
if [ "$VAR_A" = "update" ]; then
    if pgrep -f "$VAR_B$VAR_D-X" > /dev/null; then
        log_msg "Stream update blocked: already running"
        echo "ID2"
    else
        screen -A -m -d -S "b$VAR_B$VAR_D-X" ./streams.sh updaterun "$VAR_B" "$VAR_C" "$VAR_D" "$VAR_E"
        sleep 2
        if pgrep -f "b$VAR_B$VAR_D-X" > /dev/null; then
            echo "ID1"
        else
            echo "ID2"
        fi
    fi
fi

if [ "$VAR_A" = "updaterun" ]; then
    sleep 2
    cd "$STREAM_DIR" || exit 1
    IFS=$'\n'
    for cmd in $(echo "$VAR_E" | tr ';' '\n'); do
        if [ -n "$cmd" ]; then
            eval "$cmd"
        fi
    done
    unset IFS
    log_msg "Update applied for stream $VAR_D"
    echo "ID1"
fi
########################
# GENERATE PLAYLISTS
########################
if [ "$VAR_A" = "playlist" ]; then
    cd "$STREAM_DIR" || exit 1
    mkdir -p playlists songs

    if [ "$VAR_C" = "ic" ]; then
        find mp3/ -type f -name "*.mp3" > mp3_playlist.lst
        find ogg/ -type f -name "*.ogg" > ogg_playlist.lst
        log_msg "IC-style playlists created in $STREAM_DIR"
    else
        if [ -n "$VAR_E" ]; then
            if [ -n "$VAR_F" ]; then
                mkdir -p "songs/$VAR_F"
                find "songs/$VAR_F" -maxdepth 1 -type f \( -iname "*.mp3" -o -iname "*.aac" \) > "playlists/$VAR_E.lst"
                log_msg "Playlist $VAR_E.lst created from songs/$VAR_F"
            else
                find songs/ -maxdepth 1 -type f -iname "*.mp3" > "playlists/$VAR_E.lst"
                log_msg "Playlist $VAR_E.lst created from songs/"
            fi
        else
            find songs/ -type f -iname "*.mp3" > playlist.lst
            log_msg "Default playlist.lst created from songs/"
        fi
    fi
fi

########################
# OUTPUT FILE CONTENT
########################
if [ "$VAR_A" = "content" ]; then
    cd "$STREAM_DIR" || exit 1
    if [ -f "$VAR_E" ]; then
        while IFS= read -r LINE; do
            echo "$LINE%TEND%"
        done < "$VAR_E"
    else
        echo "File not found: $VAR_E"
    fi
fi

########################
# STREAM STATISTICS
########################
if [ "$VAR_A" = "streamstats" ]; then
    STATS_DIR="/home/$VAR_B/streams/$VAR_C/stats"
    mkdir -p "$STATS_DIR"
    cd "$STATS_DIR" || exit 1

    STREAM_CHECK=$(php -f php/stream_check.php)
    CURRENT_SLOTS=$(echo "$STREAM_CHECK" | awk '{print $2}')
    CURRENT_TITLE=$(echo "$STREAM_CHECK" | awk '{for (i=3;i<=NF;i++) printf("%s ", $i)}')

    EXISTING_ENTRY=$(grep -i "$CURRENT_TITLE" "$LOGF.txt" | awk '{print $3, $4}')
    if [ -n "$EXISTING_ENTRY" ]; then
        LISTENERS=$(echo "$EXISTING_ENTRY" | awk '{print $2}')
        [ -z "$LISTENERS" ] && LISTENERS="0"
        if [ "$LISTENERS" -lt "$CURRENT_SLOTS" ]; then
            sed -i "/$CURRENT_TITLE/Ic\\$LOGDAY | Listeners $CURRENT_SLOTS | Title $CURRENT_TITLE" "$LOGF.txt"
        fi
    else
        echo "$LOGDAY | Listeners $CURRENT_SLOTS | Title $CURRENT_TITLE" >> "$LOGF.txt"
    fi
fi
########################
# EXIT
########################
exit 0