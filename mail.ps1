$MailDir = "C:\MailServer"
$InboxDir = "$MailDir\Inbox"
$ConfigDir = "$MailDir\Config"
$LogDir = "$MailDir\Logs"

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

function Instalar-SMTP {
    Write-Host "Descargando nssmtp (servidor SMTP)..."
    $nssmtpPath = "$MailDir\nssmtp.exe"
    # Sobrescribir la política de certificados SSL para evitar problemas con certificados no confiables
    add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    # Sobrescribir la política de certificados SSL para evitar problemas con certificados no confiables
    add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    Invoke-WebRequest -Uri "https://github.com/andysan/nssmtp/releases/download/v2.0/nssmtp.exe" -OutFile $nssmtpPath

    Write-Host "Configurando nssmtp..."
    @"
listen=0.0.0.0
port=$($puertos.SMTP)
logfile=$LogDir\smtp.log
inboxdir=$InboxDir
"@ | Set-Content -Path "$ConfigDir\nssmtp.ini"

    Write-Host "Iniciando nssmtp..."
    Start-Process -FilePath $nssmtpPath -ArgumentList "-config $ConfigDir\nssmtp.ini" -NoNewWindow
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
    Instalar-SMTP
    Configurar-Firewall -puertos $puertos
    Gestionar-Usuarios

    Write-Host ""
    Write-Host "Servidor SMTP activo. Correos se almacenan en: $InboxDir"
    Write-Host "SMTP escuchando en puerto: $($puertos.SMTP)"
    Write-Host "POP3 no real: puede consultar correos mediante opción 3 del menú"
}

Main
