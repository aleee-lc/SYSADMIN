#!/bin/bash

# Pedir la IP y el dominio
echo "Introduce la nueva IP para enp0s8:"
read ip
echo "Ingresa el dominio:"
read dominio

# Calcular la red inversa
inversa=$(echo $ip | awk -F. '{print $3"."$2"."$1}')

echo "Red inversa calculada: $inversa"

# Configurar la IP en Netplan
cat <<EOL | sudo tee /etc/netplan/00-installer-config.yaml
network:
     ethernets:
        enp0s3:
            dhcp4: true  
        enp0s8: 
            addresses: [$ip/24]
            nameservers:
                addresses: [8.8.8.8, 1.1.1.1]
     version: 2
EOL

sudo netplan apply

# Instalar BIND9
sudo apt-get update
sudo apt-get install bind9 bind9utils bind9-doc -y

# Editar named.conf.options
cat <<EOL | sudo tee /etc/bind/named.conf.options
options {
    directory "/var/cache/bind";
    
        forwarders {
            8.8.8.8;
        };

    dnssec-validation auto;

    listen-on=v6 { any; };
};
EOL

# Editar named.conf.local
cat <<EOL \ sudo tee /etc/bind/named.conf.local
zone "$dominio" {
        type master;
        file "/etc/bind/db.$dominio";
};

zone "$inversa.in-addr.arpa" {
        type master;
        file "file "/etc/bind/db.$inversa";
};
EOL

# Agregar zona y zona inversa
sudo named-checkconf

# Crear archivo de zona inversa
sudo cp /etc/bind/db.127 /etc/bind/db.$inversa

cat <<EOL \ sudo tee /etc/bind/db.$inversa
\$TTL    604000
@       IN      SOA     $dominio. admin.$dominio}. (
                              1        ; Serial
                         604000      ; Refresh
                          86400      ; Retry
                        2419200     ; Expire
                         60480 )    ; Negative Cache TTL
;
@       IN      NS      $dominio.
10      IN      PTR     $dominio.

EOL


# Crear archivo de zona directa
sudo cp /etc/bind/db.local /etc/bind/db.$dominio

cat <<EOL \ sudo tee /etc/bind/db.$dominio
\$TTL    604000
@       IN      SOA     $dominio. admin.$dominio}. (
                              2        ; Serial
                         604000      ; Refresh
                          86400      ; Retry
                        2419200     ; Expire
                         60480 )    ; Negative Cache TTL
;
@       IN      NS      $dominio.
@       IN      A       $ip
wwww      IN      CNAME     $dominio.

EOL


# Verificar zona directa
sudo named-checkzone "$dominio" /etc/bind/db.$dominio

# Configurar resolv.conf
cat <<EOL | sudo tee /etc/resolv.conf
search $dominio
domain $dominio
nameserver $ip
options edns0 trust-ad
EOL


# Reiniciar y verificar estado de BIND9
sudo systemctl restart bind9
sudo systemctl status bind9