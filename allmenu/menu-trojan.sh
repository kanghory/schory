#!/bin/bash
dateFromServer=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
biji=`date +"%Y-%m-%d" -d "$dateFromServer"`
###########- COLOR CODE -##############
NC="\e[0m"
COLOR1="\033[0;31m" 
###########- END COLOR CODE -##########

BURIQ () {
    curl -sS https://raw.githubusercontent.com/kanghory/schory/main/izin > /root/tmp
    data=( `cat /root/tmp | grep -E "^### " | awk '{print $2}'` )
    for user in "${data[@]}"
    do
    exp=( `grep -E "^### $user" "/root/tmp" | awk '{print $3}'` )
    d1=(`date -d "$exp" +%s`)
    d2=(`date -d "$biji" +%s`)
    exp2=$(( (d1 - d2) / 86400 ))
    if [[ "$exp2" -le "0" ]]; then
    echo $user > /etc/.$user.ini
    else
    rm -f /etc/.$user.ini > /dev/null 2>&1
    fi
    done
    rm -f /root/tmp
}

MYIP=$(curl -sS ipv4.icanhazip.com)
Name=$(curl -sS https://raw.githubusercontent.com/kanghory/schory/main/izin | grep $MYIP | awk '{print $2}')
echo $Name > /usr/local/etc/.$Name.ini
CekOne=$(cat /usr/local/etc/.$Name.ini)

Bloman () {
if [ -f "/etc/.$Name.ini" ]; then
CekTwo=$(cat /etc/.$Name.ini)
    if [ "$CekOne" = "$CekTwo" ]; then
        res="Expired"
    fi
else
res="Permission Accepted..."
fi
}

PERMISSION () {
    MYIP=$(curl -sS ipv4.icanhazip.com)
    IZIN=$(curl -sS https://raw.githubusercontent.com/kanghory/schory/main/izin | awk '{print $4}' | grep $MYIP)
    if [ "$MYIP" = "$IZIN" ]; then
    Bloman
    else
    res="Permission Denied!"
    fi
    BURIQ
}
red='\e[1;31m'
green='\e[1;32m'
NC='\e[0m'
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }

xxxcek_user_trojan_online() {
    LOG="/var/log/xray/access.log"
    LIMIT_DIR="/etc/klmpk/limit/trojan/ip"
    TMP="/tmp/cek_trojan_ip.tmp"
    NOW=$(date +%s)

    > $TMP

    # Ambil log 1 menit terakhir
    grep 'email:' "$LOG" | while read -r line; do
        ts=$(echo "$line" | awk '{print $1" "$2}' | cut -d. -f1)
        ep=$(date -d"${ts//\//-}" +%s 2>/dev/null)
        [[ -n $ep ]] && [[ $((NOW - ep)) -le 60 ]] || continue

        user=$(echo "$line" | awk -F'email: ' '{print $2}')
        ip=$(echo "$line" | grep -oP 'from (\K[^ ]+)' | sed 's/^tcp://;s/^udp://')
        echo "$user $ip"
    done | sort -u > $TMP

    echo -e "\e[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "                            CEK TROJAN ACCOUNT"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "%-15s %-12s %-12s %-s\n" "USERNAME" "LIMIT IP" "JUMLAH IP" "IP LOGIN"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for user in $(cut -d' ' -f1 "$TMP" | sort -u); do
        iplist=$(grep "^$user " "$TMP" | awk '{print $2}' | paste -sd ", ")
        jumlah=$(echo "$iplist" | tr ',' '\n' | wc -l)
        limit="∞"
        [[ -f "$LIMIT_DIR/$user" ]] && limit=$(cat "$LIMIT_DIR/$user")
        printf "%-15s %-12s %-12s %-s\n" "$user" "$limit" "$jumlah" "$iplist"
    done

    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "                 Selamat menggunakan script by Andbbb"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

function deltrojan(){
    clear
NUMBER_OF_CLIENTS=$(grep -c -E "^#! " "/etc/xray/config.json")
if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1│${NC} ${COLBG1}           • DELETE TROJAN USER •              ${NC} $COLOR1│$NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1│${NC}  • You Dont have any existing clients!"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}" 
echo -e "$COLOR1┌────────────────────── BY ───────────────────────┐${NC}"
echo -e "$COLOR1│${NC}                • KANGHORY •                 $COLOR1│$NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}" 
echo ""
read -n 1 -s -r -p "   Press any key to back on menu"
menu-trojan
fi
clear
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1│${NC} ${COLBG1}           • DELETE TROJAN USER •              ${NC} $COLOR1│$NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
grep -E "^#! " "/etc/xray/config.json" | cut -d ' ' -f 2-3 | column -t | sort | uniq | nl
echo -e "$COLOR1│${NC}"
echo -e "$COLOR1│${NC}  • [NOTE] Press any key to back on menu"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
echo -e "$COLOR1───────────────────────────────────────────────────${NC}"
read -rp "   Input Username : " user
if [ -z $user ]; then
menu-trojan
else
exp=$(grep -wE "^#! $user" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)
sed -i "/^#! $user $exp/,/^},{/d" /etc/xray/config.json
systemctl restart xray > /dev/null 2>&1
clear
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1│${NC} ${COLBG1}           • DELETE TROJAN USER •              ${NC} $COLOR1│$NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1│${NC}   • Accound Delete Successfully"
echo -e "$COLOR1│${NC}"
echo -e "$COLOR1│${NC}   • Client Name : $user"
echo -e "$COLOR1│${NC}   • Expired On  : $exp"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}" 
echo -e "$COLOR1┌────────────────────── BY ───────────────────────┐${NC}"
echo -e "$COLOR1│${NC}                • KANGHORY •            $COLOR1│$NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}" 
echo ""
read -n 1 -s -r -p "   Press any key to back on menu"
menu-trojan
fi
}

function renewtrojan(){
clear
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1│${NC} ${COLBG1}            • RENEW TROJAN USER •              ${NC} $COLOR1│$NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
NUMBER_OF_CLIENTS=$(grep -c -E "^#! " "/etc/xray/config.json")
if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
echo -e "$COLOR1│${NC}  • You have no existing clients!"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}" 
echo -e "$COLOR1┌────────────────────── BY ───────────────────────┐${NC}"
echo -e "$COLOR1│${NC}                • KANGHORY •            $COLOR1│$NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}" 
echo ""
read -n 1 -s -r -p "   Press any key to back on menu"
menu-trojan
fi
clear
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1│${NC} ${COLBG1}            • RENEW TROJAN USER •              ${NC} $COLOR1│$NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
grep -E "^#! " "/etc/xray/config.json" | cut -d ' ' -f 2-3 | column -t | sort | uniq | nl
echo -e "$COLOR1│${NC}"
echo -e "$COLOR1│${NC}  • [NOTE] Press any key to back on menu"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}" 
echo -e "$COLOR1┌────────────────────── BY ───────────────────────┐${NC}"
echo -e "$COLOR1│${NC}                 • KANGHORY •                 $COLOR1│$NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}" 
echo -e "$COLOR1───────────────────────────────────────────────────${NC}"
read -rp "   Input Username : " user
if [ -z $user ]; then
menu-trojan
else
read -p "   Expired (days): " masaaktif
if [ -z $masaaktif ]; then
masaaktif="1"
fi
exp=$(grep -E "^#! $user" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)
now=$(date +%Y-%m-%d)
d1=$(date -d "$exp" +%s)
d2=$(date -d "$now" +%s)
exp2=$(( (d1 - d2) / 86400 ))
exp3=$(($exp2 + $masaaktif))
exp4=`date -d "$exp3 days" +"%Y-%m-%d"`
sed -i "/#! $user/c\#! $user $exp4" /etc/xray/config.json
systemctl restart xray > /dev/null 2>&1
clear
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1│${NC} ${COLBG1}            • RENEW TROJAN USER •              ${NC} $COLOR1│$NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1│${NC}   [INFO]  $user Account Renewed Successfully"
echo -e "$COLOR1│${NC}   "
echo -e "$COLOR1│${NC}   Client Name : $user"
echo -e "$COLOR1│${NC}   Days Added  : $masaaktif Days"
echo -e "$COLOR1│${NC}   Expired On  : $exp4"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}" 
echo -e "$COLOR1┌────────────────────── BY ───────────────────────┐${NC}"
echo -e "$COLOR1│${NC}                • KANGHORY •                 $COLOR1│$NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}" 
echo ""
read -n 1 -s -r -p "   Press any key to back on menu"
menu-trojan
fi
}

function addtrojan(){
source /var/lib/ssnvpn-pro/ipvps.conf
domain=$(cat /etc/xray/domain)
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1│${NC} ${COLBG1}           • CREATE TROJAN USER •              ${NC} $COLOR1│$NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
tr="$(cat ~/log-install.txt | grep -w "Trojan WS " | cut -d: -f2 | sed 's/ //g')"

until [[ $user =~ ^[a-zA-Z0-9_]+$ && ${user_EXISTS} == '0' ]]; do
  read -rp "   Input Username : " -e user
  [[ -z $user ]] && {
    echo -e "$COLOR1│${NC}   [Error] Username cannot be empty "
    echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}" 
    echo -e "$COLOR1┌────────────────────── BY ───────────────────────┐${NC}"
    echo -e "$COLOR1│${NC}                 • KANGHORY •                 $COLOR1│$NC"
    echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}" 
    read -n 1 -s -r -p "   Press any key to back on menu"
    menu
  }
  user_EXISTS=$(grep -w $user /etc/xray/config.json | wc -l)
  [[ ${user_EXISTS} == '1' ]] && {
    clear
    echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
    echo -e "$COLOR1│${NC} ${COLBG1}           • CREATE TROJAN USER •              ${NC} $COLOR1│$NC"
    echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
    echo -e "$COLOR1│${NC}  Please choose another name."
    echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}" 
    echo -e "$COLOR1┌────────────────────── BY ───────────────────────┐${NC}"
    echo -e "$COLOR1│${NC}                • KANGHORY •                 $COLOR1│$NC"
    echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}" 
    read -n 1 -s -r -p "   Press any key to back on menu"
    trojan-menu
  }
done

uuid=$(cat /proc/sys/kernel/random/uuid)
read -p "   Expired (days): " masaaktif
read -p "   Limit IP        : " limitip
exp=$(date -d "$masaaktif days" +"%Y-%m-%d")

# Tambah konfigurasi ke Xray
sed -i '/#trojanws$/a\#! '"$user $exp"'\
},{"password": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json
sed -i '/#trojangrpc$/a\#! '"$user $exp"'\
},{"password": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json

# Simpan limit IP
mkdir -p /etc/klmpk/limit/trojan/ip
echo "$limitip" > /etc/klmpk/limit/trojan/ip/$user

# Restart layanan
systemctl restart xray

# Generate link
trojanlink="trojan://${uuid}@bug.com:${tr}?path=%2Ftrojan-ws&security=tls&host=${domain}&type=ws&sni=${domain}#${user}"
trojanlink1="trojan://${uuid}@${domain}:${tr}?mode=gun&security=tls&type=grpc&serviceName=trojan-grpc&sni=${domain}#${user}"

# Tampilkan hasil akun
clear
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1│${NC} ${COLBG1}           • TROJAN ACCOUNT CREATED •          ${NC} $COLOR1│$NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
echo -e "Username      : $user"
echo -e "Domain        : $domain"
echo -e "Port WS       : $tr"
echo -e "Port gRPC     : $tr"
echo -e "UUID          : $uuid"
echo -e "Limit IP      : $limitip IP"
echo -e "Created       : $(date -d "0 days" +"%Y-%m-%d")"
echo -e "Expired       : $exp"
echo -e "-----------------------------------------------------"
echo -e "Trojan WS     :"
echo -e "$trojanlink"
echo -e "-----------------------------------------------------"
echo -e "Trojan gRPC   :"
echo -e "$trojanlink1"
echo -e "-----------------------------------------------------"

# QR Code WS (opsional)
if command -v qrencode &> /dev/null; then
    echo -e "QR Code (Trojan WS):"
    echo "$trojanlink" | qrencode -t ANSIUTF8
else
    echo -e "QR Code: qrencode tidak tersedia"
fi

echo -e "$COLOR1┌────────────────────── BY ───────────────────────┐${NC}"
echo -e "$COLOR1│${NC}                • KANGHORY •                 $COLOR1│$NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
echo
read -n 1 -s -r -p "   Press any key to back on menu"
menu-trojan
}


clear
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1│${NC} ${COLBG1}              • TROJAN PANEL MENU •            ${NC} $COLOR1│$NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
echo -e " $COLOR1┌───────────────────────────────────────────────┐${NC}"
echo -e " $COLOR1│$NC   ${COLOR1}[01]${NC} • ADD TROJAN    ${COLOR1}[03]${NC} • DELETE TROJAN${NC}   $COLOR1│$NC"
echo -e " $COLOR1│$NC   ${COLOR1}[02]${NC} • RENEW TROJAN${NC}  ${COLOR1}[04]${NC} • USER ONLINE     $COLOR1│$NC"
echo -e " $COLOR1│$NC   ${COLOR1}[05]${NC} • MONITOR LIMIT IP${NC}  ${COLOR1}[06]${NC} • HEMMM     $COLOR1│$NC"
echo -e " $COLOR1│$NC                                              ${NC} $COLOR1│$NC"
echo -e " $COLOR1│$NC   ${COLOR1}[00]${NC} • GO BACK${NC}                              $COLOR1│$NC"
echo -e " $COLOR1└───────────────────────────────────────────────┘${NC}"
echo -e "$COLOR1┌────────────────────── BY ───────────────────────┐${NC}"
echo -e "$COLOR1│${NC}                • KANGHORY •                 $COLOR1│$NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}" 
echo -e ""
read -p " Select menu :  "  opt
echo -e ""
case $opt in
01 | 1) clear ; addtrojan ;;
02 | 2) clear ; renewtrojan ;;
03 | 3) clear ; deltrojan ;;
04 | 4) clear ; cek-user-online-trojan ;;
05 | 5) clear ; monitor-limit-ip-trojan ;;
06 | 6) clear ; hemmm ;;
00 | 0) clear ; menu ;;
*) clear ; menu-trojan ;;
esac

       
