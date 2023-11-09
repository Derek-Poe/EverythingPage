Write-Host -f Cyan "IPUOTA Results Builder"

$PID | Set-Content C:\Automation\AutoServerMonitor\IPUOTA_ResultsBuilder--PID.txt -Force

While($true){
  Write-Host "$((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")): Collecting OTA Results Data..."

  $ct = (Get-Date)
  $allTasks = Import-Csv C:\Automation\IPU\otaJobs.csv
  $tasks = @()
  forEach($ipu in $allTasks){
    if((New-TimeSpan -Start ([DateTime]::Parse($ipu.Time)) -End $ct).Minutes -le 20){
      $tasks += $ipu
    }
  }
  
  $logRead = Get-Content -Tail 1000 \\fileshare01\gateway\GWGuiProc.log
  $results = @()
  forEach($ipu in ($tasks | ? {$_.Task -eq "SWUP"})){
    $result = $null
    $result = $logRead | ? {$_ -like "*Retrieve*from $($ipu.IPU)"} | Select -Last 1
    if($result -ne $null){
      $results += New-Object PSCustomObject -Property ([Ordered]@{IPU=$ipu.IPU;Result=($ipu.Task).Split(":")[4].Split("from")[0].Trim()})
    }
  }
  
  $tasks | Export-Csv C:\Automation\IPU\otaJobs.csv -Force -NoTypeInformation
  $results | Export-Csv C:\Automation\IPU\otaResults.csv -Force -NoTypeInformation

  Write-Host "$((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")): Data Collection Completed"
  Write-Host "-------------------------------------------------"
  Start-Sleep -Seconds 5
}