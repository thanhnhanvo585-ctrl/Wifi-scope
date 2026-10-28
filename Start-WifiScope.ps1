param([int]$Port = 8765, [switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
Add-Type -Path "$PSScriptRoot/NativeWifi.cs"
. "$PSScriptRoot/Diagnostics.ps1"
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
try {
    $listener.Start()
} catch [System.Net.Sockets.SocketException] {
    if ($_.Exception.SocketErrorCode -ne [System.Net.Sockets.SocketError]::AddressAlreadyInUse) { throw }
    Write-Host "Port $Port is busy. Selecting a free local port..."
    $listener.Stop()
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
}
$Port = $listener.LocalEndpoint.Port
Write-Host "WiFi Scope: http://127.0.0.1:$Port  (Ctrl+C to stop)"
if (!$NoBrowser) { Start-Process "http://127.0.0.1:$Port" }
try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        $client.ReceiveTimeout = 5000
        $client.SendTimeout = 5000
        try {
            $stream = $client.GetStream()
            $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::ASCII, $false, 1024, $true)
            $request = $reader.ReadLine()
            $headers = @{}
            while ($line = $reader.ReadLine()) {
                if ($line -match '^([^:]+):\s*(.*)$') { $headers[$matches[1].ToLower()] = $matches[2] }
            }
            $status = '200 OK'
            $type = 'application/json; charset=utf-8'
            $path = ($request -split ' ')[1]
            $route = ($path -split '\?')[0]
            if ($headers['host'] -notin @("127.0.0.1:$Port", "localhost:$Port")) {
                $status = '403 Forbidden'; $body = '{"error":"Invalid host"}'
            } elseif ($request -notmatch '^GET ') {
                $status = '405 Method Not Allowed'; $body = '{}'
            } elseif ($route.StartsWith('/api/') -and ($headers['x-wifiscope'] -ne '1' -or ($headers.ContainsKey('sec-fetch-site') -and $headers['sec-fetch-site'] -notin @('same-origin','none')))) {
                $status = '403 Forbidden'; $body = '{"error":"Open the local application to access this API."}'
            } elseif ($route -eq '/api/scan') {
                $body = [WifiScope.NativeWifi]::Scan() | ConvertTo-Json -Depth 8 -Compress
            } elseif ($route -eq '/api/connection') {
                $body = ConvertTo-Json -InputObject @([WifiScope.NativeWifi]::Connections()) -Depth 6 -Compress
            } elseif ($route -eq '/api/diagnostics') {
                $body = Get-NetworkDiagnostics -Query $path -Root $PSScriptRoot | ConvertTo-Json -Depth 20 -Compress
            } elseif ($route -in @('/', '/app.js', '/core.js', '/style.css', '/vendors.json')) {
                $file = if ($route -eq '/') {'index.html'} else {$route.Substring(1)}
                $type = if ($route.EndsWith('.js')) {'application/javascript; charset=utf-8'} elseif ($route.EndsWith('.css')) {'text/css; charset=utf-8'} elseif ($route.EndsWith('.json')) {'application/json; charset=utf-8'} else {'text/html; charset=utf-8'}
                $body = [IO.File]::ReadAllText((Join-Path "$PSScriptRoot/web" $file))
            } else { $status = '404 Not Found'; $body = '{}' }
            $bytes = [Text.Encoding]::UTF8.GetBytes($body)
            $head = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 $status`r`nContent-Type: $type`r`nContent-Length: $($bytes.Length)`r`nCache-Control: no-store`r`nX-Content-Type-Options: nosniff`r`nContent-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data: blob:; connect-src 'self'; frame-ancestors 'none'; object-src 'none'; base-uri 'none'`r`nConnection: close`r`n`r`n")
            $stream.Write($head, 0, $head.Length)
            $stream.Write($bytes, 0, $bytes.Length)
        } catch { Write-Warning $_.Exception.Message } finally { $client.Dispose() }
    }
} finally { $listener.Stop() }
