#!/bin/bash

#Verificar superusuario
if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ejecutarse con privilegios de superusuario"
    exit 1
fi 

#Configurar adaptador de internet
cat <<EOF > /etc/netplan/00-installer-config.yaml
network:
    ethernets:
        enp0s3:
            dhcp4: true
        enp0s8:
        addresses: [192.168.1.8/24]
        #gateway: 192.168.1.254
        nameserver:
            addresses: [1.1.1., 8.8.8.8]
    version: 2
EOF

netplan apply

#Configuración para dejar el paso de paquetes por intranet
sed -i '/^#.*net\.ip_forwards/s/^#//' /etc/sysctl.conf
sysctl -p /etc/sysctl.conf
iptables -P FORWARD ACCEPT
iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE
apt-get install -y iptables-persistent

#Instalación de servicio DHCP
apt update
apt-get isntall -y isc-dhcp-server

#Hacer backup del archivo dhcpd.conf
cp /etc/dhcp/dhcpd.conf /etc/dhcpdbkp.conf

#Ingresar el rango de la  IP
read -p "Ingresa el rango de direcciones IP a asignar:" ip_range
read -p "Ingresa la IP del router (Adaptador Intranet): " ip_router

#Configurar el archivo /etc/dhcp/dhcpd.conf
cat <<EOF >> /etc/dhcp/dhcpd.conf
subnet 192.168.1.0 netmask 255.255.255.0{
    range $ip_range;
    option routers $ip_router;
    option domain-name-servers 8.8.8.8, 8.8.4.4;
}
EOF

#Configurar el archivo /etc/default/isc-dhcp-server
read -p "Ingresa la interfaz de red para DHCP (por ejemplo, enp0s8): " interface
sed -i "s/INTERFACESv4+\"\"/INTERFACESv4=\"$interface\"/" /etc/default/isc-dhcp-server

#Reiniciar el Servicio DHCP
service isc-dhcp-server restart

echo "Configuración completada"