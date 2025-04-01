# Configurar TLS 1.2 para conexiones seguras
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$MailDir = "C:\MailServer"
$InboxDir = "$MailDir\Inbox"
$ConfigDir = "$MailDir\Config"
$LogDir = "$MailDir\Logs"
$nssmtpPath = "$MailDir\nssmtp.exe"
$nssmPath = "$MailDir\nssm.exe"

function Validar-Dominio($dominio) {
    return $dominio -match "^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
}

function Solicitar-Dominio {
    do {
        $MailDomain = Read-Host "Ingrese el nombre de dominio para su servidor (ej: reprobados.com)"
        if (Validar-Dominio $MailDomain) { break }
        Write-Host "Dominio no válido. Ejemplo válido: reprobados.com" -ForegroundColor Red
    } while ($true)
    return $MailDomain
}

function Solicitar-Puertos {
    $usarDefault = Read-Host "¿Desea usar puertos por defecto? (s/n)"
    if ($usarDefault -match '^[sS]$') {
        return @{ SMTP = 25; POP3 = 110 }
    } else {
        $smtp = Read-Host "Puerto SMTP (recomendado 25)"
        $pop3 = Read-Host "Puerto POP3 (solo simulado, recomendado 110)"
        return @{ SMTP = [int]$smtp; POP3 = [int]$pop3 }
    }
}

function Preparar-Estructura {
    Write-Host "Creando estructura de carpetas..."
    New-Item -ItemType Directory -Path $InboxDir -Force | Out-Null
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Descargar-nssmtp {
    Write-Host "Descargando nssmtp..."
    try {
        Invoke-WebRequest -Uri "https://github.com/andysan/nssmtp/releases/download/v2.0/nssmtp.exe" -OutFile $nssmtpPath
    } catch {
        Write-Host "Error al descargar nssmtp: $_" -ForegroundColor Red
        exit
    }
}

function Descargar-NSSM {
    Write-Host "Descargando NSSM..."
    $nssmZip = "$MailDir\nssm.zip"
    $nssmDir = "$MailDir\nssm"
    try {
        Invoke-WebRequest -Uri "https://nssm.cc/release/nssm-2.24.zip" -OutFile $nssmZip
        Expand-Archive -Path $nssmZip -DestinationPath $nssmDir -Force
        Copy-Item "$nssmDir\nssm-2.24\win64\nssm.exe" -Destination $nssmPath -Force
        Remove-Item $nssmZip
    } catch {
        Write-Host "Error al descargar o extraer NSSM: $_" -ForegroundColor Red
        exit
    }
}

function Configurar-nssmtp {
    Write-Host "Configurando nssmtp..."
    @"
listen=0.0.0.0
port=$($puertos.SMTP)
logfile=$LogDir\smtp.log
inboxdir=$InboxDir
"@ | Set-Content -Path "$ConfigDir\nssmtp.ini"
}

function Crear-Servicio-SMTP {
    $svcName = "SMTP_MailService"
    if (-not (Test-Path $nssmPath)) {
        Write-Host "NSSM no encontrado. Abortando registro de servicio." -ForegroundColor Red
        exit
    }
    if (-not (Test-Path $nssmtpPath)) {
        Write-Host "nssmtp.exe no encontrado. Verifica la descarga previa." -ForegroundColor Red
        exit
    }
    Write-Host "Registrando servicio '$svcName' con NSSM..."
    & $nssmPath install $svcName $nssmtpPath "-config $ConfigDir\nssmtp.ini"
    Start-Service $svcName
    Set-Service $svcName -StartupType Automatic
}

function Configurar-Firewall($puertos) {
    Write-Host "Configurando reglas de firewall..."
    foreach ($p in $puertos.Values) {
        New-NetFirewallRule -DisplayName "Mail Port $p" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $p
    }
}

function Gestionar-Usuarios {
    do {
        Write-Host ""
        Write-Host "1) Crear usuario"
        Write-Host "2) Eliminar usuario"
        Write-Host "3) Leer correos (POP3 simulado)"
        Write-Host "4) Salir"
        $opcion = Read-Host "Seleccione una opción"
        switch ($opcion) {
            '1' {
                $user = Read-Host "Nombre de usuario"
                $plain = Read-Host "Contraseña"
                $pass = ConvertTo-SecureString $plain -AsPlainText -Force
                if (-not (Get-LocalUser -Name $user -ErrorAction SilentlyContinue)) {
                    try {
                        New-LocalUser -Name $user -Password $pass -FullName $user -PasswordNeverExpires:$true
                        Add-LocalGroupMember -Group "Users" -Member $user
                        Write-Host "Usuario $user creado correctamente." -ForegroundColor Green
                    } catch {
                        Write-Host "Error al crear usuario: $_" -ForegroundColor Red
                    }
                } else {
                    Write-Host "El usuario ya existe." -ForegroundColor Yellow
                }
            }
            '2' {
                $user = Read-Host "Nombre de usuario a eliminar"
                Remove-LocalUser -Name $user -ErrorAction SilentlyContinue
                Write-Host "Usuario $user eliminado"
            }
            '3' {
                Leer-Buzon
            }
            '4' { break }
            default { Write-Host "Opción no válida" }
        }
    } while ($true)
}

function Leer-Buzon {
    Write-Host "`nBandeja de entrada: $InboxDir"
    $mails = Get-ChildItem $InboxDir | Sort-Object LastWriteTime -Descending
    if ($mails.Count -eq 0) {
        Write-Host "No hay correos recibidos."
        return
    }
    foreach ($mail in $mails) {
        Write-Host "`nArchivo: $($mail.Name)"
        Get-Content $mail.FullName -TotalCount 20
        Write-Host "`nPresione ENTER para continuar..."
        Read-Host | Out-Null
    }
}

function Main {
    $global:dominio = Solicitar-Dominio
    $global:puertos = Solicitar-Puertos
    Preparar-Estructura
    Descargar-nssmtp
    Descargar-NSSM
    Configurar-nssmtp
    Crear-Servicio-SMTP
    Configurar-Firewall -puertos $puertos
    Gestionar-Usuarios
    Write-Host ""
    Write-Host "Servidor SMTP activo. Los correos se almacenan en: $InboxDir"
    Write-Host "SMTP escuchando en el puerto: $($puertos.SMTP)"
    Write-Host "POP3 simulado: puede consultar correos mediante la opción 3 del menú"
}

Main
