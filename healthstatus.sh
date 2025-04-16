#!/bin/bash

# TekLabs TekBase - Health Status Script
# Maintainer: Christian Frankenstein (TekLab)
# Website: teklab.de / teklab.net

VAR_A="$1"
VAR_C="$3"

# Setup paths and logging
LOGP=$(cd "$(dirname "$0")" && pwd)
LOGF=$(date +"%Y_%m")
LOGFILE="$LOGP/logs/$LOGF.txt"

mkdir -p "$LOGP/logs"
chmod 0777 "$LOGP/logs"
touch "$LOGFILE"
chmod 0666 "$LOGFILE"

log_msg() {
    echo "$(date) - $1" >> "$LOGFILE"
}

checkpasswd() {
    chkpwd="$1"
    originalpw=$(grep -w "root" /etc/shadow | cut -d: -f2)
    algo=$(echo "$originalpw" | cut -d'$' -f2)
    salt=$(echo "$originalpw" | cut -d'$' -f3)

    export chkpwd algo salt
    genpw=$(perl -le 'print crypt("$ENV{chkpwd}","\$$ENV{algo}\$$ENV{salt}\$")')

    if [ "$genpw" == "$originalpw" ]; then
        echo "error"
    else
        echo "ok"
    fi
}

if [ "$VAR_A" = "cpu" ]; then
    tekresult=""
    cpucores=$(grep -c ^processor /proc/cpuinfo)
    for ((i=0; i<cpucores; i++)); do
        totallast[$i]=0
        busylast[$i]=0
    done

    counter=0
    while [ $counter -lt 2 ]; do
        for ((i=0; i<cpucores; i++)); do
            cpudata=$(grep ^"cpu$i" /proc/stat)
            busyticks=$(echo $cpudata | awk '{print $2+$3+$4+$7+$8}')
            totalticks=$(echo $cpudata | awk '{print $2+$3+$4+$5+$6+$7+$8}')

            let "busy_1000=1000*($busyticks-${busylast[$i]})/($totalticks-${totallast[$i]})"
            let "busyfull=$busy_1000/10"
            let "busytick=$busy_1000"

            if [ $counter -eq 1 ]; then
                tekresult+="$i,$busyfull.$busytick{TEKEND}"
            fi

            totallast[$i]=$totalticks
            busylast[$i]=$busyticks
        done
        ((counter++))
        sleep 0.5
    done

    cpuname=$(grep 'model name' /proc/cpuinfo | sed -e 's/model name.*: //' | uniq)
    echo "$cpuname{TEKEND}$tekresult"
fi

if [ "$VAR_A" = "dedicated" ]; then
    memall=$(free -k | grep -i "mem" | awk '{print $2,$3,$4,$6,$7}')
    memtotal=$(echo "$memall" | awk '{print $1}')
    memfree=$(echo "$memall" | awk '{print $3+$5+$6}')
    memtype=$(dmidecode --type memory 2>/dev/null | grep -i "Type:\|Size:\|Speed:" | grep -v "Error\|Clock" |
              sed -E 's/^[ \t]*//' | sed -e 's/Type: /"type":"/g' -e 's/Speed: /"speed":"/g' -e 's/Size: /"size":"/g' |
              sed 's/$/"/g' | tr '\n' ',')

    hddlist=$(lsblk | grep -E '^[hsm]' | grep -v "─" | awk '{print $1}')
    hdds=""
    for hdd in $hddlist; do
        hddtyp=$(cat "/sys/block/$hdd/queue/rotational" | sed 's/0/ssd/;s/1/hdd/')
        hddtotal=$(lsblk | grep -i "$hdd" | awk 'NR==1{print $4}')
        hddswap=$(lsblk | grep -i "$hdd" | grep -i "SWAP" | awk '{print $4}')
        hddstat=$(smartctl -H /dev/"$hdd" 2>/dev/null | grep -i "overall-health" | awk -F': ' '{print $2}')
        hddtemp=$(hddtemp -u C /dev/"$hdd" 2>/dev/null | sed 's/°C//g' |
                  awk -v smart="$hddstat" -v htyp="$hddtyp" -v htotal="$hddtotal" -v hswap="$hddswap" -F': ' '{
                      print "{\"hdd\":\""$1"\",\"name\":\""$2"\",\"type\":\""htyp"\",\"total\":\""htotal"\",\"swap\":\""hswap"\",\"temp\":\""$3"\",\"status\":\""smart"\",\"parts\":["
                  }')

        [ -z "$hddtemp" ] && hddtemp="{\"hdd\":\"$hdd\",\"name\":\"$hdd\",\"type\":\"$hddtyp\",\"total\":\"$hddtotal\",\"swap\":\"$hddswap\",\"temp\":\"-\",\"status\":\"$hddstat\",\"parts\":["
        hddpart=$(df -k | grep -i "/dev/$hdd" | grep -v "tmpfs" |
                  awk '{print "{\"part\":\""$1"\",\"total\":\""$2"\",\"used\":\""$3"\",\"mount\":\""$6"\"}"}' | tr "\n" ",")

        [ -z "$hdds" ] && hdds="$hddtemp$hddpart]}" || hdds="$hdds,$hddtemp$hddpart]}"
    done

    timeformat=$(mpstat | grep -i PM)
    if [ -z "$timeformat" ]; then
        cpuperc=$(mpstat -P ALL | awk 'NR>4 {print "\""$2+1"\":\""$3"\""}' | tr "\n" ",")
    else
        cpuperc=$(mpstat -P ALL | awk 'NR>4 {print "\""$3+1"\":\""$4"\""}' | tr "\n" ",")
    fi

    cpuinfo=$(dmidecode --type processor 2>/dev/null | grep -i "Version:\|Max Speed:" |
              sed -e 's/Version: /"name":"/g' -e 's/Max Speed: /"speed":"/g' | sed -E 's/^[ \t]*//' |
              sed 's/[[:space:]]\+/ /g' | sed 's/$/"/g' | tr "\n" "," | sed 's/ "/"/g')
    [ -z "$cpuinfo" ] && cpuinfo=$(grep -m 1 -i "model name" /proc/cpuinfo | sed -e 's/model name/"name":"/g' -e 's/^[ \t]*//' -e 's/$/"/g' | tr "\n" ",")

    cputemp=$(sensors 2>/dev/null | grep -i "temp1:" | awk '{print "\"temp\":\""$2"\",\"critic\":\""$5"\""}' | sed 's/[+°C)]//g' | uniq)

    ipv4=$(ip -4 addr | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "^127" | awk '{print "\""NR"\":\""$1"\""}' | tr "\n" ",")

    iface=$(ip route | awk '/default/ {print $5}' | head -n1)
    trafficdays=$(vnstat -i "$iface" -d | grep -vE "eth|day|estimated|-" |
                  sed -E 's/(KiB|MiB|GiB|TiB)/\U&/g;s/\//./g' |
                  awk 'NR>2 {print "{\"date\":\""$1"\",\"rx\":\""$2,$3"\",\"tx\":\""$5,$6"\"}"}' | tr "\n" ",")

    trafficmonths=$(vnstat -i "$iface" -m | grep -vE "eth|month|estimated|-" |
                    sed -E 's/(KiB|MiB|GiB|TiB)/\U&/g;s/\//./g' |
                    awk 'NR>2 {print "{\"date\":\""$1,$2"\",\"rx\":\""$3,$4"\",\"tx\":\""$6,$7"\"}"}' | tr "\n" ",")

    echo "{\"cpu\":{$cpuinfo\"cores\":{$cpuperc},$cputemp},\"ram\":{$memtype\"total\":\"$memtotal\",\"free\":\"$memfree\"},\"hdds\":[$hdds],\"ipv4\":{$ipv4},\"traffic\":{\"daily\":[$trafficdays],\"monthly\":[$trafficmonths]},\"rootpw\":\"$(checkpasswd "$VAR_C")\"}" |
        sed -E 's/,}/}/g;s/,]/]/g'
fi

exit 0