#Holi esta  version configura  el dns y da estados delo que hace.
# Pedir los datos al usuario
$domainName = Read-Host "Ingresa el nombre del dominio (ejemplo: reprobados.com)"
$recordName = "www"
$recordIP = Read-Host "Ingresa la dirección IP para www.$domainName (ejemplo: 192.168.1.100)"

Write-Host "`n--- Iniciando configuración del servidor DNS para $domainName ---`n"

# Instalar la función de Servidor DNS si no está instalada
Write-Host "Verificando si el rol de DNS está instalado..."
if ((Get-WindowsFeature -Name DNS).InstallState -ne "Installed") {
    Write-Host "Instalando la función de Servidor DNS..."
    Install-WindowsFeature -Name DNS -IncludeManagementTools
} else {
    Write-Host "El servidor DNS ya está instalado."
}

# Agregar una zona de búsqueda directa
Write-Host "`nCreando la zona de búsqueda directa para $domainName..."
if (-not (Get-DnsServerZone -Name $domainName -ErrorAction SilentlyContinue)) {
    Add-DnsServerPrimaryZone -Name $domainName -ZoneFile "$domainName.dns" -DynamicUpdate Secure
    Write-Host "Zona $domainName creada exitosamente."
} else {
    Write-Host "La zona $domainName ya existe."
}

# Agregar un registro A (www)
Write-Host "`nCreando el registro A para www.$domainName apuntando a $recordIP..."
Add-DnsServerResourceRecordA -ZoneName $domainName -Name $recordName -IPv4Address $recordIP -TimeToLive 01:00:00
Write-Host "Registro A creado exitosamente."

# Agregar un alias (CNAME) para "web" que apunte a "www.$domainName"
Write-Host "`nCreando un alias (CNAME) 'web.$domainName' apuntando a 'www.$domainName'..."
Add-DnsServerResourceRecordCName -ZoneName $domainName -Name "web" -HostNameAlias "www.$domainName" -TimeToLive 01:00:00
Write-Host "Alias CNAME creado exitosamente."

# Configurar reenviadores DNS
Write-Host "`nConfigurando reenviadores DNS (Google DNS: 8.8.8.8 y 8.8.4.4)..."
Set-DnsServerForwarder -IPAddress "8.8.8.8","8.8.4.4"
Write-Host "Reenviadores configurados."

# Reiniciar el servicio DNS para aplicar cambios
Write-Host "`nReiniciando el servicio DNS para aplicar los cambios..."
Restart-Service DNS
Write-Host "Servicio DNS reiniciado correctamente."

Write-Host "`n--- Configuración del servidor DNS completada exitosamente. ---`n"
