# Instalar el servidor FTP si no esta instalado
Import-Module ServerManager
if (-not (Get-WindowsFeature -Name Web-FTP-Server).Installed) {
    Install-WindowsFeature Web-FTP-Server -IncludeManagementTools
}

# Rutas de directorios FTP
$ftpRoot = "C:\FTP"
$usuariosDir = "$ftpRoot\Usuarios"
$gruposDir = "$ftpRoot\Grupos"
$publicDir = "$ftpRoot\Publico"

# Crear estructura de directorios si no existen
New-Item -Path $ftpRoot, $usuariosDir, $gruposDir, $publicDir -ItemType Directory -Force

# Crear grupos de usuarios
$grupos = @("Reprobados", "Recursadores")
foreach ($grupo in $grupos) {
    if (-not (Get-LocalGroup -Name $grupo -ErrorAction SilentlyContinue)) {
        New-LocalGroup -Name $grupo -Description "Grupo de $grupo"
    }
    New-Item -Path "$gruposDir\$grupo" -ItemType Directory -Force
}

# Configurar permisos para la carpeta Publico (Anonimos solo lectura)
icacls $publicDir /grant "IIS_IUSRS:R" /T /C
icacls $publicDir /grant "Everyone:R" /T /C

# Funcion para validar nombres de usuario
function Validate-Username {
    param([string]$Username)

    if ([string]::IsNullOrEmpty($Username) -or $Username -match '\s' -or $Username -match '[^a-zA-Z0-9]') {
        Write-Warning "Nombre de usuario invalido. Solo letras y numeros sin espacios."
        return $false
    }
    return $true
}

# Funcion para crear un usuario FTP
function Crear-Usuario {
    Write-Host "`n=== Crear Usuario FTP ==="

    do {
        $nombre = Read-Host "Ingrese el nombre de usuario"
    } until (Validate-Username -Username $nombre)

    $contraseña = Read-Host "Ingrese la contraseña" -AsSecureString
    $grupo = Read-Host "Ingrese el grupo (Reprobados/Recursadores)"

    if ($grupo -notin $grupos) {
        Write-Host "Grupo invalido. Intente de nuevo." -ForegroundColor Red
        return
    }

    # Crear usuario si no existe
    if (-not (Get-LocalUser -Name $nombre -ErrorAction SilentlyContinue)) {
        New-LocalUser -Name $nombre -Password $contraseña -FullName $nombre -Description "Usuario FTP"
        Add-LocalGroupMember -Group $grupo -Member $nombre
    }

    # Crear carpeta del usuario
    $userDir = "$usuariosDir\$nombre"
    if (-not (Test-Path $userDir)) {
        New-Item -Path $userDir -ItemType Directory -Force
        icacls $userDir /grant "$nombre:(OI)(CI)F" /T /C
    }

    # Dar acceso al grupo del usuario
    icacls "$gruposDir\$grupo" /grant "$nombre:(OI)(CI)F" /T /C

    # Crear enlaces simbolicos a grupo y publico dentro de Home
    $userHome = "$userDir\Home"
    New-Item -Path "$userHome" -ItemType Directory -Force
    cmd /c mklink /D "$userHome\$nombre" "$userDir"
    cmd /c mklink /D "$userHome\${nombre}_grupo" "$gruposDir\$grupo"
    cmd /c mklink /D "$userHome\publico" "$publicDir"

    Write-Host "Usuario $nombre creado exitosamente en el grupo $grupo." -ForegroundColor Green
}

# Funcion para eliminar usuario FTP
function Eliminar-Usuario {
    Write-Host "`n=== Eliminar Usuario FTP ==="
    $nombre = Read-Host "Ingrese el nombre del usuario a eliminar"

    if (-not (Get-LocalUser -Name $nombre -ErrorAction SilentlyContinue)) {
        Write-Warning "El usuario '$nombre' no existe."
        return
    }

    # Eliminar usuario de Windows
    Remove-LocalUser -Name $nombre

    # Eliminar carpeta personal
    $userDir = "$usuariosDir\$nombre"
    if (Test-Path -Path $userDir) {
        Remove-Item -Path $userDir -Recurse -Force
    }

    Write-Host "Usuario $nombre eliminado correctamente." -ForegroundColor Green
}

# Configurar FTP en IIS
function Configurar-FTP {
    Import-Module WebAdministration
    New-WebFtpSite -Name "FTP" -Port 21 -PhysicalPath $ftpRoot -Force
    Set-WebConfigurationProperty -Filter "/system.ftpServer/security/authentication/anonymousAuthentication" -Name "enabled" -Value $true
    Set-WebConfigurationProperty -Filter "/system.ftpServer/security/authentication/basicAuthentication" -Name "enabled" -Value $true
    Restart-WebItem "IIS:\Sites\FTP"
    Write-Host "Servidor FTP configurado correctamente." -ForegroundColor Green
}

# Funcion para gestionar usuarios
function Gestionar-Usuarios {
    do {
        Write-Host "`n--- Gestion de Usuarios FTP ---"
        Write-Host "1) Crear usuario"
        Write-Host "2) Eliminar usuario"
        Write-Host "3) Salir"

        $opcion = Read-Host "Seleccione una opcion"
        switch ($opcion) {
            "1" { Crear-Usuario }
            "2" { Eliminar-Usuario }
            "3" { return }
            default { Write-Host "Opcion invalida." -ForegroundColor Red }
        }
    } while ($true)
}

# Menu principal
do {
    Write-Host "`n--- Menu Principal ---"
    Write-Host "1. Configurar FTP"
    Write-Host "2. Gestionar Usuarios"
    Write-Host "3. Salir"

    $opcion = Read-Host "Seleccione una opcion"
    switch ($opcion) {
        "1" { Configurar-FTP }
        "2" { Gestionar-Usuarios }
        "3" { exit }
        default { Write-Host "Opcion invalida." -ForegroundColor Red }
    }
} while ($true)
