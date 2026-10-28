$ErrorActionPreference='Stop'
Add-Type -Path "$PSScriptRoot/NativeWifi.cs"
$t=[WifiScope.NativeWifi]
if($t::Channel(2412) -ne 1 -or $t::Channel(2484) -ne 14 -or $t::Channel(5180) -ne 36 -or $t::Channel(5955) -ne 1){throw 'Channel conversion failed'}
$flags=[Reflection.BindingFlags]'NonPublic'
$bss=$t.GetNestedType('Bss',$flags)
if([Runtime.InteropServices.Marshal]::SizeOf([Activator]::CreateInstance($bss)) -ne 360){throw 'Unexpected WLAN_BSS_ENTRY layout'}
if([Runtime.InteropServices.Marshal]::OffsetOf($bss,'rssi').ToInt32() -ne 56){throw 'Unexpected RSSI offset'}
if([Runtime.InteropServices.Marshal]::OffsetOf($bss,'ieOffset').ToInt32() -ne 352){throw 'Unexpected IE offset'}
Write-Host 'PASS: WLAN memory layout and frequency/channel mapping'
$scan=$t::Scan()
[pscustomobject]@{count=$scan.networks.Count;fresh=$scan.fresh;error=$scan.error;adapters=$scan.adapters;bands=@($scan.networks | Group-Object band | Select-Object Name,Count)} | ConvertTo-Json -Depth 8
