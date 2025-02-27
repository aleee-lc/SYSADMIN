DSIM /online/Add-CapabilityName:OpenSSH.Server~~~~0.0.1.0
Get-WindowsCapability -Online | Where-Objetct Name -Like 'OpenSSH*'
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic
New-NetFirewallRule -DisplayName "SSH" -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow
Get-Service sshd

