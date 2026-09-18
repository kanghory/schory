#!/bin/bash

# Warna
CYAN='\033[1;96m'
LIGHT='\033[1;97m'
NC='\033[0m'
YELLOW='\033[1;93m'
RED='\033[1;91m'

# ==================================================
# AUTO INPUT PARAMETER / INTERAKTIF
# Format Auto Input:
# addssh username password iplimit expired
# ==================================================

if [[ $# -eq 4 ]]; then
    mode="1"
    Login="$1"
    Pass="$2"
    iplimit="$3"
    masaaktif="$4"
else
    clear
    echo -e "${YELLOW}---------------------------------------------------${NC}"
    echo -e "                SSH Ovpn Account Generator"
    echo -e "${YELLOW}---------------------------------------------------${NC}"
    echo -e " [1] Buat Single User"
    echo -e " [2] Buat Multi User (Contoh: user1-5 atau zz1200-1205)"
    echo -e "${YELLOW}---------------------------------------------------${NC}"
    read -p " Pilih Mode [1/2] : " mode

    case $mode in
        1)
            read -p " Username        : " Login
            ;;
        2)
            read -p " Format Range    : " range_input
            ;;
        *)
            echo -e "${RED}[ERROR]${NC} Pilihan tidak valid!"
            exit 1
            ;;
    esac

    read -p " Password        : " Pass
    read -p " Limit IP        : " iplimit
    read -p " Expired (Days)  : " masaaktif
fi

# ==================================================
# PARSING SINGLE / MULTI USER (FIX REGEX BUG)
# ==================================================

user_list=()

if [[ "$mode" == "1" ]]; then
    user_list+=("$Login")
elif [[ "$mode" == "2" ]]; then
    # Fix Regex: Memisahkan prefix teks dan dua pasang angka rentang secara akurat
    # Contoh: zz1200-1205 -> prefix: "zz", start: "1200", end: "1205"
    if [[ "$range_input" =~ ^([a-zA-Z_-]*[a-zA-Z_-])?([0-9]+)-([0-9]+)$ ]]; then
        prefix="${BASH_REMATCH[1]}"
        start_str="${BASH_REMATCH[2]}"
        end_str="${BASH_REMATCH[3]}"

        # Konversi ke integer basis 10
        start=$((10#$start_str))
        end=$((10#$end_str))

        if (( start > end )); then
            echo -e "${RED}[ERROR]${NC} Angka awal ($start) tidak boleh lebih besar dari angka akhir ($end)!"
            exit 1
        fi

        # Jaga panjang digit agar angka berkepala nol (misal 01-05) tidak hilang
        num_len=${#start_str}

        for (( i=start; i<=end; i++ )); do
            formatted_num=$(printf "%0${num_len}d" "$i")
            user_list+=("${prefix}${formatted_num}")
        done
    else
        echo -e "${RED}[ERROR]${NC} Format multi-user salah! Gunakan format seperti: user1-5 atau zz1200-1205"
        exit 1
    fi
fi

# ==================================================
# VALIDASI INPUT UMUM
# ==================================================

if [[ -z "$Pass" || -z "$iplimit" || -z "$masaaktif" ]]; then
    echo -e "${RED}[ERROR]${NC} Semua input wajib diisi!"
    exit 1
elif ! [[ "$iplimit" =~ ^[0-9]+$ && "$masaaktif" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}[ERROR]${NC} Limit IP dan Expired harus berupa angka!"
    exit 1
fi

# ==================================================
# LOAD DATA SERVER
# ==================================================

domain=$(cat /etc/xray/domain 2>/dev/null || echo "Tidak terdeteksi")
sldomain=$(cat /root/nsdomain 2>/dev/null || echo "Tidak terdeteksi")
cdndomain=$(cat /root/awscdndomain 2>/dev/null || echo "auto pointing Cloudflare")
slkey=$(cat /etc/slowdns/server.pub 2>/dev/null || echo "Tidak terdeteksi")
IP=$(wget -qO- ipinfo.io/ip 2>/dev/null || echo "127.0.0.1")

detect_ports() {
    local pattern="$1"
    local ports=""
    
    if command -v netstat &>/dev/null; then
        ports=$(netstat -tulpn 2>/dev/null | grep -i "$pattern" | awk '{print $4}' | grep -oE '[0-9]+$' | sort -n | uniq | paste -sd, -)
    else
        ports=$(ss -tulpn 2>/dev/null | grep -i "$pattern" | awk '{print $4}' | grep -oE ':[0-9]+$' | tr -d ':' | sort -n | uniq | paste -sd, -)
    fi

    [[ -z "$ports" ]] && echo "Tidak terdeteksi" || echo "$ports"
}

openssh=$(detect_ports ssh)
dropbear=$(detect_ports dropbear)
stunnel=$(detect_ports stunnel)
ws_tls=$(detect_ports 443)
ws_http=$(detect_ports 80)

slowdns=$(ps -ef | grep -w sldns | grep -v grep | awk '{for(i=1;i<=NF;i++){if($i=="-udp"){print $(i+1)}}}' | cut -d: -f2 | paste -sd, -)
[[ -z "$slowdns" ]] && slowdns="Tidak terdeteksi"

ssh_udp=$(ss -ulnpt 2>/dev/null | grep udp-custom | awk '{print $5}' | cut -d: -f2 | sort -n | uniq | paste -sd, -)
[[ -z "$ssh_udp" ]] && ssh_udp=$(lsof -nP -iUDP 2>/dev/null | grep udp-custom | awk '{print $9}' | cut -d: -f2 | sort -n | uniq | paste -sd, -)
[[ -z "$ssh_udp" ]] && ssh_udp="Tidak terdeteksi"

udpgw_ports=$(ps -ef | grep badvpn | grep -v grep | awk '{for(i=1;i<=NF;i++){if($i=="--listen-addr"){print $(i+1)}}}' | cut -d: -f2 | paste -sd, -)
[[ -z "$udpgw_ports" ]] && udpgw_ports="Tidak terdeteksi"

ws_direct=8080

color_port() {
    local port=$1
    [[ "$port" == "Tidak terdeteksi" ]] && echo -e "${RED}$port${NC}" || echo -e "$port"
}

# ==================================================
# PROSES EKSEKUSI PENAMBAHAN USER
# ==================================================

created_users=()
failed_users=()

mkdir -p /etc/klmpk/limit/ssh/ip/
mkdir -p /etc/klmpk/log-ssh/

hariini=$(date +%Y-%m-%d)
expi=$(date -d "$masaaktif days" +"%Y-%m-%d")

for user in "${user_list[@]}"; do
    if id "$user" &>/dev/null; then
        failed_users+=("$user (Sudah Ada)")
        continue
    fi

    # Buat user di OS
    useradd -e "$expi" -s /bin/false -M "$user"
    echo -e "$Pass\n$Pass" | passwd "$user" &>/dev/null

    # Simpan Limit IP
    echo "$iplimit" > "/etc/klmpk/limit/ssh/ip/$user"

    # Simpan Log Akun
    cat <<EOF > "/etc/klmpk/log-ssh/$user.txt"
==== SSH Account ====
Username : $user
Password : $Pass
Created  : $hariini
Expired  : $expi
Limit IP : $iplimit

==== Host ====
IP       : $IP
Domain   : $domain
PubKey   : $slkey
NS       : $sldomain

==== Service Ports ====
OpenSSH      : $openssh
Dropbear     : $dropbear
SSH UDP      : $ssh_udp
STunnel4     : $stunnel
SlowDNS      : $slowdns
WS TLS       : $ws_tls
WS HTTP      : $ws_http
WS Direct    : $ws_direct
BadVPN UDPGW : $udpgw_ports

==== OpenVPN ====
TCP : http://$IP:81/tcp.ovpn
UDP : http://$IP:81/udp.ovpn
SSL : http://$IP:81/ssl.ovpn
EOF

    created_users+=("$user")
done

# ==================================================
# OUTPUT DISPLAY
# ==================================================

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m            ⇱ INFORMASI AKUN SSH ⇲             \E[0m"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ ${#created_users[@]} -gt 0 ]]; then
    echo -e "${LIGHT}Daftar User Berhasil Dibuat:${NC}"
    for u in "${created_users[@]}"; do
        echo -e " - ${YELLOW}$u${NC}"
    done
fi

if [[ ${#failed_users[@]} -gt 0 ]]; then
    echo -e "\n${RED}Daftar User Gagal/Dilewati:${NC}"
    for f in "${failed_users[@]}"; do
        echo -e " - $f"
    done
fi

echo -e "\n${LIGHT}Password       : $Pass"
echo -e "Created        : $hariini"
echo -e "Expired        : $expi"
echo -e "Limit IP       : $iplimit"

echo -e "${LIGHT}=================HOST-SSH======================"
echo -e "IP/Host        : $IP"
echo -e "Domain SSH     : $domain"
echo -e "Cloudflare     : $cdndomain"
echo -e "PubKey         : $slkey"
echo -e "Nameserver     : $sldomain"

echo -e "${LIGHT}===============SERVICE PORT===================="
echo -e "OpenSSH        : $(color_port "$openssh")"
echo -e "Dropbear       : $(color_port "$dropbear")"
echo -e "SSH UDP        : 1-$(color_port "$ssh_udp")"
echo -e "STunnel4       : $(color_port "$stunnel")"
echo -e "SlowDNS        : $(color_port "$slowdns")"
echo -e "WS TLS         : $(color_port "$ws_tls")"
echo -e "WS HTTP        : $(color_port "$ws_http")"
echo -e "WS Direct      : $(color_port "$ws_direct")"
echo -e "BadVPN UDPGW   : $(color_port "$udpgw_ports")"

echo -e "OpenVPN TCP    : http://$IP:81/tcp.ovpn"
echo -e "OpenVPN UDP    : http://$IP:81/udp.ovpn"
echo -e "OpenVPN SSL    : http://$IP:81/ssl.ovpn"

echo -e "${LIGHT}=============Payload HTTP Custom=============="
echo -e "Payload WS TLS (Cloudflare) :"
echo -e "GET / HTTP/1.1[crlf]Host: $domain[crlf]Upgrade: websocket[crlf][crlf]"
echo -e ""
echo -e "Payload WS HTTP (Direct)    :"
echo -e "GET / HTTP/1.1[crlf]Host: $domain[crlf]Connection: Keep-Alive[crlf]Upgrade: websocket[crlf][crlf]"
echo -e ""
echo -e "Payload SNI TLS (SSL/TLS)   :"
echo -e "GET wss://$domain/ HTTP/1.1[crlf]Host: $domain[crlf]Upgrade: websocket[crlf][crlf]"
echo -e ""
echo -e "Payload CDN (Fake Host)     :"
echo -e "GET / HTTP/1.1[crlf]Host: www.bing.com[crlf]Connection: Keep-Alive[crlf]Upgrade: websocket[crlf][crlf]"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "       Script by kanghoryVPN"
echo -e "${LIGHT}================================================${NC}"

# ==================================================
# AUTO RETURN MENU JIKA MANUAL
# ==================================================

if [[ $# -eq 0 ]]; then
    read -n 1 -s -r -p "Tekan ENTER untuk kembali ke menu..."
    [[ -f /usr/bin/menu ]] && /usr/bin/menu || exit 0
fi
