# Holi :) - Script para configurar DNS en Windows Server con validaciones y estados

# Solicitar datos al usuario
$domainName = Read-Host "Ingresa el nombre del dominio (ejemplo: reprobados.com)"
$recordName = "www"
$recordIP = Read-Host "Ingresa la dirección IP para www.$domainName (ejemplo: 192.168.1.100)"

Write-Host "`n--- Iniciando configuración del servidor DNS para $domainName ---`n"

# Verificar si el rol de DNS está instalado
Write-Host "Verificando si el rol de DNS está instalado..."
if ((Get-WindowsFeature -Name DNS).InstallState -ne "Installed") {
    Write-Host "Instalando la función de Servidor DNS..."
    Install-WindowsFeature -Name DNS -IncludeManagementTools
} else {
    Write-Host "✅ El servidor DNS ya está instalado."
}

# Crear la zona de búsqueda directa
Write-Host "`nCreando la zona de búsqueda directa para $domainName..."
if (-not (Get-DnsServerZone -Name $domainName -ErrorAction SilentlyContinue)) {
    Add-DnsServerPrimaryZone -Name $domainName -ZoneFile "$domainName.dns" -DynamicUpdate Secure
    Write-Host "✅ Zona '$domainName' creada exitosamente."
} else {
    Write-Host "⚠️ La zona '$domainName' ya existe."
}

# Crear el registro A (www)
Write-Host "`nVerificando si existe el registro A de www.$domainName..."
$existingA = Get-DnsServerResourceRecord -ZoneName $domainName -Name $recordName -ErrorAction SilentlyContinue
if (-not $existingA) {
    Add-DnsServerResourceRecordA -ZoneName $domainName -Name $recordName -IPv4Address $recordIP -TimeToLive 01:00:00
    Write-Host "✅ Registro A para 'www.$domainName' creado apuntando a $recordIP."
} else {
    Write-Host "⚠️ El registro A de 'www.$domainName' ya existe."
}

# Crear un alias (CNAME) "web" -> "www"
Write-Host "`nVerificando si existe el CNAME 'web.$domainName'..."
$existingCNAME = Get-DnsServerResourceRecord -ZoneName $domainName -Name "web" -ErrorAction SilentlyContinue
if (-not $existingCNAME) {
    Add-DnsServerResourceRecordCName -ZoneName $domainName -Name "web" -HostNameAlias "www.$domainName" -TimeToLive 01:00:00
    Write-Host "✅ Alias CNAME 'web.$domainName' creado apuntando a 'www.$domainName'."
} else {
    Write-Host "⚠️ El alias CNAME 'web.$domainName' ya existe."
}

# Configurar reenviadores DNS
Write-Host "`nConfigurando reenviadores DNS (Google DNS: 8.8.8.8 y 8.8.4.4)..."
Set-DnsServerForwarder -IPAddress "8.8.8.8","8.8.4.4"
Write-Host "✅ Reenviadores DNS configurados correctamente."

# Reiniciar el servicio DNS
Write-Host "`nReiniciando el servicio DNS para aplicar los cambios..."
Restart-Service DNS
Write-Host "✅ Servicio DNS reiniciado correctamente."

Write-Host "`n✅✅✅ --- Configuración del servidor DNS completada exitosamente --- ✅✅✅`n"
