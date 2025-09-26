#!/bin/bash
# =============================================
# Cloudflare CLI Manager
# By KangHory | GPT-5 Enhanced Edition
# =============================================

# Warna
NC='\033[0m'
r='\033[1;91m'
g='\033[1;92m'
y='\033[1;93m'
c='\033[0;96m'
w='\033[1;97m'

# =============================================
# Helper: Load credentials
# =============================================
load_credentials() {
    if [[ -f "/etc/.data" ]]; then
        EMAILCF=$(grep -w 'EMAILCF' '/etc/.data' | awk '{print $2}')
        KEY=$(grep -w 'KEY' '/etc/.data' | awk '{print $2}')
    else
        unset EMAILCF KEY
    fi
}

# =============================================
# Add akun Cloudflare (Validasi Otomatis)
# =============================================
add_akun_cf() {
    clear
    echo -e "${c}┌────────────────────────────────────┐${NC}"
    echo -e "${c}│${NC}     ${w}ADD AKUN CLOUDFLARE${NC}           ${c}│${NC}"
    echo -e "${c}└────────────────────────────────────┘${NC}"

    read -p "Masukkan Email Cloudflare : " input_email
    read -p "Masukkan Global API Key / API Token : " input_key

    if [[ -z "$input_email" || -z "$input_key" ]]; then
        echo -e "${r}Email atau API Key/Token tidak boleh kosong!${NC}"
        sleep 1
        return
    fi

    old_email="$EMAILCF"
    old_key="$KEY"

    cat <<EOF > /etc/.data
EMAILCF $input_email
KEY $input_key
EOF
    chmod 600 /etc/.data

    EMAILCF="$input_email"
    KEY="$input_key"

    if get_account_id >/dev/null 2>&1; then
        echo -e "${g}Akun Cloudflare berhasil ditambahkan dan tervalidasi.${NC}"
    else
        echo -e "${r}Validasi gagal: Email/API Key mungkin salah.${NC}"
        read -p "Kembalikan kredensial lama jika ada? (y/N): " yn
        if [[ "$yn" =~ ^[Yy]$ ]]; then
            if [[ -n "$old_email" && -n "$old_key" ]]; then
                cat <<EOF > /etc/.data
EMAILCF $old_email
KEY $old_key
EOF
                chmod 600 /etc/.data
                EMAILCF="$old_email"
                KEY="$old_key"
                echo -e "${y}Kembali ke kredensial lama.${NC}"
            else
                rm -f /etc/.data
                unset EMAILCF KEY
                echo -e "${y}Kredensial baru dihapus.${NC}"
            fi
        fi
    fi

    sleep 1
}

# =============================================
# Delete akun Cloudflare
# =============================================
hapus_akun_cf() {
    clear
    echo -e "${c}Menghapus akun Cloudflare...${NC}"
    rm -f /etc/.data
    unset EMAILCF KEY
    echo -e "${g}Akun berhasil dihapus.${NC}"
    sleep 1
}

# =============================================
# Ambil Account ID
# =============================================
get_account_id() {
    if [[ -z "$EMAILCF" || -z "$KEY" ]]; then
        return 1
    fi
    RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
        -H "X-Auth-Email: $EMAILCF" \
        -H "X-Auth-Key: $KEY")
    AKUNID=$(echo "$RESPONSE" | jq -r '.result[0].id')
    AKUNNAME=$(echo "$RESPONSE" | jq -r '.result[0].name')
    [[ -n "$AKUNID" && "$AKUNID" != "null" ]]
}

# =============================================
# Add Bug List (bug.txt)
# =============================================
add_bug_list() {
    clear
    echo -e "${c}Masukkan bug yang akan digunakan (satu per baris). Ketik 'done' untuk selesai:${NC}"
    > bug.txt
    while true; do
        read -p "> " bug
        [[ "$bug" == "done" ]] && break
        echo "$bug" >> bug.txt
    done
    echo -e "${g}Daftar bug tersimpan di bug.txt${NC}"
    sleep 1
}

# =============================================
# Generate Random Worker Name
# =============================================
generate_random() {
    WORKER_NAME=$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 6)
}

# =============================================
# Buat Worker JS
# =============================================
# =============================================
# Buat Worker JS (Manual Input Name)
# =============================================
buat_worker() {
    clear
    get_account_id

    echo -e "${c}┌──────────────────────────────────────┐${NC}"
    echo -e "${c}│${NC}     ${w}ADD WORKER JAVASCRIPT${NC}         ${c}│${NC}"
    echo -e "${c}└──────────────────────────────────────┘${NC}"
    echo ""
    read -p "Masukkan nama Worker (huruf kecil & angka, tanpa spasi): " WORKER_NAME

    # Validasi nama
    if [[ ! "$WORKER_NAME" =~ ^[a-z0-9-]+$ ]]; then
        echo -e "${r}Nama worker hanya boleh huruf kecil, angka, dan tanda '-'${NC}"
        sleep 1
        return
    fi

    WORKER_SCRIPT="
addEventListener('fetch', event => {
  event.respondWith(new Response('Hello from $WORKER_NAME!', {status: 200}))
})
"
    URL="https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/scripts/$WORKER_NAME"

    echo -e "${c}Mengupload Worker JS...${NC}"
    RESPONSE=$(curl -s -w "%{http_code}" -o response.json -X PUT \
        -H "X-Auth-Email: $EMAILCF" \
        -H "X-Auth-Key: $KEY" \
        -H "Content-Type: application/javascript" \
        --data "$WORKER_SCRIPT" \
        "$URL")

    CODE=$(echo "$RESPONSE" | tail -n1)
    if [[ "$CODE" == "200" ]]; then
        echo -e "${g}Worker '$WORKER_NAME' berhasil dibuat.${NC}"
    else
        echo -e "${r}Gagal membuat worker (${CODE})${NC}"
        cat response.json
    fi
    rm -f response.json
    pause
}

# =============================================
# Add Domain Mapping berdasarkan bug.txt
# =============================================
add_domain_worker() {
    clear
    get_account_id

    WORKERS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/scripts" \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" | jq -r '.result[].id')

    echo -e "${c}Pilih Worker yang ingin dipetakan:${NC}"
    select WORKER_NAME in $WORKERS; do
        [[ -n "$WORKER_NAME" ]] && break
    done

    if [[ ! -f bug.txt ]]; then
        echo -e "${r}File bug.txt tidak ditemukan!${NC}"
        return
    fi

    read -p "Masukkan domain VPS / custom domain: " VPS_DOMAIN

    while IFS= read -r bug; do
        [[ -z "$bug" ]] && continue
        HOSTNAME="${bug}.${VPS_DOMAIN}"

        DATA=$(jq -n \
            --arg hostname "$HOSTNAME" \
            --arg service "$WORKER_NAME" \
            '{hostname: $hostname, service: $service, environment: "production"}')

        RESP=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/domains/records" \
            -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" \
            -H "Content-Type: application/json" -d "$DATA")

        if echo "$RESP" | jq -e '.success' >/dev/null; then
            echo -e "${g}Berhasil mapping: $HOSTNAME -> $WORKER_NAME${NC}"
        else
            echo -e "${r}Gagal mapping: $HOSTNAME${NC}"
        fi
    done < bug.txt
    pause
}

# =============================================
# Cek List Hostname Mapping
# =============================================
cek_list_mapping() {
    clear
    get_account_id
    echo -e "${c}Daftar Hostname Mapping Aktif:${NC}"
    curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/domains" \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" | jq -r '.result[] | "\(.hostname) => \(.service)"'
    pause
}

# =============================================
# Hapus Hostname Mapping
# =============================================
hapus_mapping() {
    clear
    get_account_id
    MAPS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/domains" \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY")

    echo -e "${c}Pilih Mapping untuk dihapus:${NC}"
    echo "$MAPS" | jq -r '.result[] | "\(.hostname) -> \(.service)"' | nl -w2 -s". "

    read -p "Nomor yang ingin dihapus (a=hapus semua): " opt
    if [[ "$opt" == "a" ]]; then
        for ID in $(echo "$MAPS" | jq -r '.result[].id'); do
            curl -s -X DELETE "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/domains/$ID" \
                -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY"
        done
        echo -e "${g}Semua mapping dihapus.${NC}"
    else
        IDX=$((opt-1))
        ID=$(echo "$MAPS" | jq -r ".result[$IDX].id")
        curl -s -X DELETE "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/domains/$ID" \
            -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY"
        echo -e "${g}Mapping dihapus.${NC}"
    fi
    pause
}

# =============================================
# Cek List Worker
# =============================================
cek_list_worker() {
    clear
    get_account_id
    echo -e "${c}Daftar Worker JS Aktif:${NC}"
    curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/scripts" \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" | jq -r '.result[].id'
    pause
}

# =============================================
# Hapus Worker JS
# =============================================
hapus_worker_js() {
    clear
    get_account_id
    WORKERS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/scripts" \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" | jq -r '.result[].id')

    echo -e "${c}Pilih Worker untuk dihapus:${NC}"
    select WORKER in $WORKERS; do
        [[ -n "$WORKER" ]] && break
    done
    curl -s -X DELETE "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/scripts/$WORKER" \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY"
    echo -e "${g}Worker '$WORKER' berhasil dihapus.${NC}"
    pause
}

# =============================================
# Function Pointing CNAME
# =============================================
pointing_cname() {
    domain_sub="${1}"
    DOMAIN=$(echo "$domain_sub" | cut -d "." -f2-)
    SUB=$(echo "$domain_sub" | cut -d "." -f1)
    SUB_DOMAIN="*.${SUB}.${DOMAIN}"

    get_zone_id

    RECORD_INFO=$(curl -sLX GET "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records?name=${SUB_DOMAIN}" \
         -H "X-Auth-Email: ${EMAILCF}" \
         -H "X-Auth-Key: ${KEY}" \
         -H "Content-Type: application/json")

    RECORD=$(echo $RECORD_INFO | jq -r .result[0].id)
    if [[ "${#RECORD}" -le 10 ]]; then
         curl -sLX POST "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records" \
         -H "X-Auth-Email: ${EMAILCF}" \
         -H "X-Auth-Key: ${KEY}" \
         -H "Content-Type: application/json" \
         --data '{"type":"CNAME","name":"'${SUB_DOMAIN}'","content":"'${domain_sub}'","ttl":120,"proxied":false}'
    else
         curl -sLX PUT "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records/${RECORD}" \
         -H "X-Auth-Email: ${EMAILCF}" \
         -H "X-Auth-Key: ${KEY}" \
         -H "Content-Type: application/json" \
         --data '{"type":"CNAME","name":"'${SUB_DOMAIN}'","content":"'${domain_sub}'","ttl":120,"proxied":false}'
    fi
}

# =============================================
# Menu Utama
# =============================================
pause() { read -n 1 -s -r -p "Tekan sembarang tombol untuk lanjut..."; }

main_menu() {
    load_credentials
    clear
    if get_account_id >/dev/null 2>&1; then
        STATUS="${g}Login sebagai: $EMAILCF ($AKUNNAME)${NC}"
    else
        STATUS="${r}Belum login Cloudflare${NC}"
    fi

    echo -e "${c}┌────────────────────────────────────────────┐${NC}"
    echo -e "${c}│${NC}   ${w}CLOUDFLARE WORKER MANAGER${NC}            ${c}│${NC}"
    echo -e "${c}└────────────────────────────────────────────┘${NC}"
    echo -e "$STATUS\n"
    echo -e "1) Add Akun Cloudflare"
    echo -e "2) Hapus Akun Cloudflare"
    echo -e "3) Add Bug List (bug.txt)"
    echo -e "4) Add Worker JS"
    echo -e "5) Add Hostname Mapping (bug.txt)"
    echo -e "6) Cek List Hostname Mapping"
    echo -e "7) Hapus Hostname Mapping"
    echo -e "8) Cek List Worker"
    echo -e "9) Hapus Worker JS"
    echo -e "x) Keluar"
    echo -ne "\nPilih menu: "
    read opt
    case $opt in
        1) add_akun_cf ;;
        2) hapus_akun_cf ;;
        3) add_bug_list ;;
        4) buat_worker ;;
        5) add_domain_worker ;;
        6) cek_list_mapping ;;
        7) hapus_mapping ;;
        8) cek_list_worker ;;
        9) hapus_worker_js ;;
        x) exit 0 ;;
        *) echo "Pilihan tidak valid" ;;
    esac
}

# =============================================
# Run
# =============================================
while true; do
    main_menu
done
