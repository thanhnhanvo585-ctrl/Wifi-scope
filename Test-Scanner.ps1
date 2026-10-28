$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/WifiScanner.ps1"
$fixture = @'
Interface name : Wi-Fi
SSID 1 : Office: Main
    Authentication : WPA2-Personal
    Encryption : CCMP
    BSSID 1 : aa:bb:cc:dd:ee:01
         Signal : 80%
         Radio type : 802.11ac
         Channel : 36
    BSSID 2 : aa:bb:cc:dd:ee:02
         Signal : 50%
         Radio type : 802.11ax
         Band : 6 GHz
         Channel : 5
SSID 2 :
    Authentication : Open
    Encryption : None
    BSSID 1 : aa:bb:cc:dd:ee:03
         Signal : 0%
         Radio type : 802.11n
         Channel : 11
SSID 3 : Ambiguous
    Authentication : WPA3-Personal
    Encryption : CCMP
    BSSID 1 : aa:bb:cc:dd:ee:04
         Signal : 42%
         Radio type : 802.11ax
         Channel : 5
'@
$rows = @(ConvertFrom-WlanNetworks $fixture)
if ($rows.Count -ne 4) { throw 'Multiple BSSID parsing failed' }
if ($rows[0].ssid -ne 'Office: Main' -or $rows[0].dbm -ne -60 -or $rows[0].band -ne '5 GHz') { throw 'Signal or SSID parsing failed' }
if ($rows[1].band -ne '6 GHz' -or $rows[1].security -ne 'WPA2-Personal') { throw 'Band or security propagation failed' }
if ($rows[2].ssid -ne '' -or $rows[2].dbm -ne -100 -or $rows[2].security -ne 'Open') { throw 'Hidden SSID parsing failed' }
if ($rows[3].band -ne 'Unknown') { throw 'Ambiguous band must not be guessed' }
if (@(ConvertFrom-WlanNetworks 'There are 0 networks currently visible.').Count -ne 0) { throw 'Empty scan parsing failed' }
Write-Host 'PASS: multiple BSSID, SSID, security, signals, bands, hidden and empty networks'
