#!/bin/bash
# Menu Wildcard + Cloudflare + acme.sh + Trojan-WS (Nginx 443) + Telegram notify
# By — integrated version for testing

NC='\033[0m'
r='\033[1;91m'
g='\033[1;92m'
y='\033[1;93m'
c='\033[0;96m'
w='\033[1;97m'

# Ensure directories
mkdir -p /etc/.wc
mkdir -p /etc/ssl

# Default config file (created if absent)
if [[ ! -f '/etc/.data' ]]; then
    cat <<EOF > /etc/.data
EMAILCF email_cf@example.com
KEY api_key_or_global_key_or_token
EOF
    echo -e "${y}Created default /etc/.data — edit it with your Cloudflare Email and Key/API token.${NC}"
fi

EMAILCF=$(grep -w 'EMAILCF' '/etc/.data' | awk '{print $2}')
KEY=$(grep -w 'KEY' '/etc/.data' | awk '{print $2}')

lane_atas(){ echo -e "${c}┌──────────────────────────────────────────┐${NC}"; }
lane_bawah(){ echo -e "${c}└──────────────────────────────────────────┘${NC}"; }

# -----------------------------
# Cloudflare account functions
# -----------------------------
add_akun_cf(){
    clear
    lane_atas
    echo -e "${c}│${NC}     ${w}ADD AKUN CLOUDFLARE${NC}                ${c}│${NC}"
    lane_bawah
    read -p "Masukkan Email Cloudflare: " input_email
    read -p "Masukkan API Key / Global Key / Token: " input_key
    if [[ -z "$input_email" || -z "$input_key" ]]; then
        echo -e "${r}Email atau API Token tidak boleh kosong!${NC}"
        sleep 2; menu_wc
    fi
    cat <<EOF > /etc/.data
EMAILCF $input_email
KEY $input_key
EOF
    EMAILCF=$input_email; KEY=$input_key
    echo -e "${g}Akun Cloudflare berhasil disimpan di /etc/.data${NC}"
    sleep 1; menu_wc
}

del_akun_cf(){
    clear
    lane_atas
    echo -e "${c}│${NC}   ${r}DELETE AKUN CLOUDFLARE${NC}           ${c}│${NC}"
    lane_bawah
    rm -f /etc/.data
    echo -e "${g}File /etc/.data dihapus.${NC}"
    sleep 1; menu_wc
}

# -----------------------------
# CF API helpers
# -----------------------------
get_account_id(){
    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
        -H "X-Auth-Email: $EMAILCF" \
        -H "X-Auth-Key: $KEY" \
        -H "Content-Type: application/json")
    if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
        AKUNID=$(echo "$response" | jq -r '.result[0].id')
    else
        echo -e "${r}Gagal mendapatkan Account ID dari Cloudflare. Periksa /etc/.data${NC}"
        echo "$response" | jq
        sleep 3; menu_wc
    fi
}

get_zone_id(){
    # expects DOMAIN variable set (root zone like domainkamu.com)
    ZONE=$(curl -sLX GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}&status=active" \
         -H "X-Auth-Email: ${EMAILCF}" \
         -H "X-Auth-Key: ${KEY}" \
         -H "Content-Type: application/json" | jq -r .result[0].id)
    if [[ -z "$ZONE" || "$ZONE" == "null" ]]; then
        echo -e "${r}Gagal dapatkan Zone ID untuk $DOMAIN${NC}"
        sleep 2; menu_wc
    fi
}

# -----------------------------
# Worker helpers (for add_wc)
# -----------------------------
generate_random(){
    WORKER_NAME="$(</dev/urandom tr -dc a-j0-9 | head -c4)-$(</dev/urandom tr -dc a-z0-9 | head -c8)-$(</dev/urandom tr -dc a-z0-9 | head -c5)"
}

buat_worker(){
    generate_random
    get_account_id
    WORKER_SCRIPT=$'addEventListener("fetch", event => { event.respondWith(new Response("Hello from worker", {status:200})); })'
    URL="https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/scripts/$WORKER_NAME"
    response=$(curl -s -w "%{http_code}" -o /tmp/response_w.json -X PUT \
        -H "X-Auth-Email: $EMAILCF" \
        -H "X-Auth-Key: $KEY" \
        -H "Content-Type: application/javascript" \
        --data "$WORKER_SCRIPT" \
        "$URL")
    httpCode=$(echo "$response" | tail -n1)
    if [ "$httpCode" -eq 200 ]; then
        echo "Success. Name : $WORKER_NAME"
    else
        echo -e "${r}Gagal membuat worker. HTTP:$httpCode${NC}"
        cat /tmp/response_w.json
    fi
    rm -f /tmp/response_w.json
}

add_domain_worker(){
    # add_domain_worker workername custom.domain
    WORKER_NAME="$1"
    CUSTOM_DOMAIN="$2"
    get_account_id
    DATA=$(cat <<EOF
{"hostname":"$CUSTOM_DOMAIN","service":"$WORKER_NAME","environment":"production"}
EOF
)
    RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/response_dw.json \
        -X PUT "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/domains/records" \
        -H "X-Auth-Email: $EMAILCF" \
        -H "X-Auth-Key: $KEY" \
        -H "Content-Type: application/json" \
        -d "$DATA")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    if [ "$HTTP_CODE" -eq 200 ]; then
        echo -e "${g}Worker domain $CUSTOM_DOMAIN added${NC}"
    else
        echo -e "${r}Gagal add domain to worker ($HTTP_CODE)${NC}"
        cat /tmp/response_dw.json
    fi
    rm -f /tmp/response_dw.json
}

hapus_worker(){
    WORKER_NAME="$1"
    get_account_id
    URL="https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/scripts/$WORKER_NAME"
    response=$(curl -s -w "%{http_code}" -o /tmp/response_del_w.json -X DELETE \
        -H "X-Auth-Email: $EMAILCF" \
        -H "X-Auth-Key: $KEY" \
        "$URL")
    httpCode=$(echo "$response" | tail -n1)
    if [ "$httpCode" -ne 200 ]; then
        echo -e "${r}Gagal menghapus worker $WORKER_NAME (HTTP $httpCode)${NC}"
        cat /tmp/response_del_w.json
    fi
    rm -f /tmp/response_del_w.json
}

# -----------------------------
# DNS CNAME pointing (wildcard)
# -----------------------------
pointing_cname(){
    # argument: domain_sub (e.g. vpn.example.com)
    domain_sub="${1}"
    DOMAIN=$(echo "$domain_sub" | cut -d "." -f2-)
    SUB=$(echo "$domain_sub" | cut -d "." -f1)
    SUB_DOMAIN="*.${SUB}.${DOMAIN}"
    get_zone_id

    RECORD_INFO=$(curl -sLX GET "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records?name=${SUB_DOMAIN}" \
         -H "X-Auth-Email: ${EMAILCF}" \
         -H "X-Auth-Key: ${KEY}" \
         -H "Content-Type: application/json")

    RECORD=$(echo "$RECORD_INFO" | jq -r .result[0].id)
    # Use DNS-only (proxied:false) for wildcard to avoid Cloudflare restriction on proxied wildcard
    if [[ "${#RECORD}" -le 10 || "$RECORD" == "null" ]]; then
         RECORD=$(curl -sLX POST "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records" \
         -H "X-Auth-Email: ${EMAILCF}" \
         -H "X-Auth-Key: ${KEY}" \
         -H "Content-Type: application/json" \
         --data '{"type":"CNAME","name":"'${SUB_DOMAIN}'","content":"'${domain_sub}'","ttl":120,"proxied":false}' | jq -r .result.id)
         echo -e "${g}Created DNS record ${SUB_DOMAIN} -> ${domain_sub} (DNS-only)${NC}"
    else
         RESULT=$(curl -sLX PUT "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records/${RECORD}" \
         -H "X-Auth-Email: ${EMAILCF}" \
         -H "X-Auth-Key: ${KEY}" \
         -H "Content-Type: application/json" \
         --data '{"type":"CNAME","name":"'${SUB_DOMAIN}'","content":"'${domain_sub}'","ttl":120,"proxied":false}')
         echo -e "${g}Updated DNS record ${SUB_DOMAIN} -> ${domain_sub}${NC}"
    fi
}

# -----------------------------
# Add Wildcard (creates worker + add domain-worker + create CNAME wildcard)
# -----------------------------
add_wc(){
    clear
    lane_atas
    echo -e "${c}│${NC}     ${w}ADD WILDCARD (create worker + CNAME + worker-domain)${NC}   ${c}│${NC}"
    lane_bawah
    read -p "Masukkan domain utama (contoh: vpn.example.com) : " domain
    if [[ -z "$domain" ]]; then echo -e "${r}Domain kosong!${NC}"; sleep 1; menu_wc; fi

    # create worker
    workername=$(buat_worker | awk '{print $4}')
    if [[ -z "$workername" ]]; then
        echo -e "${r}Gagal buat worker${NC}"; sleep 2; menu_wc
    fi

    # create CNAME *.sub.domain -> sub.domain
    pointing_cname ${domain}

    # read bug list and add worker domain for each bug entry
    BUGFILE="/etc/.wc/bug.txt"
    if [[ ! -f "$BUGFILE" ]]; then
        echo -e "${y}File ${BUGFILE} kosong / tidak ada. Silakan tambah bug lewat menu (Edit Bug).${NC}"
    else
        mapfile -t data < "$BUGFILE"
        for bug in "${data[@]}"; do
            bug_clean=$(echo "$bug" | xargs) # trim
            [[ -z "$bug_clean" ]] && continue
            custom="${bug_clean}.${domain}"
            echo -e "${c}Adding worker-domain: $custom${NC}"
            add_domain_worker "$workername" "$custom"
        done
    fi

    echo -e "${g}Selesai menambahkan wildcard dan worker mapping. Worker dibuat: $workername${NC}"
    echo -e "${y}Catatan: worker sengaja TIDAK dihapus otomatis agar mapping tetap aktif.${NC}"
    read -p "Tekan Enter untuk kembali..."
    menu_wc
}

# -----------------------------
# Delete wildcard dns record (wildcard CNAME)
# -----------------------------
delete_wc(){
    clear
    lane_atas
    echo -e "${c}│${NC}   ${r}DELETE WILDCARD (delete wildcard CNAME)${NC}       ${c}│${NC}"
    lane_bawah
    read -p "Masukkan subdomain wildcard yang dibuat sebelumnya (contoh: vpn.example.com) : " domain_sub
    if [[ -z "$domain_sub" ]]; then echo -e "${r}Domain kosong${NC}"; sleep 1; menu_wc; fi
    DOMAIN=$(echo "$domain_sub" | cut -d "." -f2-)
    SUB=$(echo "$domain_sub" | cut -d "." -f1)
    SUB_DOMAIN="*.${SUB}.${DOMAIN}"
    get_zone_id
    RECORD_INFO=$(curl -sLX GET "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records?name=${SUB_DOMAIN}" \
         -H "X-Auth-Email: ${EMAILCF}" \
         -H "X-Auth-Key: ${KEY}" \
         -H "Content-Type: application/json")
    RECORD=$(echo "$RECORD_INFO" | jq -r .result[0].id)
    if [[ "${#RECORD}" -le 10 || "$RECORD" == "null" ]]; then
        echo -e "${r}Record wildcard ${SUB_DOMAIN} tidak ditemukan${NC}"
    else
        RESPONSE=$(curl -sLX DELETE "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records/${RECORD}" \
            -H "X-Auth-Email: ${EMAILCF}" \
            -H "X-Auth-Key: ${KEY}" \
            -H "Content-Type: application/json")
        if echo "$RESPONSE" | grep -q '"success":true'; then
            echo -e "${g}Wildcard ${SUB_DOMAIN} berhasil dihapus.${NC}"
        else
            echo -e "${r}Gagal menghapus wildcard ${SUB_DOMAIN}.${NC}"; echo "$RESPONSE"
        fi
    fi
    read -p "Enter untuk kembali..." ; menu_wc
}

# -----------------------------
# Edit/Add bug list
# -----------------------------
edit_bug(){
    mkdir -p /etc/.wc
    if [[ ! -f /etc/.wc/bug.txt ]]; then
        touch /etc/.wc/bug.txt
        echo -e "# isi satu bug per baris (tanpa subdomain). contoh: bug1" > /etc/.wc/bug.txt
    fi
    nano /etc/.wc/bug.txt
    echo -e "${g}Bug updated: /etc/.wc/bug.txt${NC}"
    sleep 1; menu_wc
}

# -----------------------------
# Issue SSL wildcard + deploy Nginx trojan-ws conf + copy cert to /etc/xray
# -----------------------------
issue_ssl_wc(){
    clear
    lane_atas
    echo -e "${c}│${NC} ${w}ISSUE SSL WILDCARD & DEPLOY NGINX TROJAN-WS${NC} ${c}│${NC}"
    lane_bawah
    read -p "Masukkan domain root/sub (contoh: vpn.example.com) : " DOMAIN
    if [[ -z "$DOMAIN" ]]; then echo -e "${r}Domain kosong${NC}"; sleep 1; menu_wc; fi

    # ensure acme.sh
    if ! command -v ~/.acme.sh/acme.sh >/dev/null 2>&1; then
        echo -e "${y}Installing acme.sh...${NC}"
        curl https://get.acme.sh | sh
        source ~/.bashrc
    fi

    export CF_Email="$EMAILCF"
    export CF_Key="$KEY"
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

    echo -e "${c}Requesting wildcard certificate for $DOMAIN and *.$DOMAIN ...${NC}"
    ~/.acme.sh/acme.sh --issue --dns dns_cf -d "$DOMAIN" -d "*.$DOMAIN" --keylength ec-256
    if [[ $? -ne 0 ]]; then
        echo -e "${r}Gagal issue wildcard certificate. Cek log acme.sh${NC}"
        read -p "Enter untuk kembali..." ; menu_wc
    fi

    mkdir -p /etc/ssl/${DOMAIN}
    ~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
        --ecc \
        --key-file       /etc/ssl/${DOMAIN}/privkey.key \
        --fullchain-file /etc/ssl/${DOMAIN}/fullchain.crt

    # copy to xray (origin storage) — keep for manual fallback
    if [[ -d "/etc/xray" ]]; then
        cp /etc/ssl/${DOMAIN}/privkey.key /etc/xray/vpn.key
        cp /etc/ssl/${DOMAIN}/fullchain.crt /etc/xray/vpn.crt
    fi

    # create nginx conf for trojan-ws (front-end SSL)
    NGINX_CONF="/etc/nginx/conf.d/trojan-ws-${DOMAIN}.conf"
    cat > "$NGINX_CONF" <<'EOF'
server {
    listen 443 ssl;
    server_name __SERVER_NAMES__;
    ssl_certificate       __CERT_PATH__;
    ssl_certificate_key   __KEY_PATH__;
    ssl_protocols         TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;

    location /trojan-ws {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

    # fill placeholders
    SERVER_NAMES="*.${DOMAIN} ${DOMAIN}"
    CERT_PATH="/etc/ssl/${DOMAIN}/fullchain.crt"
    KEY_PATH="/etc/ssl/${DOMAIN}/privkey.key"
    sed -i "s|__SERVER_NAMES__|${SERVER_NAMES}|g" "$NGINX_CONF"
    sed -i "s|__CERT_PATH__|${CERT_PATH}|g" "$NGINX_CONF"
    sed -i "s|__KEY_PATH__|${KEY_PATH}|g" "$NGINX_CONF"

    # Test nginx config then restart
    nginx -t >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo -e "${r}Nginx config test gagal — periksa konfigurasi nginx.${NC}"
        echo "Nginx test output:"
        nginx -t
        read -p "Enter untuk kembali..." ; menu_wc
    fi

    systemctl restart nginx
    systemctl restart xray 2>/dev/null || true

    # setup auto renew cron (acme.sh --cron)
    (crontab -l 2>/dev/null | grep -v acme.sh; echo "0 3 * * * ~/.acme.sh/acme.sh --cron --home ~/.acme.sh > /dev/null 2>&1") | crontab -

    echo -e "${g}SSL wildcard terpasang dan Nginx dikonfigurasi untuk Trojan-WS (frontend 443).${NC}"
    echo -e "${y}Pastikan backend Trojan WS listen di 127.0.0.1:10002 (tanpa TLS).${NC}"
    read -p "Enter untuk kembali..." ; menu_wc
}

# -----------------------------
# Telegram notify setup (optional)
# -----------------------------
setup_telegram_notify(){
    clear
    lane_atas
    echo -e "${c}│${NC}   ${w}SETUP TELEGRAM NOTIFY FOR SSL RENEW${NC}     ${c}│${NC}"
    lane_bawah
    read -p "Masukkan BOT_TOKEN: " BOT_TOKEN
    read -p "Masukkan CHAT_ID (your chat id): " CHAT_ID
    mkdir -p /etc/.wc
    cat > /etc/.wc/telegram.conf <<EOF
BOT_TOKEN=$BOT_TOKEN
CHAT_ID=$CHAT_ID
EOF

    cat > /usr/bin/ssl-notify.sh <<'SH'
#!/bin/bash
DOMAIN="$1"
CONF="/etc/.wc/telegram.conf"
[ ! -f "$CONF" ] && exit 0
source "$CONF"
MSG="✅ SSL Wildcard untuk *${DOMAIN}* berhasil diperpanjang otomatis."
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="${CHAT_ID}" \
  -d parse_mode="Markdown" \
  -d text="$MSG" >/dev/null 2>&1
SH
    chmod +x /usr/bin/ssl-notify.sh

    # ensure cron runs notify after cron renew; append notify to cronline if not exist
    (crontab -l 2>/dev/null | grep -v ssl-notify.sh; echo "0 3 * * * ~/.acme.sh/acme.sh --cron --home ~/.acme.sh > /dev/null 2>&1 && /usr/bin/ssl-notify.sh YOUR_DOMAIN_HERE") | crontab -
    echo -e "${g}Telegram notify script dibuat: /usr/bin/ssl-notify.sh${NC}"
    echo -e "${y}Note: Edit crontab entry to replace YOUR_DOMAIN_HERE with the actual domain you use, or the acme.sh cron will still run and you can call ssl-notify.sh manually when needed.${NC}"
    sleep 2; menu_wc
}

# -----------------------------
# Main menu
# -----------------------------
menu_wc(){
    clear
    lane_atas
    echo -e "${c}│${NC}    ${w}MENU POINTING & SSL WILDCARD (Trojan-WS)${NC}    ${c}│${NC}"
    lane_bawah
    echo -e "${c}│${NC} 1.)${y}☞ ${w} Add Akun Cloudflare${NC}"
    echo -e "${c}│${NC} 2.)${y}☞ ${w} Delete Akun Cloudflare${NC}"
    echo -e "${c}│${NC} 3.)${y}☞ ${w} Add Wildcard (create worker + CNAME + worker mapping)${NC}"
    echo -e "${c}│${NC} 4.)${y}☞ ${w} Delete Wildcard (delete wildcard CNAME)${NC}"
    echo -e "${c}│${NC} 5.)${y}☞ ${w} Add/Edit Bug Wildcard ( /etc/.wc/bug.txt )${NC}"
    echo -e "${c}│${NC} 6.)${y}☞ ${w} Issue SSL Wildcard & Deploy Nginx for Trojan-WS 443${NC}"
    echo -e "${c}│${NC} 7.)${y}☞ ${w} Setup Telegram Notify (optional)${NC}"
    echo -e "${c}│${NC} x.)${y}☞ ${r} Exit${NC}"
    lane_bawah
    echo
    read -p "Select Options [1-7/x] : " opt
    case $opt in
        1) add_akun_cf ;;
        2) del_akun_cf ;;
        3) add_wc ;;
        4) delete_wc ;;
        5) edit_bug ;;
        6) issue_ssl_wc ;;
        7) setup_telegram_notify ;;
        x|X) exit 0 ;;
        *) menu_wc ;;
    esac
}

# start
menu_wc
