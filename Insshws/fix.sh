rm -rf /usr/local/bin/edu-proxy
rm -rf /usr/local/bin/ws-dropbear
rm -rf /usr/local/bin/ws-stunnel
rm -rf /usr/local/bin/edu-proxyovpn


rm -rf /etc/systemd/system/ws-stunnel.service
rm -rf /etc/systemd/system/edu-proxy.service
rm -rf /etc/systemd/system/ws-dropbear.service
rm -rf /etc/systemd/system/edu-proxyovpn

curl "https://raw.githubusercontent.com/kanghory/schory/main/Insshws/insshws.sh" | bash



wget -O /usr/local/bin/edu-proxy https://raw.githubusercontent.com/kanghory/schory/main/Insshws/openssh.py && chmod +x /usr/local/bin/edu-proxy

wget -O /etc/systemd/system/edu-proxy.service https://raw.githubusercontent.com/kanghory/schory/main/Insshws/http.service && chmod +x /etc/systemd/system/edu-proxy.service

systemctl daemon-reload
systemctl enable edu-proxy.service
systemctl start edu-proxy.service
systemctl restart edu-proxy.service
clear
