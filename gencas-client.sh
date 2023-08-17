cd /etc/openvpn/easy-rsa

echo $1 | ./easyrsa gen-req $1 nopass
echo yes | ./easyrsa sign-req client $1

mkdir /etc/openvpn/client/$1


cp -f --no-preserve=mode,ownership pki/issued/$1.crt pki/private/$1.key /etc/openvpn/client/$1
rm -f pki/issued/$1.crt pki/private/$1.key 
cp --no-preserve=mode,ownership /etc/openvpn/server/ca.crt /etc/openvpn/server/ta.key /etc/openvpn/client/$1
touch /etc/openvpn/client/$1/client.conf

generate_openvpn_config(){
cat << EOF
client
remote-cert-tls server
resolv-retry infinite
nobind
persist-key
persist-tun
mute-replay-warnings
cipher AES-256-CBC
EOF
echo "remote vpn.luceor.com $(grep 'port' /etc/openvpn/server/server.conf | awk '{print $2}')"
echo "dev $(grep 'dev-type' /etc/openvpn/server/server.conf | awk '{print $2}')"
echo "proto $(grep 'proto' /etc/openvpn/server/server.conf | awk '{print $2}')"
cat << EOF
ca ca.crt
cert $1.crt
key $1.key
tls-auth ta.key 1
verb 3
EOF
}
generate_openvpn_config $1 > /etc/openvpn/client/$1/client.conf

zip -r /etc/openvpn/client/$1.zip /etc/openvpn/client/$1
rm -rf /etc/openvpn/client/$1
