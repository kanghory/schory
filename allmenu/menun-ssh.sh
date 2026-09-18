BIBlack='\033[1;90m'      # Black
BIRed='\033[1;91m'        # Red
BIGreen='\033[1;92m'      # Green
BIYellow='\033[1;93m'     # Yellow
BIBlue='\033[1;94m'       # Blue
BIPurple='\033[1;95m'     # Purple
BICyan='\033[1;96m'       # Cyan
BIWhite='\033[1;97m'      # White
UWhite='\033[4;37m'       # White
On_IPurple='\033[0;105m'  #
On_IRed='\033[0;101m'
IBlack='\033[0;90m'       # Black
IRed='\033[0;91m'         # Red
IGreen='\033[0;92m'       # Green
IYellow='\033[0;93m'      # Yellow
IBlue='\033[0;94m'        # Blue
IPurple='\033[0;95m'      # Purple
ICyan='\033[0;96m'        # Cyan
IWhite='\033[0;97m'       # White
NC='\e[0m'
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export LIGHT='\033[0;37m'
export NC='\033[0m'
export EROR="[${RED} EROR ${NC}]"
export INFO="[${YELLOW} INFO ${NC}]"
export OKEY="[${GREEN} OKEY ${NC}]"
export PENDING="[${YELLOW} PENDING ${NC}]"
export SEND="[${YELLOW} SEND ${NC}]"
export RECEIVE="[${YELLOW} RECEIVE ${NC}]"
export BOLD="\e[1m"
export WARNING="${RED}\e[5m"
export UNDERLINE="\e[4m"
export Server_URL="raw.githubusercontent.com/Zeastore/test/main"
export Server1_URL="raw.githubusercontent.com/Zeastore/limit/main"
export Server_Port="443"
export Server_IP="underfined"
export Script_Mode="Stable"
export Auther=".geovpn"
if [ "${EUID}" -ne 0 ]; then
echo -e "${EROR} Please Run This Script As Root User !"
exit 1
fi
export IP=$( curl -s https://ipinfo.io/ip/ )
export NETWORK_IFACE="$(ip route show to default | awk '{print $5}')"
clear
function del() {
    # Warna
    local CYAN='\033[1;96m'
    local LIGHT='\033[1;97m'
    local NC='\033[0m'
    local YELLOW='\033[1;93m'
    local RED='\033[1;91m'
    local GREEN='\033[1;92m'

    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "\E[0;41;36m               DELETE USER                \E[0m"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " [1] Hapus Single User"
    echo -e " [2] Hapus Multi User (Range: user1-5 ATAU Koma: Gus,Hudi,joko)"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p " Pilih Mode [1/2] : " mode_del

    local users_to_del=()

    case $mode_del in
        1)
            read -p " Username SSH to Delete : " Pengguna
            [[ -n "$Pengguna" ]] && users_to_del+=("$Pengguna")
            ;;
        2)
            read -p " Format Multi Delete : " multi_input
            
            # FIX REGEX: Range format (contoh: user1-5 atau zxl1241-1245)
            if [[ "$multi_input" =~ ^([a-zA-Z_-]*[a-zA-Z_-])?([0-9]+)-([0-9]+)$ ]]; then
                prefix="${BASH_REMATCH[1]}"
                start_str="${BASH_REMATCH[2]}"
                end_str="${BASH_REMATCH[3]}"

                # Konversi ke integer basis 10
                start=$((10#$start_str))
                end=$((10#$end_str))

                if (( start > end )); then
                    echo -e "\n${RED}[ERROR]${NC} Angka awal ($start) tidak boleh lebih besar dari angka akhir ($end)!"
                    read -n 1 -s -r -p "Tekan ENTER untuk kembali..."
                    [[ -f /usr/bin/menu ]] && /usr/bin/menu || return
                fi

                # Jaga panjang digit (jika ada angka berkepala nol misal 01-05)
                num_len=${#start_str}

                for (( i=start; i<=end; i++ )); do
                    formatted_num=$(printf "%0${num_len}d" "$i")
                    users_to_del+=("${prefix}${formatted_num}")
                done

            # Comma format (contoh: Gus,Hudi,joko)
            elif [[ "$multi_input" == *","* ]]; then
                IFS=',' read -ra ADDR <<< "$multi_input"
                for item in "${ADDR[@]}"; do
                    clean_user=$(echo "$item" | xargs)
                    [[ -n "$clean_user" ]] && users_to_del+=("$clean_user")
                done
            else
                # Single input fallback
                clean_user=$(echo "$multi_input" | xargs)
                [[ -n "$clean_user" ]] && users_to_del+=("$clean_user")
            fi
            ;;
        *)
            echo -e "\n${RED}[ERROR]${NC} Pilihan tidak valid."
            read -n 1 -s -r -p "Tekan ENTER untuk kembali..."
            [[ -f /usr/bin/menu ]] && /usr/bin/menu || return
            ;;
    esac

    if [[ ${#users_to_del[@]} -eq 0 ]]; then
        echo -e "\n${RED}Failure: Username cannot be empty.${NC}"
    else
        local success_count=0
        local fail_count=0

        echo -e "\n${CYAN}──────────────────────────────────────────${NC}"
        for user in "${users_to_del[@]}"; do
            if getent passwd "$user" > /dev/null 2>&1; then
                pkill -KILL -u "$user" 2>/dev/null
                userdel "$user" > /dev/null 2>&1

                limit_file="/etc/klmpk/limit/ssh/ip/$user"
                [[ -f "$limit_file" ]] && rm -f "$limit_file"

                log_file="/etc/klmpk/log-ssh/$user.txt"
                [[ -f "$log_file" ]] && rm -f "$log_file"

                echo -e "User \033[1;33m$user\033[0m berhasil dihapus beserta Limit IP & Log."
                ((success_count++))
            else
                echo -e "Failure: User \033[1;31m$user\033[0m does not exist."
                ((fail_count++))
            fi
        done
        echo -e "${CYAN}──────────────────────────────────────────${NC}"
        echo -e "${GREEN}TOTAL KETERANGAN PENGHAPUSAN:${NC}"
        echo -e " Real User Berhasil Dihapus : ${YELLOW}$success_count${NC} user"
        echo -e " User Gagal / Tidak Ada     : ${RED}$fail_count${NC} user"
        echo -e "${CYAN}──────────────────────────────────────────${NC}"
    fi

    echo ""
    read -n 1 -s -r -p "Tekan ENTER untuk kembali ke menu..."
    
    # Kembali ke menu utama, jika tidak ada cukup keluar dari function
    if declare -f menu > /dev/null; then
        menu
    elif [[ -f /usr/bin/menu ]]; then
        /usr/bin/menu
    else
        return
    fi
}
function autodel(){
clear
hariini=$(date +%d-%m-%Y)
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;41;36m               AUTO DELETE                \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo "Thank you for removing the EXPIRED USERS"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

cat /etc/shadow | cut -d: -f1,8 | sed /:$/d > /tmp/expirelist.txt
totalaccounts=$(cat /tmp/expirelist.txt | wc -l)

for ((i=1; i<=totalaccounts; i++)); do
    tuserval=$(head -n $i /tmp/expirelist.txt | tail -n 1)
    username=$(echo "$tuserval" | cut -f1 -d:)
    userexp=$(echo "$tuserval" | cut -f2 -d:)
    userexpireinseconds=$(( userexp * 86400 ))
    tglexp=$(date -d @$userexpireinseconds)
    tgl=$(echo $tglexp | awk -F" " '{print $3}')
    
    while [[ ${#tgl} -lt 2 ]]; do tgl="0${tgl}"; done

    # Username dengan padding hanya untuk ditampilkan
    username_pad="$username"
    while [[ ${#username_pad} -lt 15 ]]; do username_pad="$username_pad "; done

    bulantahun=$(echo $tglexp | awk -F" " '{print $2,$6}')
    echo "echo \"Expired- User : $username_pad Expire at : $tgl $bulantahun\"" >> /usr/local/bin/alluser

    todaystime=$(date +%s)
    if [[ $userexpireinseconds -ge $todaystime ]]; then
        continue
    else
        echo "echo \"Expired- Username : $username_pad are expired at: $tgl $bulantahun and removed : $hariini \"" >> /usr/local/bin/deleteduser
        echo "Username $username_pad that are expired at $tgl $bulantahun removed from the VPS $hariini"

        # Hapus user dari sistem
        userdel "$username"

        # Hapus limit IP
        limit_ip_file="/etc/klmpk/limit/ssh/ip/$username"
        [[ -f "$limit_ip_file" ]] && rm -f "$limit_ip_file"

    fi
done

echo " "
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
read -n 1 -s -r -p "Press any key to back on menu"
menu
}
function ceklim(){
clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;41;36m         CEK USER MULTI SSH        \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
if [ -e "/root/log-limit.txt" ]; then
echo "User Who Violate The Maximum Limit";
echo "Time - Username - Number of Multilogin"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
cat /root/log-limit.txt
else
echo " No user has committed a violation"
echo " "
echo " or"
echo " "
echo " The user-limit script not been executed."
fi
echo " ";
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo " ";
read -n 1 -s -r -p "Press any key to back on menu"
menu
}
function cek(){
if [ -e "/var/log/auth.log" ]; then
LOG="/var/log/auth.log";
fi
if [ -e "/var/log/secure" ]; then
LOG="/var/log/secure";
fi
data=( `ps aux | grep -i dropbear | awk '{print $2}'`);
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;41;36m         Dropbear User Login       \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo "ID  |  Username  |  IP Address";
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
cat $LOG | grep -i dropbear | grep -i "Password auth succeeded" > /tmp/login-db.txt;
for PID in "${data[@]}"
do
cat /tmp/login-db.txt | grep "dropbear\[$PID\]" > /tmp/login-db-pid.txt;
NUM=`cat /tmp/login-db-pid.txt | wc -l`;
USER=`cat /tmp/login-db-pid.txt | awk '{print $10}'`;
IP=`cat /tmp/login-db-pid.txt | awk '{print $12}'`;
if [ $NUM -eq 1 ]; then
echo "$PID - $USER - $IP";
fi
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
done
echo " "
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;41;36m          OpenSSH User Login       \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo "ID  |  Username  |  IP Address";
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
cat $LOG | grep -i sshd | grep -i "Accepted password for" > /tmp/login-db.txt
data=( `ps aux | grep "\[priv\]" | sort -k 72 | awk '{print $2}'`);
for PID in "${data[@]}"
do
cat /tmp/login-db.txt | grep "sshd\[$PID\]" > /tmp/login-db-pid.txt;
NUM=`cat /tmp/login-db-pid.txt | wc -l`;
USER=`cat /tmp/login-db-pid.txt | awk '{print $9}'`;
IP=`cat /tmp/login-db-pid.txt | awk '{print $11}'`;
if [ $NUM -eq 1 ]; then
echo "$PID - $USER - $IP";
fi
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
done
if [ -f "/etc/openvpn/server/openvpn-tcp.log" ]; then
echo " "
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;41;36m          OpenVPN TCP User Login         \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo "Username  |  IP Address  |  Connected Since";
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
cat /etc/openvpn/server/openvpn-tcp.log | grep -w "^CLIENT_LIST" | cut -d ',' -f 2,3,8 | sed -e 's/,/      /g' > /tmp/vpn-login-tcp.txt
cat /tmp/vpn-login-tcp.txt
fi
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
if [ -f "/etc/openvpn/server/openvpn-udp.log" ]; then
echo " "
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;41;36m          OpenVPN UDP User Login         \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo "Username  |  IP Address  |  Connected Since";
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
cat /etc/openvpn/server/openvpn-udp.log | grep -w "^CLIENT_LIST" | cut -d ',' -f 2,3,8 | sed -e 's/,/      /g' > /tmp/vpn-login-udp.txt
cat /tmp/vpn-login-udp.txt
fi
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo "";
rm -f /tmp/login-db-pid.txt
rm -f /tmp/login-db.txt
rm -f /tmp/vpn-login-tcp.txt
rm -f /tmp/vpn-login-udp.txt
read -n 1 -s -r -p "Press any key to back on menu"
menu
}
function member(){
clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;41;36m                 MEMBER SSH               \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo "USERNAME          EXP DATE          STATUS"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
while read expired
do
AKUN="$(echo $expired | cut -d: -f1)"
ID="$(echo $expired | grep -v nobody | cut -d: -f3)"
exp="$(chage -l $AKUN | grep "Account expires" | awk -F": " '{print $2}')"
status="$(passwd -S $AKUN | awk '{print $2}' )"
if [[ $ID -ge 1000 ]]; then
if [[ "$status" = "L" ]]; then
printf "%-17s %2s %-17s %2s \n" "$AKUN" "$exp     " "LOCKED${NORMAL}"
else
printf "%-17s %2s %-17s %2s \n" "$AKUN" "$exp     " "UNLOCKED${NORMAL}"
fi
fi
done < /etc/passwd
JUMLAH="$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | wc -l)"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo "Account number: $JUMLAH user"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
read -n 1 -s -r -p "Press any key to back on menu"
menu
}
function extend_ssh() {
    clear
    echo -e "\e[36m╔════════════════════════════════════════╗"
    echo -e "║      PERPANJANG / RESET MASA AKTIF     ║"
    echo -e "╚════════════════════════════════════════╝\e[0m"
    echo -e "\nPilih metode:"
    echo -e "  \e[32m1.\e[0m Perpanjang dari tanggal expired lama"
    echo -e "  \e[33m2.\e[0m Reset expired dari hari ini"
    read -p "Pilih opsi (1/2): " opsi

    if [[ "$opsi" != "1" && "$opsi" != "2" ]]; then
        echo -e "\e[31mOpsi tidak valid!\e[0m"
        return
    fi

    read -p "Masukkan username SSH : " user

    if ! id "$user" &>/dev/null; then
        echo -e "\e[31mUser $user tidak ditemukan!\e[0m"
        return
    fi

    read -p "Set masa aktif (dalam hari): " extend

    case $opsi in
        1)
            exp_old=$(chage -l "$user" | grep "Account expires" | cut -d: -f2 | xargs)
            if [[ "$exp_old" == "never" ]]; then
                base_date=$(date +%Y-%m-%d)
            else
                base_date=$(date -d "$exp_old" +%Y-%m-%d)
            fi
            new_exp=$(date -d "$base_date +$extend days" +%Y-%m-%d)
            mode="Perpanjang dari expired lama"
            ;;
        2)
            new_exp=$(date -d "+$extend days" +%Y-%m-%d)
            mode="Reset dari hari ini"
            ;;
    esac

    chage -E "$new_exp" "$user"

    # Ambil limit IP
    ip_limit_file="/etc/klmpk/limit/ssh/ip/$user"
    ip_limit="Tidak dibatasi"
    [[ -f "$ip_limit_file" ]] && ip_limit=$(cat "$ip_limit_file")

    # Ambil domain
    domain="Tidak ditemukan"
    [[ -f /etc/xray/domain ]] && domain=$(cat /etc/xray/domain)

    # Ambil password dari log
    pass="Tidak diketahui"
    log_file="/etc/klmpk/log-ssh/${user}.txt"
    if [[ -f "$log_file" ]]; then
        pass=$(grep -i "Password" "$log_file" | awk -F ':' '{print $2}' | xargs)
    fi

    echo -e "\n\e[36m╔═══════════════════════════════"
    echo -e "║         HASIL $mode           "
    echo -e "╠═══════════════════════════════"
    printf  "║ %-20s : %-16s \n" "Username" "$user"
    printf  "║ %-20s : %-16s \n" "Password" "$pass"
    printf  "║ %-20s : %-16s \n" "Domain" "$domain"
    printf  "║ %-20s : %-16s \n" "Hari ditambahkan" "$extend hari"
    printf  "║ %-20s : %-16s \n" "Masa aktif akhir" "$new_exp"
    printf  "║ %-20s : %-16s \n" "Limit IP Login" "$ip_limit"
    echo -e "╚═══════════════════════════════\e[0m"

    read -n 1 -s -r -p $'\nTekan Enter untuk kembali ke menu...'
    menu
}
function ubahpass_ssh() {
  clear
  echo -e "\e[0;36m┌────────────────────────────────────────────┐\e[0m"
  echo -e "\e[0;36m│         UBAH PASSWORD AKUN SSH             │\e[0m"
  echo -e "\e[0;36m└────────────────────────────────────────────┘\e[0m"
  read -p "Masukkan username SSH : " user

  if id "$user" &>/dev/null; then
    read -s -p "Masukkan password baru : " newpass
    echo
    read -s -p "Ulangi password baru   : " repass
    echo

    if [[ "$newpass" != "$repass" ]]; then
      echo -e "\n\e[31mGagal: Password tidak cocok.\e[0m"
      return
    fi

    echo -e "$user:$newpass" | chpasswd
    echo -e "\n\e[32mBerhasil: Password untuk user '$user' telah diubah.\e[0m"
  else
    echo -e "\n\e[31mGagal: User '$user' tidak ditemukan.\e[0m"
  fi
}
function ceklimit() {
clear
touch /root/.system
echo -e "  ${y}───────────────────────────────────────${NC}"
echo -e "            ️ ${g}USER LOGIN SSH${NC}  ️"
echo -e "  ${y}───────────────────────────────────────${NC}"
echo -e "    ${ungu} LOGIN IP    LIMIT IP    USERNAME ${NC}"
mulog=$(cekssh)
data=( `cat /etc/passwd | grep home | cut -d ' ' -f 1 | cut -d : -f 1`);
for user in "${data[@]}"
do
cekcek=$(echo -e "$mulog" | grep $user | wc -l)
if [[ $cekcek -gt 0 ]]; then
iplimit=$(cat /etc/klmpk/limit/ssh/ip/$user)
printf "  %-13s %-7s %-8s %2s\n" "     ${cekcek} IP        ${iplimit} IP      ${user}"
echo "slot" >> /root/.system
else
echo > /dev/null
fi
echo send_log > /dev/null
sleep 0.1
done
aktif=$(cat /root/.system | wc -l)
echo -e "  ${y}───────────────────────────────────────${NC}"
echo -e "            $aktif User Online"
echo -e "  ${y}───────────────────────────────────────${NC}"
sed -i "d" /root/.system
read -n 1 -s -r -p "Press any key to back on menu"
menu
}
function autokill(){
clear
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[ON]${Font_color_suffix}"
Error="${Red_font_prefix}[OFF]${Font_color_suffix}"
cek=$(grep -c -E "^# Autokill" /etc/cron.d/tendang)
if [[ "$cek" = "1" ]]; then
sts="${Info}"
else
sts="${Error}"
fi
clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[44;1;39m             AUTOKILL SSH          \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Status Autokill : $sts        "
echo -e ""
echo -e "[1]  AutoKill After 5 Minutes"
echo -e "[2]  AutoKill After 10 Minutes"
echo -e "[3]  AutoKill After 15 Minutes"
echo -e "[4]  Turn Off AutoKill/MultiLogin"
echo -e "[x]  Menu"
echo ""
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e ""
read -p "Select From Options [1-4 or x] :  " AutoKill
read -p "Multilogin Maximum Number Of Allowed: " max
echo -e ""
case $AutoKill in
1)
echo -e ""
sleep 1
clear
echo > /etc/cron.d/tendang
echo "# Autokill" >/etc/cron.d/tendang
echo "*/5 * * * *  root /usr/bin/tendang $max" >>/etc/cron.d/tendang && chmod +x /etc/cron.d/tendang
echo "" > /root/log-limit.txt
echo -e ""
echo -e "======================================"
echo -e ""
echo -e "      Allowed MultiLogin : $max"
echo -e "      AutoKill Every     : 5 Minutes"
echo -e ""
echo -e "======================================"
service cron reload >/dev/null 2>&1
service cron restart >/dev/null 2>&1
;;
2)
echo -e ""
sleep 1
clear
echo > /etc/cron.d/tendang
echo "# Autokill" >/etc/cron.d/tendang
echo "*/10 * * * *  root /usr/bin/tendang $max" >>/etc/cron.d/tendang && chmod +x /etc/cron.d/tendang
echo "" > /root/log-limit.txt
echo -e ""
echo -e "======================================"
echo -e ""
echo -e "      Allowed MultiLogin : $max"
echo -e "      AutoKill Every     : 10 Minutes"
echo -e ""
echo -e "======================================"
service cron reload >/dev/null 2>&1
service cron restart >/dev/null 2>&1
;;
3)
echo -e ""
sleep 1
clear
echo > /etc/cron.d/tendang
echo "# Autokill" >/etc/cron.d/tendang
echo "*/15 * * * *  root /usr/bin/tendang $max" >>/etc/cron.d/tendang && chmod +x /etc/cron.d/tendang
echo "" > /root/log-limit.txt
echo -e ""
echo -e "======================================"
echo -e ""
echo -e "      Allowed MultiLogin : $max"
echo -e "      AutoKill Every     : 15 Minutes"
echo -e ""
echo -e "======================================"
service cron reload >/dev/null 2>&1
service cron restart >/dev/null 2>&1
;;
4)
rm -fr /etc/cron.d/tendang
echo "" > /root/log-limit.txt
echo -e ""
echo -e "======================================"
echo -e ""
echo -e "      AutoKill MultiLogin Turned Off"
echo -e ""
echo -e "======================================"
service cron reload >/dev/null 2>&1
service cron restart >/dev/null 2>&1
;;
x)
menu
;;
*)
echo "Please enter an correct number"
;;
esac
read -n 1 -s -r -p "Press any key to back on menu"
menu
}
function lock_unlock_ssh() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "\E[44;1;39m                    ⇱ LOCK & UNLOCK SSH ⇲                     \E[0m"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " [1] Kunci akun SSH"
    echo -e " [2] Buka kunci akun SSH"
    echo -e " [3] List akun terkunci ${RED}(Status: LOCKED)${NC}"
    echo -e " [4] List akun tidak terkunci ${GREEN}(Status: UNLOCKED)${NC}"
    echo -e " [x] Kembali"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p " Pilih opsi : " lockopt
    echo ""

    case $lockopt in
        1)
            read -p "Masukkan username yang ingin dikunci: " userlock
            if id "$userlock" &>/dev/null; then
                passwd -l "$userlock"
                echo -e "${YELLOW}Akun '$userlock' berhasil dikunci.${NC}"
            else
                echo -e "${RED}Username '$userlock' tidak ditemukan!${NC}"
            fi
            ;;
        2)
            read -p "Masukkan username yang ingin dibuka kuncinya: " userunlock
            if id "$userunlock" &>/dev/null; then
                passwd -u "$userunlock"
                echo -e "${YELLOW}Akun '$userunlock' berhasil dibuka kuncinya.${NC}"
            else
                echo -e "${RED}Username '$userunlock' tidak ditemukan!${NC}"
            fi
            ;;
        3)
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "                  ${LIGHT}DAFTAR AKUN TERKUNCI (LOCKED)${NC}"
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            printf "%-20s %-25s %-20s\n" "Username" "Expired Date" "Status"
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            while IFS=: read -r user _ uid _ _ _ shell; do
                [[ $uid -ge 1000 && $shell == "/bin/false" ]] || continue
                if passwd -S "$user" | grep -q "L"; then
                    exp=$(chage -l "$user" | grep "Account expires" | cut -d: -f2- | xargs)
                    printf "%-20s %-25s ${RED}%-20s${NC}\n" "$user" "$exp" "LOCKED"
                fi
            done < /etc/passwd
            ;;
        4)
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "               ${LIGHT}DAFTAR AKUN TIDAK TERKUNCI (UNLOCKED)${NC}"
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            printf "%-20s %-25s %-20s\n" "Username" "Expired Date" "Status"
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            while IFS=: read -r user _ uid _ _ _ shell; do
                [[ $uid -ge 1000 && $shell == "/bin/false" ]] || continue
                if passwd -S "$user" | grep -q "P"; then
                    exp=$(chage -l "$user" | grep "Account expires" | cut -d: -f2- | xargs)
                    printf "%-20s %-25s ${GREEN}%-20s${NC}\n" "$user" "$exp" "UNLOCKED"
                fi
            done < /etc/passwd
            ;;
        x)
            menun-ssh
            ;;
        *)
            echo -e "${RED}Opsi tidak valid!${NC}"
            ;;
    esac

    echo ""
    read -n 1 -s -r -p "Tekan ENTER untuk kembali..."
    lock_unlock_ssh
}
function menu_udp_custom() {
clear
echo -e "\033[1;36m========== MENU UDP CUSTOM ==========\033[0m"
echo -e "1. Install UDP Custom"
echo -e "2. Start UDP-Custom"
echo -e "3. Stop UDP-Custom"
echo -e "4. Restart UDP-Custom"
echo -e "5. Status & Log Terakhir"
echo -e "6. Log Realtime (tekan CTRL+C untuk keluar)"
echo -e "7. Edit Config UDP Custom (manual)"
echo -e "8. Ubah Port UDP Custom (otomatis)"
echo -e "9. Optimize Config Otomatis (auto port & setting)"
echo -e "10. Uninstall UDP Custom"
echo -e "0. Kembali ke menu utama"
echo -ne "\nPilih opsi: "; read opsi

case $opsi in
  1)
    bash <(curl -sL https://raw.githubusercontent.com/kanghory/UDP-Custom/main/udp-custom.sh)
    ;;
  2)
    systemctl start udp-custom
    echo -e "\n\e[32mUDP-Custom berhasil dijalankan\e[0m."
    read -n 1 -s -r -p "Tekan enter untuk kembali ke menu udp..."
    menu_udp_custom
    ;;
  3)
    systemctl stop udp-custom
    echo -e "\n\e[31mUDP-Custom berhasil dihentikan\e[0m."
    read -n 1 -s -r -p "Tekan enter untuk kembali ke menu udp..."
    menu_udp_custom
    ;;
  4)
    systemctl restart udp-custom
    echo -e "\n\e[33mUDP-Custom berhasil direstart\e[0m."
    read -n 1 -s -r -p "Tekan enter untuk kembali ke menu udp..."
    menu_udp_custom
    ;;
  5)
    echo -e "\nStatus Layanan:\n"
    systemctl status udp-custom | head -n 10
    read -n 1 -s -r -p "Tekan enter untuk kembali ke menu udp..."
    menu_udp_custom
    ;;
  6)
    echo -e "\nLog Realtime:\n"
    journalctl -u udp-custom -f --output=short-iso | awk '
    {
      if ($0 ~ /INFO|started|running|connected/) {
        print "\033[32m" $0 "\033[0m"
      } else if ($0 ~ /WARN|WARNING/) {
        print "\033[33m" $0 "\033[0m"
      } else if ($0 ~ /ERROR|FAIL/) {
        print "\033[31m" $0 "\033[0m"
      } else {
        print $0
      }
    }'
    menu_udp_custom
    ;;
  7) nano /root/udp/config.json ;;
  8)
    read -p "Masukkan port baru untuk UDP Custom: " new_port
    sed -i "s/\"listen\": \".*\"/\"listen\": \":$new_port\"/" /root/udp/config.json
    systemctl restart udp-custom
    echo "Port berhasil diubah ke $new_port dan service di-restart."
    read -n 1 -s -r -p "Tekan enter untuk kembali ke menu udp..."
    menu_udp_custom
    ;;
  9)
    echo -e "\n\033[1;36m[•] Menjalankan mode Optimasi Config Otomatis...\033[0m"
    ports=(7300 2080 44818 33434 65000 123 443 53)
    for port in "${ports[@]}"; do
        if ! ss -lun | grep -q ":$port "; then
            selected_port="$port"
            break
        fi
    done
    if [[ -z "$selected_port" ]]; then
        echo -e "\033[1;31m[!] Tidak ada port yang tersedia!\033[0m"
        return
    fi
    read -p "Target redirect UDP (default 127.0.0.1:22): " tgt
    tgt="${tgt:-127.0.0.1:22}"
    read -p "Mode (fast2/normal/faketcp) [fast2]: " mode
    mode="${mode:-fast2}"
    cat <<EOF > /root/udp/config.json
{
  "listen": ":$selected_port",
  "target": "$tgt",
  "mode": "$mode",
  "crypt": "none",
  "mtu": 1350,
  "compression": true,
  "obfs": false,
  "timeout": 60,
  "connTimeout": 30
}
EOF
    echo -e "\033[1;32m[✓] Config berhasil dibuat. Menggunakan port: $selected_port\033[0m"
    systemctl restart udp-custom
    echo -e "\033[1;33m[!] UDP Custom sudah di-restart dengan config baru.\033[0m"
    read -n 1 -s -r -p "Tekan enter untuk kembali ke menu udp..."
    menu_udp_custom
    ;;
  10)
    systemctl stop udp-custom
    systemctl disable udp-custom
    rm -f /etc/systemd/system/udp-custom.service
    rm -rf /root/udp
    systemctl daemon-reload
    echo -e "\033[1;31m[✓] UDP Custom berhasil dihapus dari sistem.\033[0m"
    read -n 1 -s -r -p "Tekan enter untuk kembali ke menu udp..."
    menu_udp_custom
    ;;
  0) menu ;;
  *) echo -e "\033[1;31mOpsi tidak valid!\033[0m"; sleep 1; menu_udp_custom ;;
esac
}
clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e "\E[44;1;39m                         ⇱ SSH MENU  ⇲                         \E[0m"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e ""
echo -e "     ${BICyan}[${BIWhite}1${BICyan}] Add Account SSH      "
echo -e "     ${BICyan}[${BIWhite}2${BICyan}] Delete Account SSH      "
echo -e "     ${BICyan}[${BIWhite}3${BICyan}] Perpanjang / Reset Account SSH      "
echo -e "     ${BICyan}[${BIWhite}4${BICyan}] Ubah Password Akun SSH      "
echo -e "     ${BICyan}[${BIWhite}5${BICyan}] Cek User SSH     "
echo -e "     ${BICyan}[${BIWhite}6${BICyan}] Mullog SSH     "
echo -e "     ${BICyan}[${BIWhite}7${BICyan}] Auto Del user Exp     "
echo -e "     ${BICyan}[${BIWhite}8${BICyan}] Auto Kill user SSH    "
echo -e "     ${BICyan}[${BIWhite}9${BICyan}] Cek Member SSH"
echo -e "     ${BICyan}[${BIWhite}10${BICyan}] Trial SSH"
echo -e "     ${BICyan}[${BIWhite}11${BICyan}] Cek ssh usr limit"
echo -e "     ${BICyan}[${BIWhite}12${BICyan}] Pengaturan Limit IP SSH"
echo -e "     ${BICyan}[${BIWhite}13${BICyan}] Lock / Unlock Akun SSH"
echo -e "     ${BICyan}[${BIWhite}14${BICyan}] Install / Unistall SSH UDP Custom"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e "\E[44;1;39m                     ⇱ KANGHORY TUNNELING ⇲                   \E[0m"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e "     ${BIYellow}tekan enter / 0 • To-${BIWhite}Exit${NC}"
echo ""
read -p " Select menu : " opt
echo -e ""
case $opt in
1) clear ; usernew ;;
2) clear ; del ;;
3) clear ; extend_ssh ;;
4) ubahpass_ssh ;;
5) clear ; cek ;;
6) clear ; ceklim ;;
7) clear ; autodel ;;
8) clear ; autokill ;;
9) clear ; member ;;
10) clear ; trialssh ;;
11) clear ; ceklimit ;;
12) clear ; menu_limit_ip_ssh ;;
13) clear ; lock_unlock_ssh ;;
14) clear ; menu_udp_custom ;;
0) clear ; menu ;;
*) echo -e "" ; echo "back on menu" ; sleep 1 ; menu ;;
esac
