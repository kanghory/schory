#!/bin/bash
# Menu Wildcard + SSL Cloudflare + Auto Renew + Telegram Notify
# By Kanghory Tunneling

NC='\033[0m'
r='\033[1;91m'
g='\033[1;92m'
y='\033[1;93m'
c='\033[0;96m'
w='\033[1;97m'

# ------------------ Cek akun CF -------------------
if [[ ! -f '/etc/.data' ]]; then
    echo -e "${y}File konfigurasi tidak ditemukan. Membuat default...${NC}"
    mkdir -p /etc
    cat <<EOF > /etc/.data
EMAILCF email_cf@example.com
KEY api_key_anda
EOF
fi

EMAILCF=$(grep -w 'EMAILCF' '/etc/.data' | awk '{print $2}')
KEY=$(grep -w 'KEY' '/etc/.data' | awk '{print $2}')

# ------------------ Fungsi Menu -------------------
lane_atas() { echo -e "${c}┌──────────────────────────────────────────┐${NC}"; }
lane_bawah() { echo -e "${c}└──────────────────────────────────────────┘${NC}"; }

add_akun_cf() {
    clear
    echo -e "${c}Add Akun Cloudflare${NC}"
    read -p "Email Cloudflare: " input_email
    read -p "API Key Cloudflare: " input_key
    [[ -z "$input_email" || -z "$input_key" ]] && { echo -e "${r}Input kosong!${NC}"; sleep 2; menu_wc; }
    cat <<EOF > /etc/.data
EMAILCF $input_email
KEY $input_key
EOF
    echo -e "${g}Akun CF disimpan.${NC}"; sleep 2; menu_wc
}

del_akun_cf() {
    clear
    echo -e "${c}Delete Akun Cloudflare${NC}"
    rm -f /etc/.data
    echo -e "${g}Akun CF dihapus.${NC}"; sleep 2; menu_wc
}

edit_bug() {
    mkdir -p /etc/.wc
    nano /etc/.wc/bug.txt
    echo -e "${g}Bug updated${NC}"
    sleep 2
    menu_wc
}

# ------------------ Issue SSL Wildcard -------------------
issue_ssl_wc() {
    clear
    EMAILCF=$(grep -w 'EMAILCF' '/etc/.data' | awk '{print $2}')
    KEY=$(grep -w 'KEY' '/etc/.data' | awk '{print $2}')
    [[ -z "$EMAILCF" || -z "$KEY" ]] && { echo -e "${r}Akun CF belum diatur!${NC}"; sleep 2; menu_wc; }

    read -p "Masukkan domain utama (contoh: vpn.example.com): " DOMAIN
    [[ -z "$DOMAIN" ]] && { echo -e "${r}Domain kosong!${NC}"; sleep 2; menu_wc; }

    if ! command -v ~/.acme.sh/acme.sh >/dev/null 2>&1; then
        echo -e "${y}Install acme.sh...${NC}"
        curl https://get.acme.sh | sh
        source ~/.bashrc
    fi

    export CF_Email="$EMAILCF"
    export CF_Key="$KEY"

    echo -e "${c}Issue SSL untuk $DOMAIN + *.$DOMAIN ...${NC}"
    ~/.acme.sh/acme.sh --issue --dns dns_cf -d $DOMAIN -d "*.$DOMAIN" --keylength ec-256

    mkdir -p /etc/ssl/${DOMAIN}
    ~/.acme.sh/acme.sh --install-cert -d $DOMAIN \
      --ecc \
      --key-file       /etc/ssl/${DOMAIN}/privkey.key \
      --fullchain-file /etc/ssl/${DOMAIN}/fullchain.crt

    if [[ -d "/etc/xray" ]]; then
        cp /etc/ssl/${DOMAIN}/privkey.key /etc/xray/vpn.key
        cp /etc/ssl/${DOMAIN}/fullchain.crt /etc/xray/vpn.crt
        systemctl restart xray
        echo -e "${g}SSL Wildcard dipasang ke Xray!${NC}"
    else
        echo -e "${y}SSL tersimpan di /etc/ssl/${DOMAIN}${NC}"
    fi

    # Setup auto renew
    echo -e "${c}Mengaktifkan auto renew SSL...${NC}"
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    (crontab -l 2>/dev/null; echo "0 3 * * * ~/.acme.sh/acme.sh --cron --home ~/.acme.sh > /dev/null && /usr/bin/ssl-notify.sh $DOMAIN") | crontab -

    echo -e "${g}Selesai! SSL aktif untuk $DOMAIN dan *.$DOMAIN${NC}"
    echo -e "${g}Auto renew SSL sudah aktif (cek tiap jam 03:00)${NC}"
    read -p "Enter untuk kembali ke menu..."
    menu_wc
}

# ------------------ Telegram Notify -------------------
setup_telegram_notify() {
    echo -e "${c}Setup Notifikasi Telegram${NC}"
    read -p "Masukkan BOT TOKEN: " BOT_TOKEN
    read -p "Masukkan CHAT ID: " CHAT_ID

    mkdir -p /etc/.wc
    cat <<EOF > /etc/.wc/telegram.conf
BOT_TOKEN=$BOT_TOKEN
CHAT_ID=$CHAT_ID
EOF

    # Script notifikasi
    cat <<'EOF' > /usr/bin/ssl-notify.sh
#!/bin/bash
DOMAIN=$1
CONF="/etc/.wc/telegram.conf"
[ ! -f "$CONF" ] && exit 0
source $CONF
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    -d parse_mode="Markdown" \
    -d text="✅ SSL Wildcard untuk *${DOMAIN}* berhasil diperpanjang otomatis!"
EOF
    chmod +x /usr/bin/ssl-notify.sh

    echo -e "${g}Notifikasi Telegram aktif.${NC}"
    sleep 2
    menu_wc
}

# ------------------ Menu Utama -------------------
menu_wc() {
clear
lane_atas
echo -e "${c}│${NC}    ${w}MENU POINTING & SSL WILDCARD${NC}    ${c}│${NC}"
lane_bawah
echo -e "${c}│${NC} 1.)${y}☞ ${w} Add Akun Cloudflare${NC}"
echo -e "${c}│${NC} 2.)${y}☞ ${w} Delete Akun Cloudflare${NC}"
echo -e "${c}│${NC} 3.)${y}☞ ${w} Add Wildcard (CNAME Worker)${NC}"
echo -e "${c}│${NC} 4.)${y}☞ ${w} Delete Wildcard${NC}"
echo -e "${c}│${NC} 5.)${y}☞ ${w} Add/Edit Bug Wildcard${NC}"
echo -e "${c}│${NC} 6.)${y}☞ ${w} Issue SSL Wildcard (Port 443)${NC}"
echo -e "${c}│${NC} 7.)${y}☞ ${w} Setup Notif Telegram Renew SSL${NC}"
echo -e "${c}│${NC} x.)${y}☞ ${r} Exit${NC}"
lane_bawah
echo
read -p "Pilih [1-7/x]: " opt
case $opt in
1) add_akun_cf ;;
2) del_akun_cf ;;
3) echo -e "${y}Fitur Add WC masih di script awal${NC}" ; sleep 2 ; menu_wc ;;
4) echo -e "${r}Coming Soon${NC}" ; sleep 2 ; menu_wc ;;
5) edit_bug ;;
6) issue_ssl_wc ;;
7) setup_telegram_notify ;;
x|X) exit 0 ;;
*) menu_wc ;;
esac
}

menu_wc
