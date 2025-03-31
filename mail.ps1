# Variables globales
$CertDir = "C:\Certs\Mail"
$WwwDir = "C:\inetpub\wwwroot\squirrelmail"

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
        return @{
            SMTP = 587
            POP3 = 110
        }
    } else {
        $smtp = Read-Host "Puerto SMTP (recomendado 587)"
        $pop3 = Read-Host "Puerto POP3 (recomendado 110)"
        return @{
            SMTP = [int]$smtp
            POP3 = [int]$pop3
        }
    }
}



function Instalar-Roles {
    Write-Host "Instalando roles y características necesarios..."
    Install-WindowsFeature -Name Web-Server,Web-WebServer,Web-Common-Http,Web-Default-Doc,Web-Dir-Browsing,Web-Http-Errors,Web-Static-Content,Web-Asp-Net45 -IncludeManagementTools
}

function Instalar-Squirrelmail {
    Write-Host "Instalando SquirrelMail..."
    New-Item -Path $WwwDir -ItemType Directory -Force | Out-Null
    $zip = "$env:TEMP\squirrelmail.zip"
    Invoke-WebRequest -Uri "http://www.squirrelmail.org/countdl.php?fileurl=http%3A%2F%2Fprdownloads.sourceforge.net%2Fsquirrelmail%2Fsquirrelmail-webmail-1.4.22.zip" -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $WwwDir -Force
    Remove-Item $zip
}

function Configurar-Firewall($puertos) {
    Write-Host "Configurando reglas de firewall..."
    foreach ($p in $puertos.Values) {
        New-NetFirewallRule -DisplayName "Mail Port $p" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $p
    }
    New-NetFirewallRule -DisplayName "HTTP Webmail" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 80
}

function Reiniciar-Servicios {
    Write-Host "Reiniciando servicios IIS..."
    Restart-Service W3SVC
}

function Gestionar-Usuarios {
    do {
        Write-Host "`n1) Crear usuario"
        Write-Host "2) Eliminar usuario"
        Write-Host "3) Salir"
        $opcion = Read-Host "Seleccione una opción"
        switch ($opcion) {
            '1' {
                $user = Read-Host "Nombre de usuario"
                $plain = Read-Host "Contraseña (mínimo: 8 caracteres, mayúscula, número)"
                $pass = ConvertTo-SecureString $plain -AsPlainText -Force

                if (-not (Get-LocalUser -Name $user -ErrorAction SilentlyContinue)) {
                    try {
                        New-LocalUser -Name $user -Password $pass -FullName $user -PasswordNeverExpires:$true
                        Add-LocalGroupMember -Group "Users" -Member $user
                        Write-Host "Usuario $user creado correctamente." -ForegroundColor Green
                    } catch {
                        Write-Host "❌ Error al crear usuario: $_" -ForegroundColor Red
                    }
                } else {
                    Write-Host "⚠️ El usuario ya existe." -ForegroundColor Yellow
                }
            }

            '2' {
                $user = Read-Host "Nombre de usuario a eliminar"
                Remove-LocalUser -Name $user -ErrorAction SilentlyContinue
                Write-Host "Usuario $user eliminado"
            }
            '3' { break }
            default { Write-Host "Opción no válida" }
        }
    } while ($true)
}

function Main {
    $dominio = Solicitar-Dominio
    $puertos = Solicitar-Puertos
    Instalar-Roles
    Instalar-Squirrelmail
    Configurar-Firewall -puertos $puertos
    Reiniciar-Servicios
    Gestionar-Usuarios

    Write-Host "`nServidor de correo configurado."
    Write-Host "Dominio: mail.$dominio"
    Write-Host "SMTP: puerto $($puertos.SMTP)"
    Write-Host "POP3: puerto $($puertos.POP3)"
    Write-Host "Webmail: http://localhost/squirrelmail"

}

Main
