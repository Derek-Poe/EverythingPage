Write-Host -f Cyan "API Hang Check"

Stop-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\apiHangCheck--PID.txt") -ErrorAction SilentlyContinue
$PID | Set-Content C:\Automation\AutoServerMonitor\apiHangCheck--PID.txt -Force
$host.UI.RawUI.WindowTitle = "apiHangCheck"

while($true){
  $startTime = (Get-Date)
  $err = $null
  #$in = Invoke-WebRequest https://net-admin-tc215.is-u.jrtc.army.mil:1320/hangCheck -TimeoutSec 210 -ErrorVariable err
  $in = Invoke-WebRequest https://net-admin-tc215.is-u.jrtc.army.mil:1320/hangCheck -TimeoutSec 120 -ErrorVariable err
  $execTime = (New-TimeSpan -Start $startTime -End (Get-Date))
  if($execTime.TotalMinutes -gt 3 -or $err[0].Message -eq "Unable to connect to the remote server"){
    ps -id (cat C:\automation\AutoServerMonitor\everythingAPI--PID.txt) | kill
    "$((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: Everything API Hang Restart" | Add-Content -Force -Path c:\Automation\HelpDeskHub\apiHangCheck.log
  }
  if($execTime.TotalSeconds -lt 30){
    Start-Sleep -Milliseconds (30000 - [Math]::Round($execTime.TotalMilliseconds))
  }
}