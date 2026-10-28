function Get-NetworkDiagnostics {
    param([string]$Query, [string]$Root)
    try {
        $argsMap = @{}
        $parts = $Query -split '\?',2
        if ($parts.Count -gt 1) { foreach ($pair in ($parts[1] -split '&')) { $kv=$pair -split '=',2; if($kv.Count -eq 2){$argsMap[$kv[0]]=[uri]::UnescapeDataString($kv[1])} } }
        $address = $argsMap['host']
        $ip = $null
        if ($address -notmatch '^\d{1,3}(\.\d{1,3}){3}$' -or ![Net.IPAddress]::TryParse($address,[ref]$ip)) { throw 'Enter a valid IPv4 address.' }
        $port = 5201
        if ($argsMap.ContainsKey('port')) { $port=[int]$argsMap['port'] }
        if ($port -lt 1 -or $port -gt 65535) { throw 'Invalid port.' }
        $kind = $argsMap['kind']
        if ($kind -notin @('ping','upload','download','udp')) { throw 'Unsupported test.' }
        if ($kind -eq 'ping') {
            $ping = [Net.NetworkInformation.Ping]::new()
            $samples = @()
            try { for($i=0;$i -lt 5;$i++){try{$r=$ping.Send($ip,1500);$samples+=@{status=$r.Status.ToString();ms=$(if($r.Status -eq 'Success'){$r.RoundtripTime}else{$null})}}catch{$samples+=@{status='Error';ms=$null}}} } finally { $ping.Dispose() }
            $ok = @($samples | Where-Object {$_.status -eq 'Success'})
            return @{target=$address;kind='ICMP ping';at=[DateTime]::UtcNow.ToString('o');samples=$samples;lossPercent=(5-$ok.Count)*20;averageMs=$(if($ok.Count){($ok | ForEach-Object {$_.ms} | Measure-Object -Average).Average}else{$null});adapters=@([WifiScope.NativeWifi]::Connections());note='ICMP round-trip latency, not Wi-Fi throughput. Adapter transmit/receive rates are PHY link rates, not measured throughput.'}
        }
        $exe = Join-Path $Root 'tools/iperf3.exe'
        if (!(Test-Path -LiteralPath $exe)) { throw 'iPerf3 is not installed. Place iperf3.exe and its required DLLs in the tools folder, and start an iPerf3 server on the target machine (iperf3 -s). No speed value was generated.' }
        $info = [Diagnostics.ProcessStartInfo]::new()
        $info.FileName = $exe
        $info.Arguments = "-c $address -p $port -t 10 -J"
        if ($kind -eq 'download') { $info.Arguments += ' -R' }
        if ($kind -eq 'udp') { $info.Arguments += ' -u -b 5M' }
        $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
        $process = [Diagnostics.Process]::Start($info)
        try {
            $outTask=$process.StandardOutput.ReadToEndAsync();$errTask=$process.StandardError.ReadToEndAsync()
            if (!$process.WaitForExit(25000)) { $process.Kill();throw 'iPerf3 timeout. Check the target and firewall.' }
            $output=$outTask.Result;$stderr=$errTask.Result
            if ($process.ExitCode -ne 0) { throw "iPerf3 failed: $stderr $output" }
            return @{target=$address;kind=$kind;at=[DateTime]::UtcNow.ToString('o');result=($output | ConvertFrom-Json)}
        } finally { $process.Dispose() }
    } catch { return @{error=$_.Exception.Message} }
}
