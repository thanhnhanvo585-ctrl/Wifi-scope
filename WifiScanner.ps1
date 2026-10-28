function ConvertFrom-WlanNetworks {
    param([string]$Text)
    $items = [Collections.Generic.List[object]]::new()
    $ssid = ''; $auth = ''; $encryption = ''; $interface = ''; $current = $null
    foreach ($line in ($Text -split "`r?`n")) {
        if ($line -match '^\s*Interface name\s*:\s*(.*)$') { $interface = $matches[1].Trim() }
        elseif ($line -match '^\s*SSID\s+\d+\s*:\s*(.*)$') { $ssid = $matches[1].Trim(); $current = $null; $auth = ''; $encryption = '' }
        elseif ($line -match '^\s*Authentication\s*:\s*(.*)$') { $auth = $matches[1].Trim() }
        elseif ($line -match '^\s*Encryption\s*:\s*(.*)$') { $encryption = $matches[1].Trim() }
        elseif ($line -match '^\s*BSSID\s+\d+\s*:\s*([0-9a-f:]{17})') {
            $current = [pscustomobject]@{ssid=$ssid; bssid=$matches[1]; signal=$null; dbm=$null; channel=$null; band='Unknown'; radio=''; security=$auth; encryption=$encryption; interface=$interface}
            $items.Add($current)
        } elseif ($null -ne $current) {
            if ($line -match '^\s*Signal\s*:\s*(\d+)%') { $current.signal = [int]$matches[1]; $current.dbm = [math]::Round(($current.signal / 2) - 100) }
            elseif ($line -match '^\s*Radio type\s*:\s*(.*)$') { $current.radio = $matches[1].Trim() }
            elseif ($line -match '^\s*Band\s*:\s*(.*)$') { $current.band = $matches[1].Trim() }
            elseif ($line -match '^\s*Channel\s*:\s*(\d+)') { $current.channel = [int]$matches[1] }
        }
    }
    foreach ($item in $items) {
        if ($item.band -eq 'Unknown' -and $null -ne $item.channel -and $item.radio -notmatch 'ax|be') {
            if ($item.channel -le 14) { $item.band = '2.4 GHz' } else { $item.band = '5 GHz' }
        }
    }
    return $items.ToArray()
}
function Get-WifiScan {
    $raw = (& "$env:SystemRoot/System32/netsh.exe" wlan show networks mode=bssid 2>&1 | Out-String)
    $code = $LASTEXITCODE
    $errorMessage = $null
    if ($raw -match 'location permission|location services|requires elevation') {
        $errorMessage = 'Windows đang chặn quyền đọc Wi-Fi. Mở Settings > Privacy & security > Location, bật Location services và cho phép ứng dụng desktop truy cập vị trí. Nếu vẫn bị chặn, thử chạy Start.cmd bằng quyền Administrator.'
    } elseif ($code -ne 0) { $errorMessage = 'Không đọc được Wi-Fi. Kiểm tra adapter và dịch vụ WLAN AutoConfig; xem chẩn đoán bên dưới.' }
    elseif ($raw -match 'no wireless interface') { $errorMessage = 'Không tìm thấy adapter Wi-Fi trên máy.' }
    $networks = @(ConvertFrom-WlanNetworks $raw)
    if (!$errorMessage -and !$networks.Count -and $raw -notmatch 'SSID|0 networks') { $errorMessage = 'Không nhận diện được kết quả netsh. Bộ đọc hiện hỗ trợ đầu ra Windows tiếng Anh; xem chẩn đoán bên dưới.' }
    return @{networks=$networks; error=$errorMessage; scannedAt=[DateTime]::UtcNow.ToString('o'); diagnostic=$(if ($errorMessage) {$raw} else {''}); source='windows-netsh'}
}
