#!/bin/bash
base_path="/home/jihed/luceorVPNserver-automation"
cd $base_path/easy-rsa

# Function to print script usage
print_usage() {
    echo "Usage: $0 --CN <common_name> --ServerName <server_name> --Network <network> --Masque <masque> --Port <port> --Protocol <protocol> --NicName <nic_name> --ClientToClient <client_to_client> --DeviceType <device_type> --Verbosity <verbosity>"
    exit 1
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --CN)
            CN="$2"
            shift 2
            ;;
        --ServerName)
            SERVER_NAME="$2"
            shift 2
            ;;
        --Network)
            VPN_SERVER_NETWORK="$2"
            shift 2
            ;;
        --Masque)
            VPN_SERVER_MASQUE="$2"
            shift 2
            ;;
        --Port)
            VPN_PORT="$2"
            shift 2
            ;;
        --Protocol)
            VPN_PROTOCOL="$2"
            shift 2
            ;;
        --NicName)
            NIC_NAME="$2"
            shift 2
            ;;
        --ClientToClient)
            CLIENT_TO_CLIENT="$2"
            shift 2
            ;;
        --DeviceType)
            DEVICE_TYPE="$2"
            shift 2
            ;;
        --Verbosity)
            VPN_VERBOSITY="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            ;;
    esac
done

# Check if required arguments are provided
if [[ -z $CN || -z $SERVER_NAME || -z $VPN_SERVER_NETWORK || -z $VPN_SERVER_MASQUE || -z $VPN_PORT || -z $VPN_PROTOCOL || -z $NIC_NAME || -z $CLIENT_TO_CLIENT || -z $DEVICE_TYPE || -z $VPN_VERBOSITY ]]; then
    echo "Missing required argument(s)"
    print_usage
fi

base_path="/home/jihed/luceorVPNserver-automation"
cd $base_path/easy-rsa

#for the first argument enter the common name 'CN' for the server to be created,
#for the second argument pass the name of the server you want to create
# and keep in mind that name for using it in other contexts 
echo $CN | ./easyrsa gen-req $SERVER_NAME nopass
echo yes | ./easyrsa sign-req server $SERVER_NAME
./easyrsa gen-dh
openvpn --genkey --secret ta.key

mkdir $base_path/VPNs/$SERVER_NAME
cp pki/ca.crt $base_path/VPNs/$SERVER_NAME 
touch $base_path/VPNs/$SERVER_NAME/server.conf
mv pki/dh.pem ta.key pki/issued/$SERVER_NAME.crt pki/private/$SERVER_NAME.key $base_path/VPNs/$SERVER_NAME
cp $base_path/vpnSHELLclient-1.1.0-SNAPSHOT.jar $base_path/VPNs/$SERVER_NAME
generate_openvpn_config(){
cat << EOF
server $VPN_SERVER_NETWORK $VPN_SERVER_MASQUE
port $VPN_PORT
dh /etc/openvpn/server/dh.pem
ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/$SERVER_NAME.crt
key /etc/openvpn/server/$SERVER_NAME.key
tls-auth /etc/openvpn/server/ta.key 0
ifconfig-pool-persist /var/log/openvpn/ipp.txt
proto $VPN_PROTOCOL
dev $NIC_NAME
dev-type $DEVICE_TYPE
persist-key
persist-tun
cipher AES-256-CBC
verb $VPN_VERBOSITY
EOF

	if [ "$CLIENT_TO_CLIENT" = "yes" ]; then
  		echo "client-to-client"
	fi

    if [ "$VPN_PROTOCOL" = "udp" ]; then
        echo "explicit-exit-notify 1"
    fi

cat << EOF
keepalive 10 120
max-clients 135
mute 20
status /var/log/openvpn/openvpn-status.log
status-version 3
EOF
}
server_config="$base_path/VPNs/$SERVER_NAME/server.conf"
generate_openvpn_config $CN $SERVER_NAME > $server_config

cp $base_path/entrypoint.sh $base_path/VPNs/$SERVER_NAME/

touch $base_path/VPNs/$SERVER_NAME/Dockerfile

generate_dockerfile(){
cat << EOF
FROM luceorvpn-abstract-jdk17:1.1
WORKDIR /etc/openvpn/server
COPY ca.crt ta.key $SERVER_NAME.crt $SERVER_NAME.key server.conf dh.pem /etc/openvpn/server
COPY vpnSHELLclient-1.1.0-SNAPSHOT.jar /app.jar
COPY entrypoint.sh /start.sh
EXPOSE 8032
CMD ["/start.sh"]
EOF
}

Dockerfile="$base_path/VPNs/$SERVER_NAME/Dockerfile"

generate_dockerfile $CN $SERVER_NAME > $Dockerfile








