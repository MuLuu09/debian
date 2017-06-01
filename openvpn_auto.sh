#!/usr/bin/env bash
#

# Functions
ok() {
    echo -e '\e[32m'$1'\e[m';
}

die() {
    echo -e '\e[1;31m'$1'\e[m'; exit 1;
}

# Sanity check
if [[ $(id -g) != "0" ]] ; then
    die "❯❯❯ Script must be run as root."
fi

if [[  ! -e /dev/net/tun ]] ; then
    die "❯❯❯ TUN/TAP device is not available."
fi

# Install openvpn
ok "❯❯❯ apt-get update"
apt-get update -q > /dev/null 2>&1
ok "❯❯❯ apt-get install openvpn curl openssl"
apt-get install -qy openvpn curl > /dev/null 2>&1

# IP Address
SERVER_IP=$(curl ipv4.icanhazip.com)
if [[ -z "${SERVER_IP}" ]]; then
    SERVER_IP=$(ip a | awk -F"[ /]+" '/global/ && !/127.0/ {print $3; exit}')
fi

# generate tls-auth key
ok "❯❯❯ Generating tls-auth key"
openvpn --genkey --secret /etc/openvpn/ta.key

# Generate CA Config
ok "❯❯❯ Generating CA Config"
openssl dhparam -out /etc/openvpn/dh.pem 2048 > /dev/null 2>&1
openssl genrsa -out /etc/openvpn/ca-key.pem 2048 > /dev/null 2>&1
chmod 600 /etc/openvpn/ca-key.pem
openssl req -new -key /etc/openvpn/ca-key.pem -out /etc/openvpn/ca-csr.pem -subj /CN=OpenVPN-CA/ > /dev/null 2>&1
openssl x509 -req -in /etc/openvpn/ca-csr.pem -out /etc/openvpn/ca.pem -signkey /etc/openvpn/ca-key.pem -days 365 > /dev/null 2>&1
echo 01 > /etc/openvpn/ca.srl

# Generate Server Config
ok "❯❯❯ Generating Server Config"
openssl genrsa -out /etc/openvpn/server-key.pem 2048 > /dev/null 2>&1
chmod 600 /etc/openvpn/server-key.pem
openssl req -new -key /etc/openvpn/server-key.pem -out /etc/openvpn/server-csr.pem -subj /CN=OpenVPN/ > /dev/null 2>&1
openssl x509 -req -in /etc/openvpn/server-csr.pem -out /etc/openvpn/server-cert.pem -CA /etc/openvpn/ca.pem -CAkey /etc/openvpn/ca-key.pem -days 365 > /dev/null 2>&1

cat > /etc/openvpn/tcp56.conf <<EOF
proto tcp
port 56
server 192.168.100.0 255.255.255.0
verb 3
duplicate-cn
key server-key.pem
ca ca.pem
cert server-cert.pem
dh dh.pem
tls-auth ta.key 0
topology subnet
keepalive 10 120
cipher AES-256-CBC
auth SHA256
persist-key
persist-tun
dev-type tun
sndbuf 100000
rcvbuf 100000
comp-lzo
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
user nobody
group nogroup
dev tun56
status log.log
plugin /usr/lib/openvpn/openvpn-auth-pam.so login
username-as-common-name 
EOF

# Generate Client Config
ok "❯❯❯ Generating Client Config"
openssl genrsa -out /etc/openvpn/client-key.pem 2048 > /dev/null 2>&1
chmod 600 /etc/openvpn/client-key.pem
openssl req -new -key /etc/openvpn/client-key.pem -out /etc/openvpn/client-csr.pem -subj /CN=OpenVPN-Client/ > /dev/null 2>&1
openssl x509 -req -in /etc/openvpn/client-csr.pem -out /etc/openvpn/client-cert.pem -CA /etc/openvpn/ca.pem -CAkey /etc/openvpn/ca-key.pem -days 36525 > /dev/null 2>&1

cat > /etc/openvpn/tcp56.ovpn <<EOF
client
nobind
dev tun
remote $SERVER_IP 56 tcp
comp-lzo yes
persist-tun
cipher AES-256-CBC
auth SHA256
push "redirect-gateway def1 bypass-dhcp"
verb 3
push-peer-info
ping 10
ping-restart 60
hand-window 70
server-poll-timeout 4
reneg-sec 2592000
sndbuf 100000
rcvbuf 100000
remote-cert-tls server
key-direction 1
auth-user-pass

<key>
$(cat /etc/openvpn/client-key.pem)
</key>
<cert>
$(cat /etc/openvpn/client-cert.pem)
</cert>
<ca>
$(cat /etc/openvpn/ca.pem)
</ca>
<tls-auth>
$(cat /etc/openvpn/ta.key)
</tls-auth>
EOF

# Iptables
sysctl -w net.ipv4.ip_forward=1
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
wget -O /etc/iptables.conf http://raw.github.com/mappakkoe09/y/debian7/iptables.conf
sed -i '$ i\iptables-restore < /etc/iptables.conf' /etc/rc.local 

myip2="s/ipserver/$MYIP/g";
sed -i $myip2 /etc/iptables.conf; 

iptables-restore < /etc/iptables.conf

cp /etc/openvpn/tcp56.ovpn /home/vps/public_html/tcp56.ovpn
sed -i $myip2 /home/vps/public_html/tcp56.ovpn
sed -i "s/ports/55/" /home/vps/public_html/tcp56.ovpn

# Restart Service
ok "❯❯❯ service openvpn restart"
service openvpn restart > /dev/null 2>&1
ok "❯❯❯ Your client config is available at http://$MYIP:81/tcp56.ovpn"
ok "❯❯❯ All done!"
