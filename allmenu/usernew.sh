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
echo -e "                SSH Ovpn Account"
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

# Load info sistem
domain=$(cat /etc/xray/domain)
sldomain=$(cat /root/nsdomain)
cdndomain=$(cat /root/awscdndomain 2>/dev/null || echo "auto pointing Cloudflare")
slkey=$(cat /etc/slowdns/server.pub)
IP=$(wget -qO- ipinfo.io/ip)

# Deteksi port otomatis
openssh=$(ss -tnlp | grep -w 'sshd' | awk '{print $4}' | cut -d: -f2 | sort -u | paste -sd, -)
dropbear=$(ps -ef | grep dropbear | grep -v grep | awk '{for(i=1;i<=NF;i++){if($i=="dropbear"){print $(i+1)}}}' | cut -d: -f2 | sort -u | paste -sd, -)
udpgw_ports=$(ps -ef | grep badvpn | grep -v grep | grep -oP '127\.0\.0\.1:\K[0-9]+' | paste -sd, -)
stunnel=$(ss -tnlp | grep stunnel | awk '{print $4}' | cut -d: -f2 | sort -u | paste -sd, -)
slowdns=$(ps -ef | grep sldns | grep -v grep | grep -oP '-udp \K[0-9]+' | paste -sd, -)
ws_tls=$(ss -tnlp | grep ':443' | awk '{print $4}' | cut -d: -f2 | paste -sd, -)
ws_http=$(ss -tnlp | grep ':80' | awk '{print $4}' | cut -d: -f2 | paste -sd, -)
ws_direct=8080

# Proses user
useradd -e `date -d "$masaaktif days" +"%Y-%m-%d"` -s /bin/false -M $Login
echo -e "$Pass\n$Pass\n" | passwd $Login &> /dev/null
hariini=$(date +%Y-%m-%d)
expi=$(date -d "$masaaktif days" +"%Y-%m-%d")

# Output akun
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
echo -e "OpenSSH        : ${openssh:-Tidak terdeteksi}"
echo -e "Dropbear       : ${dropbear:-Tidak terdeteksi}"
echo -e "SSH UDP        : ${udpgw_ports:-Tidak terdeteksi}"
echo -e "STunnel4       : ${stunnel:-Tidak terdeteksi}"
echo -e "SlowDNS        : ${slowdns:-Tidak terdeteksi}"
echo -e "WS TLS         : ${ws_tls:-Tidak terdeteksi}"
echo -e "WS HTTP        : ${ws_http:-Tidak terdeteksi}"
echo -e "WS Direct      : ${ws_direct:-Tidak terdeteksi}"
echo -e "OpenVPN TCP    : http://$IP:81/tcp.ovpn"
echo -e "OpenVPN UDP    : http://$IP:81/udp.ovpn"
echo -e "OpenVPN SSL    : http://$IP:81/ssl.ovpn"
echo -e "BadVPN UDPGW   : ${udpgw_ports:-Tidak terdeteksi}"
echo -e "Squid Proxy    : [ON]"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "       Script by kanghoryVPN"
echo -e "${LIGHT}================================================${NC}"

# Simpan log akun
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

==== OpenVPN ====
TCP : http://$IP:81/tcp.ovpn
UDP : http://$IP:81/udp.ovpn
SSL : http://$IP:81/ssl.ovpn
EOF
