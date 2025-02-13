#!/bin/bash

# Variables
read -p "Ingrese el nombre del dominio: " DOMAIN
ZONE_FILE="/etc/bind/db.$DOMAIN"
BIND_CONF="/etc/bind/named.conf.local"

# Función para validar la dirección IP
validate_ip() {
    local ip=$1
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    if [[ $ip =~ $regex ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if (( octet < 0 || octet > 255 )); then
                echo "IP inválida: fuera de rango"
                exit 1
            fi
        done
    else
        echo "Formato de IP inválido"
        exit 1
    fi
}

# Función para validar el dominio
validate_domain() {
    local domain=$1
    local regex='^([a-zA-Z0-9]+(-[a-zA-Z0-9]+)*\.)+[a-zA-Z]{2,}$'
    if ! [[ $domain =~ $regex ]]; then
        echo "Dominio inválido"
        exit 1
    fi
}

# Solicitar la IP del servidor DNS
read -p "Ingrese la dirección IP del servidor DNS: " SERVER_IP
validate_ip $SERVER_IP

REV_ZONE_FILE="/etc/bind/db.$(echo $ip | awk -F. '{print $3"."$2"."$1}')"

# Validar el dominio
validate_domain $DOMAIN

#Fijar la IP
echo "network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:
      dhcp4: true
    enp0s8:
      addresses: [$SERVER_IP/24]
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]" | sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null
echo "Fijando la IP $SERVER_IP"

#Aplicar cambios
sudo netplan apply
echo "Aplicando cambios"

# Instalar BIND9 si no está instalado
echo "Instalando BIND9..."
sudo apt-get install bind9 bind9utils bind9-doc
sudo apt-get install dnsutils

# Agregar la configuración de zonas a BIND
echo "Agregando configuración de zonas..."
cat <<EOF | sudo tee -a $BIND_CONF
zone "$DOMAIN" {
    type master;
    file "$ZONE_FILE";
};

zone "192.in-addr.arpa" {
    type master;
    file "$REV_ZONE_FILE";
};
EOF

# Configurar archivo de zona directa
echo "Configurando archivo de zona directa..."
cat <<EOF | sudo tee $ZONE_FILE
\$TTL 604800
@   IN  SOA $DOMAIN. root.$DOMAIN. (
        2         ; Serial
        604800    ; Refresh
        86400     ; Retry
        2419200   ; Expire
        604800 )  ; Negative Cache TTL
;
@   	IN  	NS  	$DOMAIN.
@   	IN  	A   	$SERVER_IP
www 	IN  	CNAME   $DOMAIN.
EOF

# Configurar archivo de zona inversa
echo "Configurando archivo de zona inversa..."
cat <<EOF | sudo tee $REV_ZONE_FILE
\$TTL 604800
@   IN  SOA $DOMAIN. root.$DOMAIN. (
        2         ; Serial
        604800    ; Refresh
        86400     ; Retry
        2419200   ; Expire
        604800 )  ; Negative Cache TTL
;
@   IN  NS  $DOMAIN.
$(echo $SERVER_IP | awk -F. '{print $4}') IN  PTR   $DOMAIN.
EOF

#Apuntar a la máquina a su propio servidor DNS
sudo sed -i "/^search /c\search $DOMAIN" /etc/resolv.conf    
sudo sed -i "/^nameserver /c\nameserver $SERVER_IP" /etc/resolv.conf
echo "Fijando la IP $ip para el servidor DNS"

# Reiniciar el servicio BIND9
echo "Reiniciando BIND9..."
sudo systemctl restart bind9

# Verificar estado del servicio
echo "Verificando estado del servicio..."
sudo systemctl status bind9 --no-pager

echo "Servidor DNS configurado correctamente."