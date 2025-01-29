# Configure Server Features Installation Script
# configure-server.ps1

# Install Windows Features
Install-WindowsFeature -Name Web-Server -IncludeManagementTools
Install-WindowsFeature -Name DHCP -IncludeManagementTools
Install-WindowsFeature -Name Windows-Server-Backup -IncludeManagementTools

# Configure IIS
Import-Module WebAdministration
New-WebSite -Name "Default" -Port 80 -PhysicalPath "$env:SystemDrive\inetpub\wwwroot" -Force

# Configure DHCP
$DHCPScope = @{
    Name = "DefaultScope"
    StartRange = "10.0.0.100"
    EndRange = "10.0.0.200"
    SubnetMask = "255.255.255.0"
    LeaseDuration = "8.00:00:00"
}

Add-DhcpServerv4Scope @DHCPScope
Set-DhcpServerv4OptionValue -DnsServer 8.8.8.8 -Router 10.0.0.1

# Authorize DHCP server in Active Directory
Add-DhcpServerInDC

# Configure Windows Server Backup
$Policy = New-WBPolicy
$Volume = Get-WBVolume -AllVolumes
Add-WBVolume -Policy $Policy -Volume $Volume
Add-WBSystemState -Policy $Policy
$Target = New-WBBackupTarget -Volume (Get-WBVolume -VolumePath "D:")
Add-WBBackupTarget -Policy $Policy -Target $Target
Set-WBSchedule -Policy $Policy -Schedule "12:00 AM"

# Enable features in Windows Firewall
New-NetFirewallRule -DisplayName "IIS" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow
New-NetFirewallRule -DisplayName "DHCP" -Direction Inbound -Protocol UDP -LocalPort 67,68 -Action Allow

# Write completion log
$LogFile = "C:\Windows\Temp\server-setup.log"
$TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path $LogFile -Value "Server configuration completed at $TimeStamp"