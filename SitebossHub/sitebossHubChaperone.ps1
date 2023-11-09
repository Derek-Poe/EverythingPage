Write-Host -f Cyan "Siteboss Hub Chaperone"

$PID | Set-Content C:\Automation\AutoServerMonitor\sitebossHubChaperone--PID.txt -Force
$host.UI.RawUI.WindowTitle = "sitebossHubChaperone"

$pidwl = @(
  "sitebossPoller",
  "sitebossAPI",
  "sitebossHistoryBuilder",
  "sitebossSyslogBuilder"
)
$firstRun = $true
Write-Host "Checking for $($pidwl -join ",")"
while($true){
  if((Import-Csv C:\Automation\HelpDeskHub\chaperoneDebug.csv).SitebossHub -eq $true){
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
        "sitebossPoller"{
          Start-Process "C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" "C:\Automation\SitebossHub\$pro.ps1"
          Start-Sleep -Seconds 30
          break
        }
        "sitebossAPI"{
          Start-Process "C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" "C:\Automation\SitebossHub\$pro.ps1"
          Start-Sleep -Seconds 7
          break
        }
        "sitebossHistoryBuilder"{
          Start-Process "C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" "C:\Automation\SitebossHub\$pro.ps1"
          Start-Sleep -Seconds 3
          break
        }
        "sitebossSyslogBuilder"{
          Start-Process "C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" "C:\Automation\SitebossHub\$pro.ps1"
          Start-Sleep -Seconds 3
          break
        }
      }
    }
  }
  $firstRun = $false
  Start-Sleep -Seconds 5
}