Write-Host -f Cyan "IPU API Chaperone"

Stop-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\IPUAPIChaperone_2--PID.txt") -ErrorAction SilentlyContinue
$PID | Set-Content C:\Automation\AutoServerMonitor\IPUAPIChaperone_2--PID.txt -Force
$host.UI.RawUI.WindowTitle = "IPUAPIChaperone_2"

$pidwl = @(
  "IPURR_DataBuilder",
  "IPUAPI",
  "IPUOTADataBuilder_multiInstance",
  "IPUOTAResultsAPI",
  "IPUOTATracker",
  "IPUOTAAuto",
  "IPUOTAServerDataAutoReload"
)
Write-Host "Checking for $($pidwl -join ",")"
$firstRun = $true
while($true){
  if((Import-Csv C:\Automation\HelpDeskHub\chaperoneDebug.csv).IPU -eq $true){
    continue
  }
  forEach($pro in $pidwl){
    $proCheck = $null
    $proCheck = (Get-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\$pro--PID.txt") -ErrorAction SilentlyContinue)
    if($proCheck -ne $null){
      if($firstRun){
        Write-Host -f Magenta "$pro($($proCheck.Id)) Found"
        $proCheck = $null
      }
    }
    else{
      Write-Host -f Yellow "$pro($((Get-Content "C:\Automation\AutoServerMonitor\$pro--PID.txt"))) Not Found $((Get-Date).ToString(`"MM/dd/yyyy hh:mm:ss tt`"))"
    }
    if($pro -eq "IPUOTADataBuilder_multiInstance"){
      $tm = (New-TimeSpan ([DateTime]::Parse((Get-Content C:\Automation\IPU\instrDataDate.txt))) (Get-Date)).TotalMinutes
      if(($tm -ge 2) -and ((Get-Content C:\Automation\IPU\repairingOTADataBuilder.txt) -eq $false)){
        Stop-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\$pro--PID.txt") -ErrorAction SilentlyContinue
        $true | Set-Content C:\Automation\IPU\repairingOTADataBuilder.txt
      }
      elseIf($tm -lt 2){
        $false | Set-Content C:\Automation\IPU\repairingOTADataBuilder.txt
      }
    }
    if($pro -eq "IPUAPI"){
      $webReq = $null
      $webReq = Invoke-WebRequest https://net-admin-tc215.is-u.jrtc.army.mil:9748/chaperoneCheckin -TimeoutSec 20
      if($webReq -eq $null){
        Stop-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\$pro--PID.txt") -ErrorAction SilentlyContinue
      }
    }
    if($proCheck -eq $null){
      if($pro -ne "WebSessionAPI"){
        Start-Process "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" "C:\Automation\IPU\$pro.ps1"
      }
      else{       
        Start-Process "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" "C:\Automation\WebSessionAPI\$pro.ps1"
      }
      if($pro -ne "IPUOTADataBuilder_multiInstance"){
        Start-Sleep -Seconds 10
      }
      else{
        Start-Sleep -Seconds 45
      }
    }
  }
  $firstRun = $false
  Start-Sleep -Seconds 5
}