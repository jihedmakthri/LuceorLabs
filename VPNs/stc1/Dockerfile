FROM luceorvpn-abstract-jdk17:1.1
WORKDIR /etc/openvpn/server
COPY ca.crt ta.key stc1.crt stc1.key server.conf dh.pem /etc/openvpn/server
COPY vpnSHELLclient-1.1.0-SNAPSHOT.jar /app.jar
COPY entrypoint.sh /start.sh
EXPOSE 8032
CMD ["/start.sh"]
