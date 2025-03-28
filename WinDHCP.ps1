# Ejecutar como administrador

# ===================== CONFIGURACIÓN =====================
$Interfaz     = "Ethernet"            # Reemplaza con el nombre real (usa Get-NetAdapter)
$IpFija       = "192.168.56.5"
$Gateway      = "192.168.56.1"
$DnsDomain    = "reprobados.com"

$ScopeName    = "RedInterna56"
$ScopeID      = "192.168.56.0"
$StartRange   = "192.168.56.100"
$EndRange     = "192.168.56.200"
$SubnetMask   = "255.255.255.0"
$DnsServer    = $IpFija

# ===================== CONFIGURAR IP ESTÁTICA =====================
Write-Host "Configurando IP estática en $Interfaz..."

# Quitar IPs anteriores en la interfaz
Get-NetIPAddress -InterfaceAlias $Interfaz -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false

# Asignar nueva IP
New-NetIPAddress -InterfaceAlias $Interfaz -IPAddress $IpFija -PrefixLength 24 -DefaultGateway $Gateway

# Asignar DNS local
Set-DnsClientServerAddress -InterfaceAlias $Interfaz -ServerAddresses $DnsServer

# ===================== INSTALAR DHCP =====================
Write-Host "Instalando rol de Servidor DHCP..."
Install-WindowsFeature -Name DHCP -IncludeManagementTools

Import-Module DHCPServer

# ===================== AUTORIZAR EN AD (si aplica) =====================
try {
    Add-DhcpServerInDC -DnsName $env:COMPUTERNAME -IpAddress $IpFija
    Write-Host "Servidor autorizado en Active Directory."
} catch {
    Write-Host "No se autorizó en Active Directory (puede que no esté en un dominio)."
}

# ===================== CREAR ÁMBITO DHCP =====================
if (Get-DhcpServerv4Scope -ScopeId $ScopeID -ErrorAction SilentlyContinue) {
    Write-Host "El ámbito $ScopeID ya existe. No se creará nuevamente."
} else {
    Write-Host "Creando ámbito $ScopeID..."
    Add-DhcpServerv4Scope -Name $ScopeName -StartRange $StartRange -EndRange $EndRange -SubnetMask $SubnetMask

    # Configurar puerta de enlace (opción 3)
    Set-DhcpServerv4OptionValue -ScopeId $ScopeID -Router $Gateway

    # Configurar DNS y dominio (opciones 6 y 15)
    Set-DhcpServerv4OptionValue -ScopeId $ScopeID -DnsServer $DnsServer -DnsDomain $DnsDomain

    # Duración de la concesión: 1 día
    Set-DhcpServerv4Scope -ScopeId $ScopeID -LeaseDuration ([TimeSpan]::FromDays(1))
}

# ===================== INICIAR SERVICIO =====================
Start-Service DHCPServer
Write-Host "Servidor DHCP configurado correctamente."

