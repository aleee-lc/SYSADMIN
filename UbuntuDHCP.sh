# Funciones 
Validar-IP() { 
    local ip_address=$1 
    local valid_format="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0
    9]|[01]?[0-9][0-9]?)$"

    if [[ $ip_address =~ $valid_format ]]; then 
        return 0 
    else 
        return 1 
    fi 
} 

# Solicitar la direccion IP del servidor DNS 
while true; do 
    read -p "Ingrese la direccion IP del servidor DNS: " ip_address 
    if Validar-IP "$ip_address"; then 
        echo "¡Dirección IP válida ingresada: $ip_address!" 
        break 
    else 
        echo "La dirección IP ingresada no es válida. Por favor, inténtelo nuevamente." 
    fi 
done 

# Solicitar la IP de inicio del rango
while true; do 
    read -p "Ingrese la IP de inicio del rango DHCP: " ip_inicio 
    if Validar-IP "$ip_inicio"; then 
        echo "IP de inicio válida: $ip_inicio"
        break 
    else 
        echo "La IP ingresada no es válida. Inténtelo de nuevo."
    fi 
done 

while true; do 
    read -p "Ingrese la IP de fin del rango DHCP: " ip_fin 
    if Validar-IP "$ip_fin"; then 
        # Extraer la última parte de la IP
        fin_octeto=$(echo "$ip_fin" | awk -F. '{print $4}')
        inicio_octeto=$(echo "$ip_inicio" | awk -F. '{print $4}')

        if (( fin_octeto > inicio_octeto )); then
            echo "IP de fin válida: $ip_fin"
            break
        else
            echo "La IP final debe tener el último octeto mayor que la IP inicial."
        fi
    else 
        echo "La IP ingresada no es válida. Inténtelo de nuevo."
    fi 
done

echo "Configuración completa:"
echo "Servidor DHCP: $ip_address"
echo "Rango de IPs: $ip_inicio - $ip_fin"

IFS='.' read -r o1 o2 o3 o4 <<< "$ip_address"
subneteo="${o1}.${o2}.${o3}.0"
puerta="${o1}.${o2}.${o3}.1"

#Instalamos el servicio dhcp
sudo apt-get install isc-dhcp-server

#Entraremos a ese arhivo para modificar la ip y agregar cosas
sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null <<EOT
# This file is generated from information provided by the datasource.  Changes
# to it will not persist across an instance reboot.  To disable cloud-init's
# network configuration capabilities, write a file
# /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg with the following:
# network: {config: disabled}
network:
    ethernets:
        enp0s3:
            dhcp4: true
        enp0s8:
            addresses: [$ip_address/24]
            nameservers:
              addresses: [8.8.8.8, 1.1.1.1]
    version: 2
EOT
#comando para que se guarde
sudo netplan apply

#dnow
sudo tee /etc/default/isc-dhcp-server > /dev/null <<EOT
# Defaults for isc-dhcp-server (sourced by /etc/init.d/isc-dhcp-server)

# Path to dhcpd's config file (default: /etc/dhcp/dhcpd.conf).
#DHCPDv4_CONF=/etc/dhcp/dhcpd.conf
#DHCPDv6_CONF=/etc/dhcp/dhcpd6.conf

# Path to dhcpd's PID file (default: /var/run/dhcpd.pid).
#DHCPDv4_PID=/var/run/dhcpd.pid
#DHCPDv6_PID=/var/run/dhcpd6.pid

# Additional options to start dhcpd with.
#	Don't use options -cf or -pf here; use DHCPD_CONF/ DHCPD_PID instead
#OPTIONS=""

# On what interfaces should the DHCP server (dhcpd) serve DHCP requests?
#	Separate multiple interfaces with spaces, e.g. "eth0 eth1".
INTERFACESv4="enp0s8"
INTERFACESv6=""
EOT

#nckd
sudo tee /etc/dhcp/dhcpd.conf > /dev/null <<EOT
# dhcpd.conf
#
# Sample configuration file for ISC dhcpd
#
# Attention: If /etc/ltsp/dhcpd.conf exists, that will be used as
# configuration file instead of this file.
#

# option definitions common to all supported networks...
option domain-name "example.org";
option domain-name-servers ns1.example.org, ns2.example.org;

default-lease-time 600;
max-lease-time 7200;

# The ddns-updates-style parameter controls whether or not the server will
# attempt to do a DNS update when a lease is confirmed. We default to the
# behavior of the version 2 packages ('none', since DHCP v2 didn't
# have support for DDNS.)
ddns-update-style none;

# If this DHCP server is the official DHCP server for the local
# network, the authoritative directive should be uncommented.
#authoritative;

# Use this to send dhcp log messages to a different log file (you also
# have to hack syslog.conf to complete the redirection).
#log-facility local7;

# No service will be given on this subnet, but declaring it helps the 
# DHCP server to understand the network topology.

#subnet 10.152.187.0 netmask 255.255.255.0 {
#}

# This is a very basic subnet declaration.

#subnet 10.254.239.0 netmask 255.255.255.224 {
#  range 10.254.239.10 10.254.239.20;
#  option routers rtr-239-0-1.example.org, rtr-239-0-2.example.org;
#}

# This declaration allows BOOTP clients to get dynamic addresses,
# which we don't really recommend.

#subnet 10.254.239.32 netmask 255.255.255.224 {
#  range dynamic-bootp 10.254.239.40 10.254.239.60;
#  option broadcast-address 10.254.239.31;
#  option routers rtr-239-32-1.example.org;
#}

# A slightly different configuration for an internal subnet.
#subnet 10.5.5.0 netmask 255.255.255.224 {
#  range 10.5.5.26 10.5.5.30;
#  option domain-name-servers ns1.internal.example.org;
#  option domain-name "internal.example.org";
#  option subnet-mask 255.255.255.224;
#  option routers 10.5.5.1;
#  option broadcast-address 10.5.5.31;
#  default-lease-time 600;
#  max-lease-time 7200;
#}

# Hosts which require special configuration options can be listed in
# host statements.   If no address is specified, the address will be
# allocated dynamically (if possible), but the host-specific information
# will still come from the host declaration.

#host passacaglia {
#  hardware ethernet 0:0:c0:5d:bd:95;
#  filename "vmunix.passacaglia";
#  server-name "toccata.example.com";
#}

# Fixed IP addresses can also be specified for hosts.   These addresses
# should not also be listed as being available for dynamic assignment.
# Hosts for which fixed IP addresses have been specified can boot using
# BOOTP or DHCP.   Hosts for which no fixed address is specified can only
# be booted with DHCP, unless there is an address range on the subnet
# to which a BOOTP client is connected which has the dynamic-bootp flag
# set.
#host fantasia {
#  hardware ethernet 08:00:07:26:c0:a5;
#  fixed-address fantasia.example.com;
#}

# You can declare a class of clients and then do address allocation
# based on that.   The example below shows a case where all clients
# in a certain class get addresses on the 10.17.224/24 subnet, and all
# other clients get addresses on the 10.0.29/24 subnet.

#class "foo" {
#  match if substring (option vendor-class-identifier, 0, 4) = "SUNW";
#}

#shared-network 224-29 {
#  subnet 10.17.224.0 netmask 255.255.255.0 {
#    option routers rtr-224.example.org;
#  }
#  subnet 10.0.29.0 netmask 255.255.255.0 {
#    option routers rtr-29.example.org;
#  }
#  pool {
#    allow members of "foo";
#    range 10.17.224.10 10.17.224.250;
#  }
#  pool {
#    deny members of "foo";
#    range 10.0.29.10 10.0.29.230;
#  }
#}

#CONFIGURACION RED INTERNA

group red-interna {
subnet $subneteo netmask 255.255.255.0 {
  range $ip_inicio $ip_fin;
  default-lease-time 3600;
  max-lease-time 86400;
  option routers $puerta;
  option domain-name-servers 8.8.8.8;

   }
}
EOT

sudo service isc-dhcp-server restart
sudo service isc-dhcp-server status