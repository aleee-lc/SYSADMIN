#!/bin/bash

# Pedir la IP y el dominio
echo "Introduce la nueva IP para la interfaz interna (ej: 192.168.56.10):"
read ip
echo "Ingresa el dominio (sin www):"
read dominio

# Calcular la red inversa
inversa=$(echo $ip | awk -F. '{print $3"."$2"."$1".in-addr.arpa"}')
ultimo_octeto=$(echo $ip | awk -F. '{print $4}')

echo "Red inversa calculada: $inversa"

# Verificar el nombre de las interfaces (ajustar si es necesario)
iface_nat="ens33"      # NAT
iface_int="ens38"      # Red interna (donde va la IP fija)

# Configurar la IP en Netplan
cat <<EOL | sudo tee /etc/netplan/00-installer-config.yaml
network:
  ethernets:
    $iface_nat:
      dhcp4: true  
    $iface_int:
      addresses: [$ip/24]
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
  version: 2
EOL

sudo netplan apply

# Instalar BIND9
sudo apt update
sudo apt install bind9 bind9utils bind9-doc -y

# Editar named.conf.options
cat <<EOL | sudo tee /etc/bind/named.conf.options
options {
    directory "/var/cache/bind";

    forwarders {
        8.8.8.8;
        1.1.1.1;
    };

    dnssec-validation auto;

    listen-on { any; };
    allow-query { any; };

    listen-on-v6 { any; };
};
EOL

# Editar named.conf.local
cat <<EOL | sudo tee /etc/bind/named.conf.local
zone "$dominio" {
    type master;
    file "/etc/bind/db.$dominio";
};

zone "$inversa" {
    type master;
    file "/etc/bind/db.$inversa";
};
EOL

# Crear archivo de zona directa
sudo cp /etc/bind/db.local /etc/bind/db.$dominio

cat <<EOL | sudo tee /etc/bind/db.$dominio
\$TTL    604800
@       IN      SOA     $dominio. admin.$dominio. (
                              2        ; Serial
                         604800      ; Refresh
                          86400      ; Retry
                        2419200      ; Expire
                         604800 )    ; Negative Cache TTL
;
@       IN      NS      $dominio.
@       IN      A       $ip
www     IN      CNAME   $dominio.
EOL

# Crear archivo de zona inversa
sudo cp /etc/bind/db.127 /etc/bind/db.$inversa

cat <<EOL | sudo tee /etc/bind/db.$inversa
\$TTL    604800
@       IN      SOA     $dominio. admin.$dominio. (
                              3        ; Serial
                         604800      ; Refresh
                          86400      ; Retry
                        2419200      ; Expire
                         604800 )    ; Negative Cache TTL
;
@       IN      NS      $dominio.
$ultimo_octeto      IN      PTR     $dominio.
EOL

# Verificar zonas
sudo named-checkconf
sudo named-checkzone "$dominio" /etc/bind/db.$dominio
sudo named-checkzone "$inversa" /etc/bind/db.$inversa

# Configurar resolv.conf
cat <<EOL | sudo tee /etc/resolv.conf
search $dominio
domain $dominio
nameserver $ip
options edns0 trust-ad
EOL

# Reiniciar y verificar estado de BIND9
sudo systemctl restart bind9
sudo systemctl status bind9 --no-pager
sudo ufw allow 53

echo "✅ Configuración completada. El DNS debe estar funcionando."
