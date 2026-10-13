param(
  [int]$Filter   = 2,
  [string]$Devices = '10',
  [int]$Seconds  = 15,
  [string]$OutFile = "$env:TEMP\dacal_capture.pcap"
)
$ErrorActionPreference = 'Stop'
$usbpcap = 'C:\Program Files\USBPcap\USBPcapCMD.exe'
$devStr  = ($Devices -replace '\s','')
$args = @('-d', ('\\.\USBPcap' + $Filter), '--devices', $devStr, '--inject-descriptors', '-o', $OutFile)

$log = $OutFile + '.runlog.txt'
"START $(Get-Date -Format o)"            | Set-Content $log
"CMD  : $usbpcap $($args -join ' ')"     | Add-Content $log

$p = Start-Process -FilePath $usbpcap -ArgumentList $args -PassThru -WindowStyle Hidden `
      -RedirectStandardOutput ($OutFile + '.stdout.txt') -RedirectStandardError ($OutFile + '.stderr.txt')
Start-Sleep -Seconds $Seconds
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force }
$p.WaitForExit()

$size = if (Test-Path $OutFile) { (Get-Item $OutFile).Length } else { 0 }
"DONE  $(Get-Date -Format o) size=$size" | Add-Content $log
