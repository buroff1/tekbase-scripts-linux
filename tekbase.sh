#!/bin/bash

# TekLabs TekBase - Modernized User & Server Management Script
# Maintainer: Christian Frankenstein
# Updated: 2025-04-16

# Parameters
VAR_A="$1"
VAR_B="$2"
VAR_C="$3"
VAR_D="$4"
VAR_E="$5"
VAR_F="$6"
VAR_G="$7"
VAR_H="$8"
VAR_I="$9"
VAR_J="${10}"

# Setup Paths and Logging
LOGP=$(cd "$(dirname "$0")" && pwd)
LOGF=$(date +"%Y_%m")
LOGC=$(date +"%Y_%m-%H_%M_%S")
LOGFILE="$LOGP/logs/$LOGF.txt"

mkdir -p "$LOGP/logs" "$LOGP/restart" "$LOGP/startscripte" "$LOGP/cache"
chmod -R 0777 "$LOGP/logs" "$LOGP/restart" "$LOGP/startscripte" "$LOGP/cache"
touch "$LOGFILE"
chmod 0666 "$LOGFILE"

log_msg() {
    echo "$(date) - $1" >> "$LOGFILE"
}

# Info header for default run
if [ -z "$VAR_A" ]; then
    LOGY=$(date +"%Y")
    clear
    echo "###########################################"
    echo "# TekLabs TekBase                         #"
    echo "# Copyright 2005-$LOGY TekLab              #"
    echo "# Christian Frankenstein                  #"
    echo "# Website: www.teklab.de                  #"
    echo "#          www.teklab.us                  #"
    echo "###########################################"
fi
case "$VAR_A" in
    # ----------------------------
    # Case 1: Create or update user
    # ----------------------------
    1)
        if [ ! -d /home/"$VAR_B" ]; then
            useradd -g users -p "$(perl -e 'print crypt("'"$VAR_C"'","Sa")')" -s /bin/bash -m "$VAR_B" -d /home/"$VAR_B"
            if [ ! -d /home/"$VAR_B" ]; then
                log_msg "Error: User $VAR_B could not be created"
                echo "ID2"
            else
                log_msg "User $VAR_B was created"
                echo "ID1"
            fi
        else
            usermod -p "$(perl -e 'print crypt("'"$VAR_C"'","Sa")')" "$VAR_B"
            log_msg "User $VAR_B already existed and password was updated"
            echo "ID1"
        fi
    ;;

    # ----------------------------
    # Case 2: Change user password
    # ----------------------------
    2)
        usermod -p "$(perl -e 'print crypt("'"$VAR_C"'","Sa")')" "$VAR_B"
        log_msg "User $VAR_B password was changed"
        echo "ID1"
    ;;

    # ----------------------------
    # Case 3: Delete user (step 1 - initiate)
    # ----------------------------
    3)
        rm -f "$LOGP/restart/$VAR_B"*
        screenname="d${VAR_B}-X"
        startchk=$(pgrep -f "screen.*$screenname")

        if [ -z "$startchk" ]; then
            screen -A -m -d -S "$screenname" "$0" 4 "$VAR_B" "$VAR_C"
            sleep 1
            check=$(pgrep -f "screen.*$screenname")
        fi

        if [ -z "$check" ]; then
            if [ ! -d /home/"$VAR_B" ]; then
                log_msg "User $VAR_B was deleted"
                echo "ID1"
            else
                log_msg "Error: User $VAR_B could not be deleted"
                echo "ID2"
            fi
        else
            log_msg "User $VAR_B deletion screen started"
            echo "ID1"
        fi
    ;;

    # ----------------------------
    # Case 4: Delete user (step 2 - deep clean)
    # ----------------------------
    4)
        counter=0
        deleteall=0
        if [ "$VAR_C" != "all" ]; then
            while [ "$counter" -ne 1 ]; do
                totalcount=0
                cd /home/"$VAR_B" || break

                for folder in apps server streams voice vstreams; do
                    if [ -d "$folder" ]; then
                        cd "$folder" || continue
                        subcount=$(find -type d | wc -l)
                        [ "$subcount" -ne 1 ] && totalcount=1
                        cd ..
                    fi
                done

                if [ "$totalcount" -eq 1 ]; then
                    sleep 5
                    deleteall=$((deleteall + 1))
                else
                    counter=1
                fi

                if [ "$deleteall" -eq 5 ]; then
                    cd /home/"$VAR_B" && rm -rf *
                    counter=1
                fi
            done
        fi

        userdel "$VAR_B"
        rm -rf /home/"$VAR_B"
        rm -rf /var/run/screen/S-"$VAR_B"
        rm -rf /var/run/uscreen/S-"$VAR_B"
        log_msg "User $VAR_B and home directory removed"
    ;;
    # ----------------------------
    # Case 5: Install - Step 1 (screen launch)
    # ----------------------------
    5)
        screenname="i${VAR_B}${VAR_C}-X"
        startchk=$(pgrep -f "screen.*$screenname")
        if [ -z "$startchk" ]; then
            screen -A -m -d -S "$screenname" "$0" 6 "$VAR_B" "$VAR_C" "$VAR_D" "$VAR_E" "$VAR_F" "$VAR_G" "$VAR_H"
            sleep 1
            check=$(pgrep -f "screen.*$screenname")
        fi

        if [ -z "$check" ]; then
            [ ! -d /home/"$VAR_B"/"$VAR_F"/"$VAR_C" ] && echo "ID2" || echo "ID1"
        else
            echo "ID1"
        fi
    ;;

    # ----------------------------
    # Case 6: Install - Step 2 (actual install)
    # ----------------------------
    6)
        cd /home/"$VAR_B" || exit 1
        su "$VAR_B" -c "mkdir -p '$VAR_F'"
        cd "$VAR_F" || exit 1

        if [ "$VAR_G" = "delete" ]; then
            sleep 10
            rm -rf "$VAR_C"
            [ -f "$VAR_C.tar" ] && rm "$VAR_C.tar"
        fi

        su "$VAR_B" -c "mkdir '$VAR_C'"
        if [ ! -d "$VAR_C" ]; then
            log_msg "Folder /home/$VAR_B/$VAR_F/$VAR_C could not be created"
        else
            log_msg "Folder /home/$VAR_B/$VAR_F/$VAR_C was created"
        fi

        if [ -f "$VAR_G" ] && [ -n "$VAR_G" ]; then
            mv "$VAR_G" "/home/$VAR_B/$VAR_F/$VAR_C/install.sh"
            cd "/home/$VAR_B/$VAR_F/$VAR_C" || exit 1
            chown "$VAR_B" install.sh
            chmod 755 install.sh
            su "$VAR_B" -c "./install.sh"
            rm install.sh

            counter=$(find . -type f | wc -l)
            [ "$counter" -ne 0 ] && log_msg "Script in $VAR_B/$VAR_F/$VAR_C installed" || log_msg "Script in $VAR_B/$VAR_F/$VAR_C could not be installed"
            exit 0
        fi

        cd "$LOGP" || exit 1
        mkdir -p cache
        cd cache || exit 1

        if [ ! -f "$VAR_D.tar" ]; then
            mkdir "$LOGC"
            cd "$LOGC" || exit 1
            wget "$VAR_E/$VAR_D.tar"
            mv "$VAR_D.tar" "$LOGP/cache/$VAR_D.tar"
            cd "$LOGP/cache" || exit 1
            rm -rf "$LOGC"
        else
            [ -f "$VAR_B$VAR_C.md5" ] && rm "$VAR_B$VAR_C.md5"
            wget -O "$VAR_B$VAR_C.md5" "$VAR_E/$VAR_D.tar.md5"
            if [ -f "$VAR_B$VAR_C.md5" ]; then
                dowmd5=$(awk '{print $1}' "$VAR_B$VAR_C.md5")
                rm "$VAR_B$VAR_C.md5"
            else
                dowmd5="ID2"
            fi
            chkmd5=$(md5sum "$VAR_D.tar" | awk '{print $1}')
            if [ "$dowmd5" != "$chkmd5" ]; then
                mkdir "$LOGC"
                cd "$LOGC" || exit 1
                wget "$VAR_E/$VAR_D.tar"
                dowmd5=$(md5sum "$VAR_D.tar" | awk '{print $1}')
                [ "$dowmd5" != "$chkmd5" ] && mv "$VAR_D.tar" "$LOGP/cache/$VAR_D.tar"
                cd "$LOGP/cache" || exit 1
                rm -rf "$LOGC"
            fi
        fi

        if [ ! -f "$VAR_D.tar" ]; then
            log_msg "Image $VAR_D.tar could not be downloaded"
        else
            log_msg "Image $VAR_D.tar was downloaded"
            if [ "$VAR_G" = "protect" ]; then
                userchk=$(grep "^$VAR_B-p:" /etc/passwd | grep -i sec)
                if [ -z "$userchk" ]; then
                    passwd=$(pwgen 8 1 -c -n)
                    useradd -g users -p "$(perl -e 'print crypt("'"$passwd"'","Sa")')" -s /bin/bash "$VAR_B-p" -d "/home/$VAR_B/$VAR_F/$VAR_C"
                fi
                cd "/home/$VAR_B/$VAR_F" || exit 1
                chown "$VAR_B-p:users" "$VAR_C"
                chmod 755 "$VAR_C"
                cd "$LOGP/cache" || exit 1
                su "$VAR_B-p" -c "tar -xf $VAR_D.tar -C /home/$VAR_B/$VAR_F/$VAR_C"
            else
                su "$VAR_B" -c "tar -xf $VAR_D.tar -C /home/$VAR_B/$VAR_F/$VAR_C"
            fi

            cd "/home/$VAR_B/$VAR_F/$VAR_C" || exit 1
            [ -f install.sh ] && chmod 0777 install.sh && su "$VAR_B" -c "./install.sh" && rm install.sh

            if [ "$VAR_F" = "server" ]; then
                cd "$LOGP/includes/$VAR_D" || exit 1
                for PROTLINE in $(cat protect.inf); do
                    [ -f "$PROTLINE" ] && chown "$VAR_B-p:users" "$PROTLINE" && chmod 554 "$PROTLINE"
                done
            fi

            counter=$(find . -type f | wc -l)
            [ "$counter" -ne 0 ] && log_msg "Image $VAR_D.tar installed" || log_msg "Image $VAR_D.tar could not be installed"
        fi
        sleep 2
    ;;

    # ----------------------------
    # Case 7: Deinstall - Step 1 (screen launch)
    # ----------------------------
    7)
        [ -f "$LOGP/restart/$VAR_B-$VAR_D-$VAR_C" ] && rm "$LOGP/restart/$VAR_B-$VAR_D-$VAR_C"
        screenname="d${VAR_B}${VAR_C}-X"
        startchk=$(pgrep -f "screen.*$screenname")

        if [ -z "$startchk" ]; then
            screen -A -m -d -S "$screenname" "$0" 8 "$VAR_B" "$VAR_C" "$VAR_D"
            sleep 1
            check=$(pgrep -f "screen.*$screenname")
        fi

        if [ -z "$check" ]; then
            [ ! -d /home/"$VAR_B"/"$VAR_D"/"$VAR_C" ] && echo "ID1" || echo "ID2"
        else
            echo "ID1"
        fi
    ;;

    # ----------------------------
    # Case 8: Deinstall - Step 2
    # ----------------------------
    8)
        sleep 10
        cd /home/"$VAR_B"/"$VAR_D" || exit 1
        rm -rf "$VAR_C"

        userchk=$(grep "^$VAR_B-p:" /etc/passwd | grep -i sec)
        if [ -n "$userchk" ]; then
            killall -u "$VAR_B-p"
            sleep 10
            userdel "$VAR_B-p"
            rm -rf /home/"$VAR_B"
            rm -rf /var/run/screen/S-"$VAR_B-p"
            rm -rf /var/run/uscreen/S-"$VAR_B-p"
        fi

        [ -d "$LOGP/cache/$VAR_B$VAR_D" ] && rm -f "$LOGP/cache/$VAR_B$VAR_D"
        [ -d "$LOGP/cache/$VAR_B$VAR_C" ] && rm -rf "$LOGP/cache/$VAR_B$VAR_C"

        if [ ! -d "$VAR_C" ]; then
            log_msg "Folder /home/$VAR_B/$VAR_D/$VAR_C was deleted"
        else
            log_msg "Folder /home/$VAR_B/$VAR_D/$VAR_C could not be deleted"
        fi
    ;;
    # FTP User Creation
    9)
        uid=$(grep "home/$VAR_B" /etc/passwd | cut -d : -f3)
        gid=$(grep "home/$VAR_B" /etc/passwd | cut -d : -f4)
        /usr/bin/expect <<EOF
cd /etc/proftpd
spawn ftpasswd --passwd --name=$VAR_C --uid=$uid --gid=$gid --home=$VAR_E --shell=/bin/false
expect "Password:" {send "$VAR_D\r"}
expect "Re-type password:" {send "$VAR_D\r"}
expect eof
EOF
        ftpasswd --group --file=/etc/proftpd/ftpd.group --name=$VAR_C --gid=$gid --member=$VAR_C
        echo "ID1"
    ;;

    # FTP User Password Change
    10)
        /usr/bin/expect <<EOF
cd /etc/proftpd
spawn ftpasswd --change-password --passwd --name=$VAR_C
expect "Password:" {send "$VAR_D\r"}
expect "Re-type password:" {send "$VAR_D\r"}
expect eof
EOF
        echo "ID1"
    ;;

    # FTP User Deletion
    11)
        cd /etc/proftpd
        ftpasswd --delete-user --passwd --name=$VAR_C
        echo "ID1"
    ;;

    # TekBase Utility: Cleanup Logs, Restart Daemon, CPU/Memory Stats
    18)
        case "$VAR_B" in
            "")
                echo "8701"
                ;;
            "scservlog")
                find /home -iname sc_serv.log -type f -exec rm {} \;
                ;;
            "sctranslog")
                find /home -iname sc_trans.log -type f -exec rm {} \;
                ;;
            "screenlog")
                find /home -iname screenlog* -type f -exec rm {} \;
                ;;
            "restart")
                cd "$LOGP/restart"
                find . -type f -exec bash {} \;
                ;;
            "daemon")
                check=$(pgrep -f tekbase_daemon)
                [ -z "$check" ] && check=$(pgrep -f "perl -e use MIME::Base64")
                [ -z "$check" ] && ./server &
                ;;
            "cpumem")
                check=$(ps x | grep -i "server${VAR_C}-X" | grep -v grep | sed -e "s#.*server${VAR_C}-X \.\(\)#\1#" | grep -v "sed -e")
                if [ -n "$check" ]; then
                    pidone=$(ps x | grep -i "$check" | grep -vi screen | grep -v grep | awk '{print $1}')
                    if [ -n "$pidone" ]; then
                        let pidend=pidone+51
                        while [ $pidone -lt $pidend ]; do
                            chkpid=$(ps x | grep -i "${pidone} " | grep -v grep)
                            if [ -n "$chkpid" ]; then
                                chkmem=$(ps -p $pidone -o pmem --no-headers | awk '{print $1}')
                                if [[ "$chkmem" != "0.0" && "$chkmem" != "0.1" && "$chkmem" != "0.2" ]]; then
                                    chkcpu=$(ps -p $pidone -o pcpu --no-headers | awk '{print $1}')
                                    chkfree=$(free -k | grep -i "mem" | awk '{print $2}')
                                    echo "$chkcpu;$chkmem;$chkfree"
                                    break
                                fi
                            fi
                            let pidone=pidone+1
                        done
                    fi
                fi
                ;;
        esac
    ;;

    # AutoUpdater Start
    19)
        screen -A -m -d -S tekautoup ./autoupdater
        check=$(pgrep -f "screen.*tekautoup")
        [ -z "$check" ] && echo "ID2" || echo "ID1"
    ;;
    # VServer Management: delete, traffic, iplist
    24)
        if [ "$VAR_C" = "delete" ]; then
            check=$(vzctl status "$VAR_B" | grep -i running)
            [ -n "$check" ] && vzctl stop "$VAR_B"
            vzctl destroy "$VAR_B"
            if [ ! -f /etc/vz/conf/"$VAR_B".conf ]; then
                echo "$(date) - VServer $VAR_B was deleted" >> "$LOGP/logs/$LOGF.txt"
            else
                echo "$(date) - VServer $VAR_B cant be deleted" >> "$LOGP/logs/$LOGF.txt"
            fi
            cd /etc/vz/conf
            rm -f "$VAR_B.conf.destroyed"
            [ -d /usr/vz/"$VAR_B" ] && rm -rf "/usr/vz/$VAR_B"
        fi

        if [ "$VAR_C" = "traffic" ]; then
            for ip in $(./tekbase 24 99 iplist); do
                traffic=$(iptables -nvx -L FORWARD | grep " $ip " | tr -s ' ' | cut -d' ' -f3 | awk '{sum+=$1} END {print sum}')
                if [ -n "$VAR_E" ]; then
                    wget --post-data "op=vtraffic&key=$VAR_B&rid=$VAR_E&vip=$ip&traffic=$traffic" -O - "$VAR_D/automated.php"
                else
                    wget --post-data "op=vtraffic&key=$VAR_B&vip=$ip&traffic=$traffic" -O - "$VAR_D/automated.php"
                fi
            done
            iptables -Z
            for ip in $(./tekbase 24 99 iplist); do
                iptables -D FORWARD -s "$ip"
                iptables -D FORWARD -d "$ip"
            done >/dev/null 2>&1
            for ip in $(./tekbase 24 99 iplist); do
                iptables -A FORWARD -s "$ip"
                iptables -A FORWARD -d "$ip"
            done >/dev/null 2>&1
        fi

        if [ "$VAR_C" = "iplist" ]; then
            vzlist -H -o ip
        fi
    ;;
    # File permission adjustments
    28)
        if [ "$VAR_F" = "startscr" ]; then
            cd /home/"$VAR_B"/"$VAR_C"/"$VAR_D" || exit
            for LINE in $(echo "$VAR_E" | tr ';' '\n'); do
                chmod 777 "$LINE"
                if [ -d "$LINE" ]; then
                    cd "$LINE" && chmod 544 * && cd - >/dev/null
                fi
            done
        else
            screen -A -m -d -S "${VAR_B}${VAR_D}-28" ./tekbase 28 "$VAR_B" "$VAR_C" "$VAR_D" "$VAR_E" "startscr"
        fi
    ;;

    # Copy and protect files
    29)
        if [ "$VAR_F" = "startscr" ]; then
            cd "$LOGP/cache" || exit
            mkdir -p "${VAR_B}${VAR_D}"
            chmod 0777 "${VAR_B}${VAR_D}"
            cd "/home/$VAR_B/$VAR_C/$VAR_D" || exit
            while IFS= read -r LINE; do
                if [ -d "$LINE" ]; then
                    cp -r --parents "$LINE" "$LOGP/cache/${VAR_B}${VAR_D}"
                elif [ -f "$LINE" ]; then
                    cp --parents "$LINE" "$LOGP/cache/${VAR_B}${VAR_D}"
                fi
            done <<< "$(echo "$VAR_E" | tr ';' '\n')"
            cd "$LOGP/cache/${VAR_B}${VAR_D}" || exit
            rm -f protect.md5
            cd "$LOGP/cache" || exit
            tar -cf "${VAR_B}${VAR_D}.tar" "${VAR_B}${VAR_D}"
            md5sum "${VAR_B}${VAR_D}.tar" | awk '{print $1}' > "${LOGP}/cache/${VAR_B}${VAR_D}/protect.md5"
            rm -f "${VAR_B}${VAR_D}.tar"
            cp "${LOGP}/cache/${VAR_B}${VAR_D}/protect.md5" "/home/$VAR_B/$VAR_C/$VAR_D/"
        else
            screen -A -m -d -S "${VAR_B}${VAR_D}-29" ./tekbase 29 "$VAR_B" "$VAR_C" "$VAR_D" "$VAR_E" "startscr"
        fi
    ;;

    # MD5 verification of protected files
    30)
        dowmd5=$(awk '{print $1}' "$LOGP/cache/${VAR_B}${VAR_D}/protect.md5")
        chkmd5=$(awk '{print $1}' "/home/$VAR_B/$VAR_C/$VAR_D/protect.md5")
        [ "$dowmd5" = "$chkmd5" ] && echo "ID1" || echo "ID2"
    ;;

    # Check disk usage for folder
    31)
        target="/home/$VAR_B"
        [ -n "$VAR_C" ] && target="$target/$VAR_C"
        [ -n "$VAR_D" ] && target="/home/$VAR_B/$VAR_D"
        [ -n "$VAR_E" ] && target="/home/$VAR_B/$VAR_E"
        [ -n "$VAR_F" ] && target="/home/$VAR_B/$VAR_F"
        du -s "$target" | awk '{print $1}'
    ;;

    # List running processes
    32)
        ps aux --sort pid | grep -v "ps aux" | grep -v "awk {printf" | grep -v "tekbase" | grep -v "perl -e use MIME::Base64" | awk '{
            printf($1"%TD%")
            printf($2"%TD%")
            printf($3"%TD%")
            printf($4"%TD%")
            for (i=11;i<=NF;i++) {
                printf("%s ", $i)
            }
            print "%TEND%"
        }'
    ;;

    # Rebind chroot & execute tekbase inside
    33)
        killall -w -q -u "$VAR_B"
        home=$(grep "$VAR_B" /etc/passwd | cut -d ":" -f6)
        rsync -a --link-dest=/home/chroot/ /home/chroot/ "$home/"
        grep "$VAR_B" /etc/passwd >> "$home/etc/passwd"
        grep "$VAR_B" /etc/shadow >> "$home/etc/shadow"
        cp /home/skripte/tekbase "$home/"
        chown "$VAR_B" "$home"
        mkdir -p "$home/proc"
        umount "$home/proc" >/dev/null 2>&1
        umount "$home/dev" >/dev/null 2>&1
        mount proc -t proc "$home/proc" >/dev/null 2>&1
        mount --bind /dev "$home/dev"
        rm -rf "$home$home"
        mkdir -p "$home$home"
        rmdir "$home$home"
        ln -s / "$home$home"
        chroot "$home" su "$VAR_B" -c "./tekbase 9 '$VAR_C' '$VAR_D' '$VAR_E' '$VAR_F' '$VAR_G' '$VAR_H' '$VAR_I' '$VAR_J'"
        echo "su $VAR_B -c \"./tekbase 9 '$VAR_C' '$VAR_D' '$VAR_E' '$VAR_F' '$VAR_G' '$VAR_H' '$VAR_I' '$VAR_J'\"" >> "$LOGP/logs/tekbase2"
    ;;

    # List Apache processes
    34)
        ps aux | grep -i apache | awk '{
            printf($1"%TD%")
            for (i=11;i<=NF;i++) {
                printf("%s ", $i)
            }
            print ""
        }'
    ;;

    # Report disk usage (soft quota)
    35)
        cd /home || exit
        for MEMBER in */; do
            MEMBER=${MEMBER%/}
            if [ -d "$MEMBER/$VAR_B" ]; then
                cd "/home/$MEMBER/$VAR_B" || continue
                for SERVER in */; do
                    SERVER=${SERVER%/}
                    quota=$(du -s | awk '{print $1}')
                    wget --post-data "op=softlimit&key=$VAR_C&member=$MEMBER&typ=$VAR_B&path=$SERVER&quota=$quota" -O - "$VAR_D/automated.php"
                done
            fi
        done
    ;;
esac

exit 0