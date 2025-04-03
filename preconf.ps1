# Instala todas las características necesarias para Exchange Server 2019
Write-Host "Instalando roles y características requeridas para Exchange..." -ForegroundColor Cyan

Install-WindowsFeature `
    ADLDS, `
    AS-HTTP-Activation, `
    Desktop-Experience, `
    NET-Framework-45-Features, `
    NET-WCF-HTTP-Activation45, `
    RPC-over-HTTP-proxy, `
    RSAT-Clustering, `
    RSAT-Clustering-CmdInterface, `
    RSAT-Clustering-Mgmt, `
    RSAT-Clustering-PowerShell, `
    Web-Mgmt-Console, `
    Web-Mgmt-Service, `
    Web-Asp-Net45, `
    Web-Basic-Auth, `
    Web-Client-Auth, `
    Web-Digest-Auth, `
    Web-Dir-Browsing, `
    Web-Dyn-Compression, `
    Web-Http-Errors, `
    Web-Http-Logging, `
    Web-Http-Redirect, `
    Web-Http-Tracing, `
    Web-ISAPI-Ext, `
    Web-ISAPI-Filter, `
    Web-Lgcy-Mgmt-Console, `
    Web-Metabase, `
    Web-Net-Ext45, `
    Web-Request-Monitor, `
    Web-Server, `
    Web-Static-Content, `
    Web-Windows-Auth, `
    Web-WMI, `
    WAS-Process-Model, `
    Windows-Identity-Foundation `
    -IncludeManagementTools

Write-Host "`n✅ Todos los roles han sido instalados correctamente." -ForegroundColor Green

# Recordatorio sobre dependencias externas
Write-Host "`n📌 Aún necesitas instalar estos manualmente antes de continuar:" -ForegroundColor Yellow
Write-Host "1. Visual C++ 2013 Redistributable (https://aka.ms/vs2013redist)"
Write-Host "2. UCMA 4.0 Runtime (https://www.microsoft.com/en-us/download/details.aspx?id=34992)"
Write-Host "3. IIS URL Rewrite Module (https://www.iis.net/downloads/microsoft/url-rewrite)"

Write-Host "`nReiniciando sistema para aplicar cambios..." -ForegroundColor Cyan
Restart-Computer
