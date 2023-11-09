Write-Host -f Cyan "IPU OTA Server Data AutoReload"

Stop-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\IPUOTAServerDataAutoReload--PID.txt") -ErrorAction SilentlyContinue
$PID | Set-Content C:\Automation\AutoServerMonitor\IPUOTAServerDataAutoReload--PID.txt -Force
$host.UI.RawUI.WindowTitle = "IPUOTAServerDataAutoReload"

$enc = [System.Text.Encoding]::ASCII
$busyCounter = 0
while($true){
  $startTime = (Get-Date)
  $in = Invoke-WebRequest http://127.0.0.1:1482/jh23bk54jhb23/s
  if($enc.GetString($in.Content) -like "*busy*"){
    $busyCounter++
  }
  else{
    $busyCounter = 0
  }
  Write-Host "$((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")) :: Request Sent -- Busy Counter: $busyCounter"
  if($busyCounter -ge 3){
    ps -Id (Get-Content C:\Automation\AutoServerMonitor\IPUOTADataBuilder_multiInstance--PID.txt) | kill
  }
  $execTime = (New-TimeSpan -Start $startTime -End (Get-Date))
  if($execTime.TotalSeconds -lt 60){
    Start-Sleep -Milliseconds (60000 - [Math]::Round($execTime.TotalMilliseconds))
  }
}