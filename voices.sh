#!/bin/bash

# TekLabs TekBase - Voice Server Management Script (Mumble, Ventrilo, TS2)
# Maintainer: Christian Frankenstein (TekLab)
# Website: www.teklab.de / www.teklab.us

VAR_A="$1"  # Action
VAR_B="$2"  # User
VAR_C="$3"  # Server ID
VAR_D="$4"  # Directory (e.g. ts2, mumble)
VAR_E="$5"  # Type: mumble/ventrilo
VAR_F="$6"  # Port
VAR_G="$7"  # Max Clients or user name
VAR_H="$8"  # Host or password
VAR_I="$9"  # Bandwidth or admin level
VAR_J="${10}" # Optional

# Standard paths
LOGP=$(cd "$(dirname "$0")" && pwd)
LOGF=$(date +"%Y_%m")
LOGFILE="$LOGP/logs/$LOGF.txt"
RESTART_PATH="$LOGP/restart"
VOICE_PATH="/home/$VAR_B/voice/$VAR_D"

mkdir -p "$LOGP/logs" "$RESTART_PATH"
chmod 0777 "$LOGP/logs" "$RESTART_PATH"
touch "$LOGFILE"
chmod 0666 "$LOGFILE"

log_msg() {
    echo "$(date) - $1" >> "$LOGFILE"
}

[ -z "$VAR_A" ] && ./tekbase && exit 0

# ------------------
# START SERVER
# ------------------
if [ "$VAR_A" = "start" ]; then
    restart_file="$RESTART_PATH/$VAR_B-voice-$VAR_C"
    [ -f "$restart_file" ] && rm -f "$restart_file"

    {
        echo "#!/bin/bash"
        echo "check=\"\""
        if [ "$VAR_E" = "ventrilo" ]; then
            echo "check=\$(pgrep -f \"screen.*voice$VAR_C-X\")"
        elif [ "$VAR_E" = "mumble" ]; then
            echo "if [ -f \"$VOICE_PATH/murmurd.pid\" ]; then"
            echo "  check=\$(ps -p \$(cat \"$VOICE_PATH/murmurd.pid\"))"
            echo "fi"
        fi
        echo "if [ -z \"\$check\" ]; then"
        echo "  cd \"$LOGP\" && sudo -u \"$VAR_B\" ./voices.sh start \"$VAR_B\" \"$VAR_C\" \"$VAR_D\" \"$VAR_E\" \"$VAR_F\" \"$VAR_G\" \"$VAR_H\" \"$VAR_I\" \"$VAR_J\""
        echo "fi"
        echo "exit 0"
    } > "$restart_file"
    chmod 0755 "$restart_file"

    cd "$VOICE_PATH" || exit 1

    if [ "$VAR_E" = "mumble" ]; then
        [ -f murmurd.pid ] && kill -9 "$(cat murmurd.pid)" 2>/dev/null && rm -f murmurd.pid
        sed -i "s/^port=.*/port=$VAR_F/" mumble-server.ini
        sed -i "s/^users=.*/users=$VAR_G/" mumble-server.ini
        sed -i "s/^host=.*/host=$VAR_H/" mumble-server.ini
        sed -i "s/^bandwidth=.*/bandwidth=$VAR_I/" mumble-server.ini
        ./mumble-server -ini mumble-server.ini &
        sleep 2
        if [ -f murmurd.pid ]; then
            log_msg "Mumble started at $VOICE_PATH"
            echo "ID1"
        else
            log_msg "Mumble failed to start at $VOICE_PATH"
            echo "ID2"
        fi

    elif [ "$VAR_E" = "ventrilo" ]; then
        pkill -f "screen.*voice$VAR_C-X"
        screen -wipe
        screen -A -m -d -S "voice$VAR_C-X" ./ventrilo_srv
        sleep 2
        if pgrep -f "screen.*voice$VAR_C-X" > /dev/null; then
            log_msg "Ventrilo started at $VOICE_PATH"
            echo "ID1"
        else
            log_msg "Ventrilo failed to start at $VOICE_PATH"
            echo "ID2"
        fi
    fi
fi

# ------------------
# STOP SERVER
# ------------------
if [ "$VAR_A" = "stop" ]; then
    restart_file="$RESTART_PATH/$VAR_B-voice-$VAR_C"
    [ -f "$restart_file" ] && rm -f "$restart_file"

    cd "$VOICE_PATH" || exit 1

    if [ "$VAR_E" = "mumble" ]; then
        [ -f murmurd.pid ] && kill -9 "$(cat murmurd.pid)" 2>/dev/null && rm -f murmurd.pid
    elif [ "$VAR_E" = "ventrilo" ]; then
        pkill -f "screen.*voice$VAR_C-X"
        screen -wipe
    fi

    if ! pgrep -f "screen.*voice$VAR_C-X" > /dev/null; then
        log_msg "Voice server stopped at $VOICE_PATH"
        echo "ID1"
    else
        log_msg "Voice server failed to stop at $VOICE_PATH"
        echo "ID2"
    fi
fi
# ------------------
# MUMBLE USER MANAGEMENT
# ------------------
if [ "$VAR_A" = "muserlist" ]; then
    cd "$VOICE_PATH" || exit 1
    sqlite3 -html mumble-server.sqlite "SELECT user_id, name FROM users ORDER BY name ASC"

elif [ "$VAR_A" = "museradd" ]; then
    cd "$VOICE_PATH" || exit 1
    password=$(echo -n "$VAR_F" | sha1sum | awk '{print $1}')
    usercount=$(sqlite3 mumble-server.sqlite "SELECT user_id FROM users ORDER BY user_id DESC LIMIT 1")
    ((newid=usercount+1))
    sqlite3 mumble-server.sqlite "INSERT INTO users (server_id, user_id, name, pw) VALUES (1, \"$newid\", \"$VAR_E\", \"$password\")"
    echo "ID1"

elif [ "$VAR_A" = "musermod" ]; then
    cd "$VOICE_PATH" || exit 1
    password=$(echo -n "$VAR_E" | sha1sum | awk '{print $1}')
    sqlite3 mumble-server.sqlite "UPDATE users SET pw=\"$password\" WHERE user_id=\"$VAR_F\""
    echo "ID1"

elif [ "$VAR_A" = "muserdel" ]; then
    cd "$VOICE_PATH" || exit 1
    sqlite3 mumble-server.sqlite "DELETE FROM users WHERE user_id=\"$VAR_E\""
    echo "ID1"
fi

# ------------------
# TS2 USER MANAGEMENT
# ------------------
TSDB_PATH="/home/user-webi/$VAR_D"

if [ "$VAR_A" = "tuserlist" ]; then
    cd "$TSDB_PATH" || exit 1
    serverid=$(sqlite server.dbs "SELECT i_server_id FROM ts2_servers WHERE i_server_udpport=\"$VAR_F\"")
    userlist=$(sqlite -html server.dbs "SELECT i_client_id, s_client_name, b_client_privilege_serveradmin FROM ts2_clients WHERE i_client_server_id=\"$serverid\" ORDER BY s_client_name ASC")
    userlist=$(echo "${userlist//&/_}")
    counter=0
    line=""
    for entry in $userlist; do
        line="$line$entry"
        ((counter++))
        if [ $counter -eq 4 ]; then
            echo "$line%TEK%"
            counter=0
            line=""
        fi
    done

elif [ "$VAR_A" = "tuseradd" ]; then
    cd "$TSDB_PATH" || exit 1
    adddate="$(date +"%d%m%Y%H%M%S")00000"
    serverid=$(sqlite server.dbs "SELECT i_server_id FROM ts2_servers WHERE i_server_udpport=\"$VAR_F\"")
    sqlite server.dbs "INSERT INTO ts2_clients (i_client_server_id, b_client_privilege_serveradmin, s_client_name, s_client_password, dt_client_created) VALUES (\"$serverid\", \"$VAR_I\", \"$VAR_G\", \"$VAR_H\", \"$adddate\")"
    echo "ID1"

elif [ "$VAR_A" = "tusermod" ]; then
    cd "$TSDB_PATH" || exit 1
    serverid=$(sqlite server.dbs "SELECT i_server_id FROM ts2_servers WHERE i_server_udpport=\"$VAR_F\"")
    sqlite server.dbs "UPDATE ts2_clients SET b_client_privilege_serveradmin=\"$VAR_I\", s_client_password=\"$VAR_H\" WHERE i_client_id=\"$VAR_G\" AND i_client_server_id=\"$serverid\""
    echo "ID1"

elif [ "$VAR_A" = "tuserdel" ]; then
    cd "$TSDB_PATH" || exit 1
    serverid=$(sqlite server.dbs "SELECT i_server_id FROM ts2_servers WHERE i_server_udpport=\"$VAR_F\"")
    sqlite server.dbs "DELETE FROM ts2_clients WHERE i_client_id=\"$VAR_G\" AND i_client_server_id=\"$serverid\""
    echo "ID1"
fi

# ------------------
# TS2 SERVER MANAGEMENT
# ------------------
if [ "$VAR_A" = "tserverchg" ]; then
    cd "$TSDB_PATH" || exit 1
    sqlite server.dbs "UPDATE ts2_servers SET i_server_maxusers=\"$VAR_H\", i_server_udpport=\"$VAR_G\" WHERE i_server_udpport=\"$VAR_F\""
    echo "ID1"

elif [ "$VAR_A" = "tservermod" ]; then
    cd "$TSDB_PATH" || exit 1
    sqlite server.dbs "UPDATE ts2_servers SET s_server_name=\"$VAR_C\", s_server_welcomemessage=\"$VAR_E\", s_server_password=\"$VAR_G\", b_server_clan_server=\"$VAR_H\", s_server_webposturl=\"$VAR_I\", s_server_weblinkurl=\"$VAR_J\" WHERE i_server_udpport=\"$VAR_F\""
    echo "ID1"

elif [ "$VAR_A" = "tserverdel" ]; then
    cd "$TSDB_PATH" || exit 1
    serverid=$(sqlite server.dbs "SELECT i_server_id FROM ts2_servers WHERE i_server_udpport=\"$VAR_F\"")
    sqlite server.dbs "DELETE FROM ts2_server_privileges WHERE i_sp_server_id=\"$serverid\""
    sqlite server.dbs "DELETE FROM ts2_channels WHERE i_channel_server_id=\"$serverid\""
    sqlite server.dbs "DELETE FROM ts2_channel_privileges WHERE i_cp_server_id=\"$serverid\""
    sqlite server.dbs "DELETE FROM ts2_clients WHERE i_client_server_id=\"$serverid\""
    sqlite server.dbs "DELETE FROM ts2_bans WHERE i_ban_server_id=\"$serverid\""
    sqlite server.dbs "DELETE FROM ts2_servers WHERE i_server_id=\"$serverid\""
    echo "ID1"

elif [ "$VAR_A" = "tserverread" ]; then
    cd "$TSDB_PATH" || exit 1
    result=$(sqlite -separator %TD% server.dbs "SELECT s_server_name, s_server_welcomemessage, s_server_password, b_server_clan_server, s_server_webposturl, s_server_weblinkurl FROM ts2_servers WHERE i_server_udpport=\"$VAR_F\"")
    echo "$result"
fi

# ------------------
# TSDNS Update
# ------------------
if [ "$VAR_A" = "tsdns" ]; then
    cd /home/tsdns || exit 1
    [ -f tsdns_settings.ini ] && sed -i "/$VAR_B/d" tsdns_settings.ini
    [ -n "$VAR_C" ] && echo "$VAR_C=$VAR_B" >> tsdns_settings.ini
    if ! pgrep -f "tsdnsserver_linux" > /dev/null; then
        [ -f tsdnsserver_linux_amd64 ] && ./tsdnsserver_linux_amd64 &
        [ -f tsdnsserver_linux_x86 ] && ./tsdnsserver_linux_x86 &
    else
        [ -f tsdnsserver_linux_amd64 ] && ./tsdnsserver_linux_amd64 --update
        [ -f tsdnsserver_linux_x86 ] && ./tsdnsserver_linux_x86 --update
    fi
    echo "ID1"
fi

# ------------------
# Generic content dump
# ------------------
if [ "$VAR_A" = "content" ]; then
    cd "/home/$VAR_B/voice/$VAR_D" || exit 1
    if [ -f "$VAR_E" ]; then
        while IFS= read -r LINE; do
            echo "$LINE%TEND%"
        done < "$VAR_E"
    else
        echo "File not found: $VAR_E"
    fi
fi

exit 0