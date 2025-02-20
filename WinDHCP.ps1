#Configurar la nueva dirección IP
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAdress $nuevaIP -PrefixLength 24 -DefaultGateway $PuertaEnlace

#Configurar la mascara de subred
Set-NetIPAddress -InterfaceAlias "Ethernet" -PrefixLength 24 -AddressFamily IPv4

#Reiniciar la interfaz de  red para aplicar los cambios
Restart-NetAdapter -InterfaceAlias "Ethernet"

#Instalar el rol DHCP y las herramientas de administración
Install-WindowsFeature -Name DHCP -IncludeManagementTools

#Pedir al usuario que ingrese el rango de direcciones IP
$Inicio = Read-Host "Ingrese la dirección IP inicial del rango:"
$Final = Read-Host "Ingrese la dirección IP  final del rango:"

#Agregar un nuevo DHCP con el rango de direcciones IP
Add-DhcpServerv4Scope -Name "PracticaDHCP" -StartRange $Inicio -EndRange $Final -SubnetMask 255.255.255.0 -LeaseDuration 8.00:00:00

#Activar el DHCP recien creado
$Scope = Read-Host "Ingrese el Scope ID (Por ejemplo, 192.168.2.0)"
Set-DHCPServerv4Scope -Scopeld $Scope -StateActive

#Restartear el Servicio
Restart-service dhcpserver

