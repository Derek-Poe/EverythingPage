Write-Host -f Cyan "IPU OTA Tracker"

Stop-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\IPUOTATracker--PID.txt") -ErrorAction SilentlyContinue
$PID | Set-Content C:\Automation\AutoServerMonitor\IPUOTATracker--PID.txt -Force
$host.UI.RawUI.WindowTitle = "IPUOTATracker"

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

while($true){
  $startTime = (Get-Date)
  Write-Host "StartTime: $($startTime.ToString(`"MM/dd/yyyy hh:mm:ss tt"))" -NoNewline
  $watchList = Import-Csv C:\Automation\IPU\OTAWatchlist.csv
  forEach($ipu in $watchList){
    $actTS = (New-TimeSpan ([DateTime]::Parse($ipu.Date)) (Get-Date)).TotalMinutes
    if(($actTS -gt 15) -or ($actTS -gt 10 -and $ipu.Type -ne "SWUP") -or ($actTS -gt 5 -and $ipu.Complete -eq $true)){
      #$webReq = Start-Job -ScriptBlock {param($ipu) Invoke-WebRequest "http://127.0.0.1:9733/nv273904bvfd/manageWatch/remove/$($ipu.ID)"} -ArgumentList $ipu
      $webReq = Invoke-WebRequest "http://127.0.0.1:9733/nv273904bvfd/manageWatch/remove/$($ipu.ID)"
    }
    else{
      if($ipu.Complete -eq $false){
        if($ipu.Type -eq "SWUP"){
          $time = ((Get-Date).ToUniversalTime()).ToString("yyyy-MM-ddhh:mm:ss")
          $time = $time.Insert(10,"T")
          $time = $time.Insert($time.Length,".000Z")
          $check = Invoke-WebRequest -UseBasicParsing -Uri "http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation" -Method "POST" -Headers @{"Pragma"="no-cache"; "Sec-Fetch-Site"="same-origin"; "Origin"="http://10.224.218.12"; "Accept-Encoding"="gzip, deflate, br"; "Accept-Language"="en-US,en;q=0.9"; "User-Agent"="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36"; "Sec-Fetch-Mode"="cors"; "Accept"="application/json, text/plain, */*"; "Cache-Control"="no-cache"; "Referer"="http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation";} -ContentType "application/json" -Body "{`"queryName`":`"QueryInstrumentationWithLike`",`"header`":{`"id`":{`"uuid`":`"$((New-Guid).Guid)`",`"class`":`"ctia.data_model.HeaderId`"},`"sentTime`":`"$time`",`"actualTime`":`"$time`",`"serviceName`":`"SoaInstrumentationService`",`"userName`":`"$("TCE")`",`"host`":`"s-lctia4-102.ctcis.local`",`"class`":`"ctia.data_model.HeaderData`"},`"criteria`":[{`"name`":`"LIKE_QUERY`",`"stringValue`":`"%$($ipu.IPU)%`",`"class`":`"ctia.data_model.Criterion`"}],`"maxResults`":2,`"projections`":[`"ipuSoftwareVersion`"],`"startOffset`":0,`"isRecovered`":false,`"class`":`"ctia.data_model.NamedQueryRequest`"}"
          $check = ($check.Content | ConvertFrom-Json).payload.instrumentationList.ipuSoftwareVersion
          if($check -like "1.*"){
            if($ipu.Goal -eq $check){
              #$webReq = Start-Job -ScriptBlock {param($ipu) Invoke-WebRequest "http://127.0.0.1:9733/nv273904bvfd/statusUpdate/complete/$($ipu.ID)"} -ArgumentList $ipu
              $webReq = Invoke-WebRequest "http://127.0.0.1:9733/nv273904bvfd/statusUpdate/complete/$($ipu.ID)"
            }
          }
          else{
            #Not Found
          }
        }
        elseIf($ipu.Type -eq "T -- D"){
          $time = ((Get-Date).ToUniversalTime()).ToString("yyyy-MM-ddhh:mm:ss")
          $time = $time.Insert(10,"T")
          $time = $time.Insert($time.Length,".000Z")
          $check = Invoke-WebRequest -UseBasicParsing -Uri "http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation" -Method "POST" -Headers @{"Pragma"="no-cache"; "Sec-Fetch-Site"="same-origin"; "Origin"="http://10.224.218.12"; "Accept-Encoding"="gzip, deflate, br"; "Accept-Language"="en-US,en;q=0.9"; "User-Agent"="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36"; "Sec-Fetch-Mode"="cors"; "Accept"="application/json, text/plain, */*"; "Cache-Control"="no-cache"; "Referer"="http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation";} -ContentType "application/json" -Body "{`"queryName`":`"QueryInstrumentationWithLike`",`"header`":{`"id`":{`"uuid`":`"$((New-Guid).Guid)`",`"class`":`"ctia.data_model.HeaderId`"},`"sentTime`":`"$time`",`"actualTime`":`"$time`",`"serviceName`":`"SoaInstrumentationService`",`"userName`":`"$("TCE")`",`"host`":`"s-lctia4-102.ctcis.local`",`"class`":`"ctia.data_model.HeaderData`"},`"criteria`":[{`"name`":`"LIKE_QUERY`",`"stringValue`":`"%$($ipu.IPU)%`",`"class`":`"ctia.data_model.Criterion`"}],`"maxResults`":2,`"projections`":[`"actualDistanceReportingRate`",`"actualTimeReportingRate`"],`"startOffset`":0,`"isRecovered`":false,`"class`":`"ctia.data_model.NamedQueryRequest`"}"
          $check = ($check.Content | ConvertFrom-Json).payload.instrumentationList
          $check =  "$(([String]$check.actualTimeReportingRate).Remove((([String]$check.actualTimeReportingRate)).Length - 2)) -- $(([String]$check.actualDistanceReportingRate).Remove((([String]$check.actualDistanceReportingRate)).Length - 2))"
          if($check -match "[0-9]"){
            if($ipu.Goal -eq $check){
              #$webReq = Start-Job -ScriptBlock {param($ipu) Invoke-WebRequest "http://127.0.0.1:9733/nv273904bvfd/statusUpdate/complete/$($ipu.ID)"} -ArgumentList $ipu
              $webReq = Invoke-WebRequest "http://127.0.0.1:9733/nv273904bvfd/statusUpdate/complete/$($ipu.ID)"
            }
          }
          else{
            #Not Found
          }
        }
      }
    }
  }

  #Check for Stale and Rogue

  $execTime = (New-TimeSpan -Start $startTime -End (Get-Date))
  Write-Host " -- WatchList Count: $(checkLength $watchList) -- ExecTime: $($execTime.ToString())"
  if($execTime.TotalSeconds -lt 5){
    Start-Sleep -Milliseconds (5000 - [Math]::Round($execTime.TotalMilliseconds))
  }
}

