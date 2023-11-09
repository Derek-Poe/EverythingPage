Write-Host -f Cyan "Everything Chaperone"

Stop-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\everythingChaperone--PID.txt") -ErrorAction SilentlyContinue
$PID | Set-Content C:\Automation\AutoServerMonitor\everythingChaperone--PID.txt -Force
$host.UI.RawUI.WindowTitle = "everythingChaperone"

$authUsers = @("derek.poe.sa","james.roberts.sa","diandra.burk.sa","kenny.grevemberg.sa","mathew.morris.sa","barron.williams.sa","robert.hood.sa","zelda.rogers.sa","zakk.rogerson.sa","john.millender.sa","quincy.courtney.sa","isidro.holguin.sa","heath.jewett.sa")
if($env:USERNAME -notin $authUsers){
  Write-Host -f Magenta "`n`n`n`n`nCurrent User has Insufficient Permissions`n`n"
  Read-Host "Press Enter to Exit"
  exit
}

forEach($pidFile in (ls C:\Automation\AutoServerMonitor | ? {$_.Name -like "*--PID.txt" -and $_.Name -notlike "everythingChaperone*"}).FullName){
  ps -Id (cat $pidFile) -ErrorAction SilentlyContinue | kill -Force
  ps -Id 7777777 -ErrorAction SilentlyContinue | kill -Force
  "7777777" | Set-Content $pidFile -Force
}

$pidwl = @(
  "resourceDataBuilder",
  "maintAPI",
  "sitebossHubChaperone",
  "IPUAPIChaperone_2",
  "webSessionAPI",
  "adAPI",
  "solarwindsAPI",
  "everythingAPI",
  "everythingAlertMonitor",
  "autoRDPSessionConversion",
  "apiHangCheck",
  "tabletLogonTracker"
)
$timeCounter = 0
$everythingAPIReset = 60
$firstRun = $true
Write-Host "Checking for $($pidwl -join ",")"
while($true){
  if((Import-Csv C:\Automation\HelpDeskHub\chaperoneDebug.csv).Everything -eq $true){
    continue
  }
  forEach($pro in $pidwl){
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
    if($proCheck -eq $null){
      switch($pro){
        "sitebossHubChaperone" {
          Start-Process "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" "C:\Automation\SitebossHub\$pro.ps1"
          Start-Sleep -Seconds 3
          break
        }
        "IPUAPIChaperone_2" {
          Start-Process "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" "C:\Automation\IPU\$pro.ps1"
          Start-Sleep -Seconds 3
          break
        }
        "resourceDataBuilder" {
          Start-Process "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" "C:\Automation\AutoServerMonitor\$pro.ps1"
          Start-Sleep -Seconds 3
          break
        }
        "webSessionAPI" {
          Start-Process "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" "C:\Automation\WebSessionAPI\$pro.ps1"
          Start-Sleep -Seconds 3
          break
        }
        default {
          Start-Process "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" "C:\Automation\HelpDeskHub\$pro.ps1"
          Start-Sleep -Seconds 3
        }
      }
    }
  }
  if($timeCounter -ge ((60 * $everythingAPIReset) / 5)){
    Start-Process "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" "C:\Automation\HelpDeskHub\everythingAPI.ps1"
    $timeCounter = 0
  }
  $timeCounter++
  $firstRun = $false
  Start-Sleep -Seconds 5
}