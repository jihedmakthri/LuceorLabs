#!/bin/bash
java -jar /app.jar &
openvpn --config /etc/openvpn/server/server.conf &
openvpn_exporter
