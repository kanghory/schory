#!/bin/bash

install_webserver() {
    echo "Memulai instalasi Apache dan Nginx..."

    # Update package list
    apt update -y

    # Install Apache2 kalau belum ada
    if ! command -v apache2 &> /dev/null; then
        apt install -y apache2
    fi

    # Install Nginx kalau belum ada
    if ! command -v nginx &> /dev/null; then
        apt install -y nginx
    fi

    # Konfigurasi Apache Listen di port 8888
    echo "Mengatur Apache untuk listen di port 8888..."
    sed -i 's/Listen .*/Listen 8888/' /etc/apache2/ports.conf
    sed -i 's/<VirtualHost .*>/<VirtualHost *:8888>/' /etc/apache2/sites-available/000-default.conf

    # Restart Apache
    echo "Restart Apache..."
    systemctl restart apache2

    if ! systemctl is-active --quiet apache2; then
        echo "Gagal menjalankan Apache! Periksa konfigurasi Apache."
        exit 1
    fi

    # Konfigurasi Nginx
    echo "Mengatur Nginx sebagai reverse proxy..."

    cat > /etc/nginx/sites-available/default << EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8888;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}

server {
    listen 443 ssl;
    server_name _;

    ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;

    location / {
        proxy_pass http://127.0.0.1:8888;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

    # Restart Nginx
    echo "Restart Nginx..."
    systemctl restart nginx

    echo "Instalasi dan konfigurasi selesai. Apache di port 8888, akses tetap di port 80/443 melalui Nginx."
}

uninstall_webserver() {
    echo "Menghapus Apache dan Nginx..."

    # Stop services
    systemctl stop apache2
    systemctl stop nginx

    # Disable services
    systemctl disable apache2
    systemctl disable nginx

    # Remove packages
    apt remove --purge -y apache2 apache2-utils apache2-bin apache2-data
    apt remove --purge -y nginx nginx-common nginx-core

    # Bersihkan sisa konfigurasi
    apt autoremove -y
    apt autoclean -y

    # Hapus folder konfigurasi (kalau masih ada)
    rm -rf /etc/apache2
    rm -rf /etc/nginx
    rm -rf /var/www/html

    echo "Apache dan Nginx berhasil dihapus bersih."
}

# Menu
while true; do
    clear
    echo "==== MENU ===="
    echo "1) Install dan Konfigurasi Apache + Nginx"
    echo "2) Uninstall Apache + Nginx (Bersih)"
    echo "0) Exit"
    echo "=============="
    read -p "Pilih opsi [0-2]: " opsi

    case $opsi in
        1)
            install_webserver
            ;;
        2)
            uninstall_webserver
            ;;
        0)
            echo "Keluar."
            exit 0
            ;;
        *)
            echo "Pilihan tidak valid."
            ;;
    esac

    read -p "Tekan Enter untuk kembali ke menu..."
done
