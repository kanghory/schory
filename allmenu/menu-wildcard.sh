#!/bin/bash
#
# Cloudflare Worker Manager - Final Fix
# Menu:
# 1 Add akun cloudflare
# 2 Hapus akun cloudflare
# 3 Add bug (bug.txt)
# 4 Add worker js
# 5 Add hostname berdasarkan worker js (dari bug.txt)
# 6 Cek list hostname mapping yang aktif
# 7 Hapus hostname mapping sesuai worker js / hostname
# 8 Cek list worker js yang aktif beserta hostnamenya
# 9 Hapus worker js (pilih 1 atau all)
#

# ---------- Colors ----------
NC='\033[0m'
r='\033[1;91m'
g='\033[1;92m'
y='\033[1;93m'
c='\033[0;96m'
w='\033[1;97m'

# ---------- Paths ----------
DATA_DIR="/etc/.data"
mkdir -p /etc/.wc
BUG_FILE="/etc/.wc/bug.txt"
AKUN_FILE="$DATA_DIR/akun"   # store "EMAIL|KEY"

# ---------- Utils ----------
pause() { read -p "Tekan Enter untuk lanjut..." -r; }
require_cmds() {
    for cmd in curl jq; do
        if ! command -v $cmd >/dev/null 2>&1; then
            echo -e "${r}Perlu menginstall: $cmd${NC}"
            exit 1
        fi
    done
}
require_cmds

# ---------- Load saved account if ada ----------
if [[ -f "$AKUN_FILE" ]]; then
    EMAILCF=$(cut -d'|' -f1 "$AKUN_FILE")
    KEY=$(cut -d'|' -f2 "$AKUN_FILE")
fi

# ---------- CF helpers ----------
get_account_id() {
    if [[ -z "$EMAILCF" || -z "$KEY" ]]; then
        echo -e "${r}Belum ada akun Cloudflare, silakan pilih menu 1 untuk menambah.${NC}"
        return 1
    fi

    resp=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" -H "Content-Type: application/json")

    AKUNID=$(echo "$resp" | jq -r '.result[0].id // empty')
    success=$(echo "$resp" | jq -r '.success // false')

    if [[ "$success" != "true" || -z "$AKUNID" ]]; then
        echo -e "${r}Gagal mendapatkan Account ID. Cek kredensial.${NC}"
        return 1
    fi
    return 0
}

# ---------- Menu 1 ----------
add_akun_cf() {
    clear
    echo -e "${c}Tambah Akun Cloudflare${NC}"
    read -p "Email Cloudflare  : " EMAILCF
    read -p "Global API Key    : " KEY
    if [[ -z "$EMAILCF" || -z "$KEY" ]]; then
        echo -e "${r}Email atau Key kosong.${NC}"
        pause
        return
    fi
    mkdir -p "$DATA_DIR"
    echo "${EMAILCF}|${KEY}" > "$AKUN_FILE"
    chmod 600 "$AKUN_FILE"
    echo -e "${g}Akun disimpan.${NC}"
    pause
}

# ---------- Menu 2 ----------
del_akun_cf() {
    clear
    echo -e "${r}Hapus Akun Cloudflare${NC}"
    if [[ -f "$AKUN_FILE" ]]; then
        rm -f "$AKUN_FILE"
        unset EMAILCF KEY AKUNID
        echo -e "${g}Akun dihapus.${NC}"
    else
        echo -e "${y}Belum ada akun tersimpan.${NC}"
    fi
    pause
}

# ---------- Menu 3 ----------
add_bug() {
    clear
    echo -e "${c}Tambah / Edit bug.txt (satu domain per baris)${NC}"
    echo -e "${c}Lokasi: ${BUG_FILE}${NC}"
    mkdir -p "$(dirname "$BUG_FILE")"
    # open editor
    nano "$BUG_FILE"
    echo -e "${g}Selesai edit.${NC}"
    pause
}

# ---------- Utility: random worker name ----------
generate_random() {
    WORKER_NAME="wk-$(tr -dc 'a-z0-9' </dev/urandom | head -c8)"
}

# ---------- Menu 4: buat worker JS ----------
buat_worker() {
    clear
    echo -e "${c}Buat Worker JS (Hello World)${NC}"
    get_account_id || { pause; return; }
    generate_random

    WORKER_SCRIPT="
addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request))
})
async function handleRequest(request) {
  return new Response('Hello World!', { status: 200 })
}
"
    URL="https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/scripts/$WORKER_NAME"
    resp=$(curl -s -w "\n%{http_code}" -o /tmp/cf_resp.json -X PUT "$URL" \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" \
        -H "Content-Type: application/javascript" --data "$WORKER_SCRIPT")

    code=$(tail -n1 <<< "$resp")
    if [[ "$code" == "200" || "$code" == "201" ]]; then
        echo -e "${g}Success: Worker dibuat -> ${w}$WORKER_NAME${NC}"
    else
        echo -e "${r}Gagal membuat worker. HTTP $code${NC}"
        jq . /tmp/cf_resp.json 2>/dev/null || cat /tmp/cf_resp.json
    fi
    rm -f /tmp/cf_resp.json
    pause
}

# ---------- add_domain_worker: bind hostname ke worker (POST /workers/domains) ----------
add_domain_worker_single() {
    # params: worker_name hostname
    local workername="$1"; local hostname="$2"
    DATA=$(cat <<EOF
{"hostname":"$hostname","service":"$workername","environment":"production"}
EOF
)
    RESP=$(curl -s -w "\n%{http_code}" -o /tmp/cf_resp.json -X POST \
        "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/domains" \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" -H "Content-Type: application/json" \
        -d "$DATA")
    CODE=$(tail -n1 <<< "$RESP")
    if [[ "$CODE" == "200" || "$CODE" == "201" ]]; then
        echo -e "${g}✓ $hostname -> $workername${NC}"
        return 0
    else
        echo -e "${r}✗ Gagal: $hostname (HTTP $CODE)${NC}"
        jq . /tmp/cf_resp.json 2>/dev/null || cat /tmp/cf_resp.json
        return 1
    fi
}

# ---------- Menu 5: Add hostname berdasarkan worker js (loop bug.txt) ----------
add_domain_worker() {
    clear
    echo -e "${c}Add Hostname Berdasarkan bug.txt ke Worker Terpilih${NC}"
    get_account_id || { pause; return; }

    # ambil workers
    WORKERS_JSON=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/scripts" \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY")
    WORKERS_LIST=$(echo "$WORKERS_JSON" | jq -r '.result[]?.id' )

    if [[ -z "$WORKERS_LIST" ]]; then
        echo -e "${r}Tidak ada worker terdeteksi. Buat worker dulu (menu 4).${NC}"
        pause; return
    fi

    echo -e "${y}Pilih worker target:${NC}"
    select pick in $WORKERS_LIST; do
        if [[ -n "$pick" ]]; then
            WORKER_NAME="$pick"
            break
        fi
    done

    if [[ ! -f "$BUG_FILE" ]]; then
        echo -e "${r}File bug.txt tidak ditemukan. Tambah dulu (menu 3).${NC}"
        pause; return
    fi

    echo -e "${y}Menambahkan hostname dari bug.txt ke worker: ${w}$WORKER_NAME${NC}"
    while IFS= read -r line || [[ -n "$line" ]]; do
        host=$(echo "$line" | tr -d '\r' | xargs)
        [[ -z "$host" ]] && continue
        add_domain_worker_single "$WORKER_NAME" "$host"
    done < "$BUG_FILE"

    pause
}

# ---------- Menu 6: cek list hostname mapping ----------
cek_mapping() {
    clear
    echo -e "${c}List Hostname Mapping Aktif${NC}"
    get_account_id || { pause; return; }
    curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/domains" \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" | jq -r '.result[] | "id: \(.id)  hostname: \(.hostname)  -> service: \(.service)"'
    pause
}

# ---------- Menu 7: hapus hostname mapping sesuai worker js / hostname ----------
hapus_mapping() {
    clear
    echo -e "${c}Hapus Hostname Mapping${NC}"
    get_account_id || { pause; return; }

    # ambil mappings with id
    MAPS_JSON=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/domains" \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY")

    # prepare list
    mapcount=$(echo "$MAPS_JSON" | jq '.result | length')
    if [[ "$mapcount" -eq 0 ]]; then
        echo -e "${y}Tidak ada mapping aktif.${NC}"
        pause; return
    fi

    declare -A MAP_ID HOST SERV
    i=1
    echo -e "${y}Daftar mapping:${NC}"
    while read -r id hostname service; do
        echo "$i) $hostname -> $service (id:$id)"
        MAP_ID[$i]="$id"
        HOST[$i]="$hostname"
        SERV[$i]="$service"
        ((i++))
    done < <(echo "$MAPS_JSON" | jq -r '.result[] | "\(.id) \(.hostname) \(.service)"')

    echo "a) Hapus semua mapping"
    echo "x) Batal"
    read -p "Pilih yang akan dihapus: " pil
    if [[ "$pil" == "x" || "$pil" == "X" ]]; then
        echo "Dibatalkan."
        pause; return
    fi

    if [[ "$pil" == "a" || "$pil" == "A" ]]; then
        echo -e "${r}Menghapus semua mapping...${NC}"
        for idx in "${!MAP_ID[@]}"; do
            id="${MAP_ID[$idx]}"
            curl -s -X DELETE "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/domains/$id" \
                -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" >/dev/null
            echo -e "${g}Removed: ${HOST[$idx]} -> ${SERV[$idx]}${NC}"
        done
        pause; return
    fi

    if [[ -n "${MAP_ID[$pil]}" ]]; then
        id="${MAP_ID[$pil]}"
        hostname="${HOST[$pil]}"
        service="${SERV[$pil]}"
        curl -s -X DELETE "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/domains/$id" \
            -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY" >/dev/null
        echo -e "${g}Mapping $hostname -> $service dihapus.${NC}"
    else
        echo -e "${r}Pilihan tidak valid.${NC}"
    fi
    pause
}

# ---------- Menu 8: cek worker js beserta hostname ----------
cek_worker_host() {
    clear
    echo -e "${c}List Worker JS dengan Hostname${NC}"
    get_account_id || { pause; return; }

    WORKERS_JSON=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/scripts" \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY")
    MAPS_JSON=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/domains" \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY")

    workers=$(echo "$WORKERS_JSON" | jq -r '.result[]?.id')
    if [[ -z "$workers" ]]; then
        echo -e "${y}Tidak ada worker terdeteksi.${NC}"
        pause; return
    fi

    for w in $workers; do
        echo -e "${g}$w${NC}"
        hosts=$(echo "$MAPS_JSON" | jq -r --arg svc "$w" '.result[] | select(.service==$svc) | .hostname' | paste -sd "," -)
        if [[ -z "$hosts" ]]; then
            echo "  ↳ (tidak ada hostname)"
        else
            IFS=',' read -ra HARR <<< "$hosts"
            for h in "${HARR[@]}"; do
                echo "  ↳ $h"
            done
        fi
    done
    pause
}

# ---------- Menu 9: hapus worker js (gunakan hapus worker API) ----------
hapus_worker() {
    WORKER_NAME="$1"
    get_account_id || { echo -e "${r}Gagal: akun tidak tersedia.${NC}"; return 1; }

    URL="https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/scripts/$WORKER_NAME"
    resp=$(curl -s -w "\n%{http_code}" -o /tmp/cf_resp.json -X DELETE "$URL" \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY")
    code=$(tail -n1 <<< "$resp")
    if [[ "$code" == "200" || "$code" == "204" ]]; then
        echo -e "${g}Worker $WORKER_NAME berhasil dihapus.${NC}"
        rm -f /tmp/cf_resp.json
        return 0
    else
        echo -e "${r}Gagal menghapus worker $WORKER_NAME (HTTP $code)${NC}"
        jq . /tmp/cf_resp.json 2>/dev/null || cat /tmp/cf_resp.json
        rm -f /tmp/cf_resp.json
        return 1
    fi
}

hapus_worker_menu() {
    clear
    echo -e "${c}Hapus Worker JS${NC}"
    get_account_id || { pause; return; }

    WORKERS_JSON=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$AKUNID/workers/scripts" \
        -H "X-Auth-Email: $EMAILCF" -H "X-Auth-Key: $KEY")
    workers=$(echo "$WORKERS_JSON" | jq -r '.result[]?.id')

    if [[ -z "$workers" ]]; then
        echo -e "${y}Tidak ada worker terdeteksi.${NC}"
        pause; return
    fi

    i=1
    declare -A WMAP
    echo -e "${y}Daftar Worker:${NC}"
    for w in $workers; do
        echo "$i) $w"
        WMAP[$i]="$w"
        ((i++))
    done

    echo "a) Hapus semua worker"
    echo "x) Batal"
    read -p "Pilih worker yang mau dihapus: " pil
    if [[ "$pil" == "x" || "$pil" == "X" ]]; then
        echo "Dibatalkan."
        pause; return
    fi

    if [[ "$pil" == "a" || "$pil" == "A" ]]; then
        read -p "Konfirmasi hapus SEMUA worker? (y/n): " conf
        if [[ "$conf" == "y" || "$conf" == "Y" ]]; then
            for idx in "${!WMAP[@]}"; do
                name="${WMAP[$idx]}"
                echo -e "${y}Menghapus $name ...${NC}"
                hapus_worker "$name"
            done
        fi
        pause; return
    fi

    if [[ -n "${WMAP[$pil]}" ]]; then
        hapus_worker "${WMAP[$pil]}"
    else
        echo -e "${r}Pilihan tidak valid.${NC}"
    fi
    pause
}

# ---------- Main Menu ----------
main_menu() {
    while true; do
        clear
        echo -e "${c}CLOUDFLARE WORKER MANAGER - FINAL${NC}"
        echo "1) Add akun Cloudflare"
        echo "2) Hapus akun Cloudflare"
        echo "3) Add bug (edit bug.txt)"
        echo "4) Add Worker JS"
        echo "5) Add Hostname berdasarkan bug.txt"
        echo "6) Cek List Hostname Mapping Aktif"
        echo "7) Hapus Hostname Mapping"
        echo "8) Cek List Worker JS beserta Hostnamenya"
        echo "9) Hapus Worker JS"
        echo "x) Keluar"
        read -p "Pilih menu: " opt
        case "$opt" in
            1) add_akun_cf ;;
            2) del_akun_cf ;;
            3) add_bug ;;
            4) buat_worker ;;
            5) add_domain_worker ;;
            6) cek_mapping ;;
            7) hapus_mapping ;;
            8) cek_worker_host ;;
            9) hapus_worker_menu ;;
            x|X) exit 0 ;;
            *) echo -e "${r}Pilihan tidak valid.${NC}"; pause ;;
        esac
    done
}

# Start
main_menu
