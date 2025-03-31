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
        $pop3 = Read-Host "Puerto POP3 (no funcional, pero requerido)"
        return @{ SMTP = [int]$smtp; POP3 = [int]$pop3 }
    }
}

function Instalar-SMTPServer {
    Write-Host "Instalando SMTP Server..."
    Install-WindowsFeature SMTP-Server, RSAT-SMTP
    Start-Service SMTPSVC
    Set-Service SMTPSVC -StartupType Automatic
    Write-Host "SMTP Server instalado y en ejecución."
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
            '3' { break }
            default { Write-Host "Opción no válida" }
        }
    } while ($true)
}

function Main {
    $dominio = Solicitar-Dominio
    $puertos = Solicitar-Puertos

    Instalar-SMTPServer
    Configurar-Firewall -puertos $puertos
    Gestionar-Usuarios

    Write-Host ""
    Write-Host "Servidor de correo básico configurado."
    Write-Host "SMTP disponible en puerto: $($puertos.SMTP)"
    Write-Host "Nota: POP3 no está disponible de forma nativa en Server Core."
    Write-Host "Puede usar un servidor POP3 externo o contenedor Docker si lo necesita."
}

Main
