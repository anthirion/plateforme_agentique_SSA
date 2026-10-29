<#
Prépare la VM Windows pour Active Directory : installe AD DS et ses outils,
active RDP avec authentification NLA et configure le pare-feu Windows.
L'accès RDP est limité aux relais IAP par les pare-feu GCP et Windows.
La création de la forêt et les mots de passe restent à configurer manuellement.
#>

$ErrorActionPreference = 'Stop'

# Image Windows Server Desktop Experience ; promotion volontairement séparée.
if (-not (Get-WindowsFeature AD-Domain-Services).Installed) {
    Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
}

Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0
Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name UserAuthentication -Value 1

# RDP uniquement via IAP ; désactiver les anciennes règles d'accès direct.
Get-NetFirewallRule -Name 'RemoteDesktop*' | Disable-NetFirewallRule
Get-NetFirewallRule -Name 'Poc-Direct-RDP' -ErrorAction SilentlyContinue | Disable-NetFirewallRule
if (-not (Get-NetFirewallRule -Name 'Poc-IAP-RDP' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name 'Poc-IAP-RDP' -DisplayName 'PoC RDP via IAP' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 3389 -RemoteAddress '35.235.240.0/20'
} else {
    Set-NetFirewallRule -Name 'Poc-IAP-RDP' -Enabled True -RemoteAddress '35.235.240.0/20'
}
