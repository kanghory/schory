#!/bin/bash

# Warna
CYAN='\033[1;96m'
LIGHT='\033[1;97m'
NC='\033[0m'
YELLOW='\033[1;93m'
RED='\033[1;91m'

# Header
clear
echo -e "${YELLOW}---------------------------------------------------${NC}"
echo -e "                SSH Ovpn Account kanghory VPN"
echo -e "${YELLOW}---------------------------------------------------${NC}"

# Input data
read -p " Username        : " Login
read -p " Password        : " Pass
read -p " Limit IP        : " iplimit
read -p " Expired (Days)  : " masaaktif

# Validasi input
if [[ -z "$Login" || -z "$Pass" || -z "$iplimit" || -z "$masaaktif" ]]; then
    echo -e "${RED}[ERROR]${NC} Semua input harus diisi!"
    exit 1
elif ! [[ "$iplimit" =~ ^[0-9]+$ && "$masaaktif" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}[ERROR]${NC} Limit IP dan Expired harus berupa angka!"
    exit 1
fi

# Cek jika user sudah ada
if id "$Login" &>/dev/null; then
    echo -e "${RED}[ERROR]${NC} Username '$Login' sudah ada!"
    exit 1
fi

# Simpan Limit IP
mkdir -p /etc/klmpk/limit/ssh/ip/
echo "$iplimit" > /etc/klmpk/limit/ssh/ip/$Login

# Load data sistem
domain=$(cat /etc/xray/domain)
sldomain=$(cat /root/nsdomain)
cdndomain=$(cat /root/awscdndomain 2>/dev/null || echo "auto pointing Cloudflare")
slkey=$(cat /etc/slowdns/server.pub)
IP=$(wget -qO- ipinfo.io/ip)

# Deteksi port otomatis
detect_ports() {
    local pattern="$1"
    local ports=$(netstat -tulpn 2>/dev/null | grep -i "$pattern" | awk '{print $4}' | grep -oE '[0-9]+$' | sort -n | uniq | paste -sd, -)
    [[ -z "$ports" ]] && echo "Tidak terdeteksi" || echo "$ports"
}

openssh=$(detect_ports ssh)
dropbear=$(detect_ports dropbear)
stunnel=$(detect_ports stunnel)
ws_tls=$(detect_ports 443)
ws_http=$(detect_ports 80)

slowdns=$(ps -ef | grep -w sldns | grep -v grep | awk '{for(i=1;i<=NF;i++){if($i=="-udp"){print $(i+1)}}}' | cut -d: -f2 | paste -sd, -)
[[ -z "$slowdns" ]] && slowdns="Tidak terdeteksi"

ssh_udp=$(ss -ulnpt | grep udp-custom | awk '{print $5}' | cut -d: -f2 | sort -n | uniq | paste -sd, -)
[[ -z "$ssh_udp" ]] && ssh_udp=$(lsof -nP -iUDP | grep udp-custom | awk '{print $9}' | cut -d: -f2 | sort -n | uniq | paste -sd, -)
[[ -z "$ssh_udp" ]] && ssh_udp="Tidak terdeteksi"

udpgw_ports=$(ps -ef | grep badvpn | grep -v grep | awk '{for(i=1;i<=NF;i++){if($i=="--listen-addr"){print $(i+1)}}}' | cut -d: -f2 | paste -sd, -)
[[ -z "$udpgw_ports" ]] && udpgw_ports="Tidak terdeteksi"

ws_direct=8080

# Fungsi warna port
color_port() {
    local port=$1
    [[ "$port" == "Tidak terdeteksi" ]] && echo -e "${RED}$port${NC}" || echo -e "$port"
}
log_color() {
    local port=$1
    [[ "$port" == "Tidak terdeteksi" ]] && echo -e "\033[1;91m$port\033[0m" || echo "$port"
}

# Proses pembuatan user
useradd -e `date -d "$masaaktif days" +"%Y-%m-%d"` -s /bin/false -M $Login
echo -e "$Pass\n$Pass\n" | passwd $Login &> /dev/null
hariini=$(date +%Y-%m-%d)
expi=$(date -d "$masaaktif days" +"%Y-%m-%d")

# Output informasi akun
clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m            ⇱ INFORMASI AKUN SSH ⇲             \E[0m"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${LIGHT}Username       : $Login"
echo -e "Password       : $Pass"
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
echo -e "SSH UDP        : 1 - $(color_port "$ssh_udp")"
echo -e "STunnel4       : $(color_port "$stunnel")"
echo -e "SlowDNS        : $(color_port "$slowdns")"
echo -e "WS TLS         : $(color_port "$ws_tls")"
echo -e "WS HTTP        : $(color_port "$ws_http")"
echo -e "WS Direct      : $(color_port "$ws_direct")"
echo -e "BadVPN UDPGW   : $(color_port "$udpgw_ports")"
echo -e "OpenVPN TCP    : http://$IP:81/tcp.ovpn"
echo -e "OpenVPN UDP    : http://$IP:81/udp.ovpn"
echo -e "OpenVPN SSL    : http://$IP:81/ssl.ovpn"
echo -e "Squid Proxy    : [ON]"
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

# Simpan log akun berwarna
mkdir -p /etc/klmpk/log-ssh
cat <<EOF > /etc/klmpk/log-ssh/$Login.txt
==== SSH Account ====
Username : $Login
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
OpenSSH      : $(log_color "$openssh")
Dropbear     : $(log_color "$dropbear")
SSH UDP      : $(log_color "$ssh_udp")
STunnel4     : $(log_color "$stunnel")
SlowDNS      : $(log_color "$slowdns")
WS TLS       : $(log_color "$ws_tls")
WS HTTP      : $(log_color "$ws_http")
WS Direct    : $(log_color "$ws_direct")
BadVPN UDPGW : $(log_color "$udpgw_ports")

==== OpenVPN ====
TCP : http://$IP:81/tcp.ovpn
UDP : http://$IP:81/udp.ovpn
SSL : http://$IP:81/ssl.ovpn

==== Payload HTTP Custom ====
Payload WS TLS (Cloudflare) :
GET / HTTP/1.1[crlf]Host: $domain[crlf]Upgrade: websocket[crlf][crlf]

Payload WS HTTP (Direct) :
GET / HTTP/1.1[crlf]Host: $domain[crlf]Connection: Keep-Alive[crlf]Upgrade: websocket[crlf][crlf]

Payload SNI TLS (SSL/TLS) :
GET wss://$domain/ HTTP/1.1[crlf]Host: $domain[crlf]Upgrade: websocket[crlf][crlf]

Payload CDN (Fake Host) :
GET / HTTP/1.1[crlf]Host: www.bing.com[crlf]Connection: Keep-Alive[crlf]Upgrade: websocket[crlf][crlf]
EOF

read -n 1 -s -r -p "Tekan ENTER untuk kembali ke menu..."
/usr/bin/menu
