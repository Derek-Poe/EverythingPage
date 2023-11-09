Write-Host -f Cyan "IPU OTA Auto"

Stop-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\IPUOTAAuto--PID.txt") -ErrorAction SilentlyContinue
$PID | Set-Content C:\Automation\AutoServerMonitor\IPUOTAAuto--PID.txt -Force
$host.UI.RawUI.WindowTitle = "IPUOTAAuto"

function checkLength($in){
  if($in -is [Array]){
    return $in.Length
  }
  elseIf($in -isnot [Array] -and $in -ne $null){
    return 1
  }
  else{
    return 0
  }
}

$webSess = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$aC = New-Object System.Net.Cookie; $ac.Name = "ipuSess"; $aC.Value = "2O2KHyBfBrXl1vUnF31yqeQY"; $aC.Domain = "net-admin-tc215.is-u.jrtc.army.mil"
$webSess.Cookies.Add($aC)

while($true){
  $startTime = (Get-Date)
  Write-Host "StartTime: $($startTime.ToString(`"MM/dd/yyyy hh:mm:ss tt"))" -NoNewline
  $instrData = $null
  $queue = @()
  Import-Csv C:\Automation\IPU\temp\OTABotUpdateQueue.csv | % {$queue += $_}
  if((Import-Csv C:\Automation\IPU\autoOTAConf.csv)."T-D" -ne $false){
    if((New-TimeSpan ([DateTime]::Parse((Get-Content C:\Automation\IPU\lastAutoTimeDistance.txt))) (Get-Date)).TotalMinutes -ge 10){
      $watchlist = Import-Csv C:\Automation\IPU\OTAWatchlist.csv
      $instrData = Import-Csv C:\Automation\IPU\instrData.csv | ? {!($_.actualDistanceReportingRate -eq 10 -and $_.actualTimeReportingRate -eq 300) -and !($_.actualDistanceReportingRate -eq 25 -and $_.actualTimeReportingRate -eq 600)} | ? {$_.serialNumber -notin $watchlist.IPU}
      if($instrData -ne $null){
        $jsonString = "{`"rate`":`"300`",`"IPUs`":["
        forEach($sn in $instrData.serialNumber){
          $jsonString += "`"$sn`","
          "OTA_Auto $((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: Time/Distance -- 300/10 -- $sn" | Add-Content -Force -Path C:\Automation\IPU\IPUOTAAutoLog.txt
        }
        $jsonString = $jsonString.Remove($jsonString.Length - 1)
        $jsonString += "]}"
        $webReq = Invoke-WebRequest "https://net-admin-tc215.is-u.jrtc.army.mil:9748/16dsfSFfgsf3/otaSend" -Method PUT -Body $jsonString -WebSession $webSess
      }
      (Get-Date) | Set-Content C:\Automation\IPU\lastAutoTimeDistance.txt -Force
    }
  }
  if((Import-Csv C:\Automation\IPU\autoOTAConf.csv).SWUP -ne $false){
    $watchlist = Import-Csv C:\Automation\IPU\OTAWatchlist.csv
    $instrData = Import-Csv C:\Automation\IPU\instrData.csv | ? {$_.ipuSoftwareVersion -eq "1.7.1.1"} | ? {$_.serialNumber -notin $watchlist.IPU -and $_.serialNumber -notin $queue.IPU}
    if($instrData -ne $null){
      forEach($sn in $instrData.serialNumber){
        $queue += New-Object PSCustomObject -Property ([ordered]@{IPU=$sn;Target="1.7.1.2";StartTime=(((Get-Date).AddMinutes(3)).ToString("MM/dd/yyyy hh:mm:ss tt"))})
      }
    }
  }
  $sendCount = 0
  $removalList = @()
  $jsonString = "{`"rate`":`"SWUP`",`"IPUs`":["
  forEach($entry in $queue){
    if((Get-Date) -ge [DateTime]::Parse($entry.StartTime)){
      $jsonString += "`"$($entry.IPU)`","
      $removalList += $entry.IPU
      "OTA_Auto $((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: Software Update -- 1.7.1.2 -- $sn" | Add-Content -Force -Path C:\Automation\IPU\IPUOTAAutoLog.txt
      $sendCount++
    }
  }
  $jsonString = $jsonString.Remove($jsonString.Length - 1)
  $jsonString += "]}"
  if($sendCount -gt 0){
    $webReq = Invoke-WebRequest "https://net-admin-tc215.is-u.jrtc.army.mil:9748/16dsfSFfgsf3/otaSend" -Method PUT -Body $jsonString -WebSession $webSess
  }
  $queue = $queue | ? {$_.IPU -notin $removalList}
  $queue | Export-Csv -NoTypeInformation -Force C:\Automation\IPU\temp\OTABotUpdateQueue.csv
  $execTime = (New-TimeSpan -Start $startTime -End (Get-Date))
  #Write-Host " -- WatchList Count: $(checkLength $watchList) -- ExecTime: $($execTime.ToString())"
  Write-Host " -- ExecTime: $($execTime.ToString())"
  if($execTime.TotalSeconds -lt 10){
    Start-Sleep -Milliseconds (10000 - [Math]::Round($execTime.TotalMilliseconds))
  }
}

