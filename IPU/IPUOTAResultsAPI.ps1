Write-Host -f Cyan "IPU OTA Results API"

Stop-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\IPUOTAResultsAPI--PID.txt") -ErrorAction SilentlyContinue
$PID | Set-Content C:\Automation\AutoServerMonitor\IPUOTAResultsAPI--PID.txt -Force
$host.UI.RawUI.WindowTitle = "IPUOTAResultsAPI"

$listener = New-Object System.Net.HttpListener
$apiPort = 9733
$listener.Prefixes.Add("http://127.0.0.1:$apiPort/")
$listener.Start()
$enc = [System.Text.Encoding]::ASCII

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

function getIPUID($ipu){
  $time = ((Get-Date).ToUniversalTime()).ToString("yyyy-MM-ddhh:mm:ss")
  $time = $time.Insert(10,"T")
  $time = $time.Insert($time.Length,".000Z")
  $instrData = Invoke-WebRequest -UseBasicParsing -Uri "http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation" -Method "POST" -Headers @{"Pragma"="no-cache"; "Sec-Fetch-Site"="same-origin"; "Origin"="http://10.224.218.12"; "Accept-Encoding"="gzip, deflate, br"; "Accept-Language"="en-US,en;q=0.9"; "User-Agent"="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36"; "Sec-Fetch-Mode"="cors"; "Accept"="application/json, text/plain, */*"; "Cache-Control"="no-cache"; "Referer"="http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation";} -ContentType "application/json" -Body "{`"queryName`":`"QueryInstrumentationWithLike`",`"header`":{`"id`":{`"uuid`":`"$((New-Guid).Guid)`",`"class`":`"ctia.data_model.HeaderId`"},`"sentTime`":`"$time`",`"actualTime`":`"$time`",`"serviceName`":`"SoaInstrumentationService`",`"userName`":`"$("TCE")`",`"host`":`"s-lctia4-102.ctcis.local`",`"class`":`"ctia.data_model.HeaderData`"},`"criteria`":[{`"name`":`"LIKE_QUERY`",`"stringValue`":`"%$ipu%`",`"class`":`"ctia.data_model.Criterion`"}],`"maxResults`":2,`"projections`":[`"id`"],`"startOffset`":0,`"isRecovered`":false,`"class`":`"ctia.data_model.NamedQueryRequest`"}"
  $instrData = ($instrData.Content | ConvertFrom-Json).payload.instrumentationList
  if($instrData.id.uuid -ne $null){
    if($instrData.id.uuid -is [array]){
      return "MR"
    }
    else{
      return $instrData.id.uuid
    }
  }
  else{
    return "NF"
  }
}

while($true){
  $apiKey = "nv273904bvfd"
  $context = $listener.GetContext()
  $requester = $context.Request.RemoteEndPoint
  $request = $context.Request.RawUrl
  #"STP_CON $((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: $requester -- $request" | Add-Content -Force -Path c:\Automation\IPU\ipu_web_log.txt
  Write-Host -f Yellow "$((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: $requester -- $request"
  $request = $request.Substring(1,$request.Length-1)
  $request = $request.split("/")
  $reqSess = $null
  $byteMess = $null
  $wlCon = @()
  if($request[0] -eq $apiKey){
    switch($request[1]){
      "manageWatch"{
        if($request[2] -eq "add"){
          $watchList = Import-Csv C:\Automation\IPU\OTAWatchlist.csv
          $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
          $jso = $bodyRead.ReadToEnd()
          $ipuRx = $jso | ConvertFrom-Json
          $wlCon += $watchList
          #$wlCon += $ipuRx | ? {$_.IPU -notin $watchList.IPU -and $_.Goal -notin $watchList.Goal}
          #$wlCon += $ipuRx
          $IDs = @()
          #$watchListIDs = $watchList.ID
          $IDs += $watchList.ID
          #$highNum = ($IDs | Sort {[int]$_} -Descending)[0]
          $highNum = $null
          forEach($ipu in $ipuRx){
            if($ipu.ID -eq "UD"){              
              #$newID = 0
              #$newIDs = @()
              if($IDs[0] -eq $null){
                #$ipu.ID = 1
                #$wlCon += $ipu
                #$IDs[0] = 1

                $newStartPos = [int](Get-Content C:\Automation\IPU\temp\watchlistIDPosition.txt) + 1
                $ipu.ID = $newStartPos
                $wlCon += $ipu
                $IDs[0] = $newStartPos
                if($highNum -eq $null){
                  $highNum = $newStartPos
                }
              }
              else{
                if($highNum -eq $null){
                  $highNum = [int]($IDs | Sort -Descending {[int]$_})[0] + 1
                }
                else{
                  $highNum = [int]$highNum + 1
                }
                $ipu.ID = $highNum
                $IDs += $highNum
                #for($i = 0; $i -lt $IDs.Length; $i++){
                #  #if(($i + 1) -notin $watchListIDs -and (($i + 1) -notin $newIDs -and ($i + 1) -ne $newIDs)){
                #  if(($i + 1) -lt [int]::Parse(($IDs | Sort {[int]$_})[$i])){
                #    $ipu.ID = $i + 1
                #    #$newIDs += $i + 1
                #    $IDs += $i + 1
                #    break
                #    #$newID = $i + 1
                #  }
                #  if($i -eq $IDs.Length - 1){
                #    $ipu.ID = $i + 2
                #    $IDs += $i + 2
                #    break
                #  }
                #}
                #if($newID -eq 0){
                #  $ipu.ID = $i + 2
                #}
                #else{
                #  $ipu.ID = $newID
                #}
                $wlCon += $ipu     
              }
            }
            else{
              $wlCon += $ipu
            }
          }
          if($highNum -ne $null){
            $highNum | Set-Content C:\Automation\IPU\temp\watchlistIDPosition.txt -Force
          }
          $wlCon | Export-Csv -NoTypeInformation -Force C:\Automation\IPU\OTAWatchlist.csv
        }
        elseIf($request[2] -eq "remove"){
          $watchList = Import-Csv C:\Automation\IPU\OTAWatchlist.csv
          $wlCon += $watchList
          $wlCon = $wlCon | ? {$_.ID -ne $request[3]}
          $wlCon | Export-Csv -NoTypeInformation -Force C:\Automation\IPU\OTAWatchlist.csv
        }
        break
      }
      "statusUpdate"{
        if($request[2] -eq "complete"){
          $watchList = Import-Csv C:\Automation\IPU\OTAWatchlist.csv
          ($watchList | ? {$_.ID -eq $request[3]}).Complete = $true
          ($watchList | ? {$_.ID -eq $request[3]}).Date = (Get-Date)
          $watchList | Export-Csv C:\Automation\IPU\OTAWatchlist.csv -Force -NoTypeInformation
          $ipuComplete = $watchList | ? {$_.ID -eq $request[3]}
          "$($ipuComplete.IPU),$($ipuComplete.Type),$($ipuComplete.Goal),$($ipuComplete.Initiator),$($ipuComplete.Date)" | Add-Content C:\Automation\IPU\OTAWatchlistComplete.csv -Force
          
          #$ipu = $watchList | ? {$_.ID -eq $request[3]} 
          #Write-Host "$($ipu.IPU) Completed $($ipu.Goal)"


        }
        break
      }
    
      default{
        $context.Response.StatusCode = 404;
      }
    }
  }
  
  else{
    $context.Response.StatusCode = 404;
  }
  $context.Response.Close()
  Start-Sleep -Milliseconds 500
}


# SIG # Begin signature block
# MIIKjgYJKoZIhvcNAQcCoIIKfzCCCnsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUC88RajGyJiNqRiTsyBFBj5M8
# 3bigggfQMIIHzDCCBbSgAwIBAgITHwAACoAM7RE2PVdFewAAAAAKgDANBgkqhkiG
# 9w0BAQ0FADBvMRMwEQYKCZImiZPyLGQBGRYDbWlsMRQwEgYKCZImiZPyLGQBGRYE
# YXJteTEUMBIGCgmSJomT8ixkARkWBGpydGMxFDASBgoJkiaJk/IsZAEZFgRpcy11
# MRYwFAYDVQQDEw1KUlRDLUVOVC1ST09UMB4XDTIxMDUxMzEzNDg0NloXDTMwMTAw
# ODE3NDkwMVowgagxEzARBgoJkiaJk/IsZAEZFgNtaWwxFDASBgoJkiaJk/IsZAEZ
# FgRhcm15MRQwEgYKCZImiZPyLGQBGRYEanJ0YzEUMBIGCgmSJomT8ixkARkWBGlz
# LXUxGTAXBgNVBAsTEEVudGVycHJpc2UgVXNlcnMxDzANBgNVBAsTBkFkbWluczEM
# MAoGA1UECxMDUkNTMRUwEwYDVQQDEwxEZXJlayBKLiBQb2UwggEiMA0GCSqGSIb3
# DQEBAQUAA4IBDwAwggEKAoIBAQCe2yh13p2/CiO7ZJKfKrXtlJQ5TAgmvuxa5fHY
# Qp0978MFgVOUNCnDFezfFoaTt0Nsu+vlTaCZqYYG90/0q/eYBKabxfSBhP44A229
# ZzlfkayDsW80eA7WxY/yFLSNBakTL3fLn26QRQBc1oX8WMwGQ43bJRv6KvsocfXH
# JFWjguOVvWUh/ygjWEVBfc5H06DPfOqgyvxwXwnZLrRxDqCs3Ddoc7/LdXFLqKCk
# DsUyZsbIY8o7orkvbRqtwOtE0xiJO8Uc3iqPWH8Zpp4m41seC9SaZ2wJmnTwq7a4
# 619SN6pUoU3dDa4O3s3vyhi7nlks3UMr9MbVWiVMOmbGQazNAgMBAAGjggMlMIID
# ITA8BgkrBgEEAYI3FQcELzAtBiUrBgEEAYI3FQiD9YcpgrahUe2NN4Wn1E/t3zeB
# OoaO4hKHycZCAgFlAgECMBMGA1UdJQQMMAoGCCsGAQUFBwMDMA4GA1UdDwEB/wQE
# AwIHgDAbBgkrBgEEAYI3FQoEDjAMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBTgIRgs
# JcXZ4OyHx5/MBOKSxFQrozAfBgNVHSMEGDAWgBSP7vW/M1StXUmbyX+WS7uE+l9A
# PTCCAR0GA1UdHwSCARQwggEQMIIBDKCCAQigggEEhoHBbGRhcDovLy9DTj1KUlRD
# LUVOVC1ST09ULENOPUktQ0EtMDEsQ049Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNl
# cnZpY2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9aXMtdSxEQz1q
# cnRjLERDPWFybXksREM9bWlsP2NlcnRpZmljYXRlUmV2b2NhdGlvbkxpc3Q/YmFz
# ZT9vYmplY3RDbGFzcz1jUkxEaXN0cmlidXRpb25Qb2ludIY+aHR0cDovL0ktQ0Et
# MDEuaXMtdS5qcnRjLmFybXkubWlsL0NlcnRFbnJvbGwvSlJUQy1FTlQtUk9PVC5j
# cmwwggEABggrBgEFBQcBAQSB8zCB8DCBuQYIKwYBBQUHMAKGgaxsZGFwOi8vL0NO
# PUpSVEMtRU5ULVJPT1QsQ049QUlBLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2Vz
# LENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9aXMtdSxEQz1qcnRjLERD
# PWFybXksREM9bWlsP2NBQ2VydGlmaWNhdGU/YmFzZT9vYmplY3RDbGFzcz1jZXJ0
# aWZpY2F0aW9uQXV0aG9yaXR5MDIGCCsGAQUFBzABhiZodHRwOi8vSS1DQS0wMS5p
# cy11LmpydGMuYXJteS5taWwvb2NzcDA6BgNVHREEMzAxoC8GCisGAQQBgjcUAgOg
# IQwfZGVyZWsucG9lLnNhQGlzLXUuanJ0Yy5hcm15Lm1pbDANBgkqhkiG9w0BAQ0F
# AAOCAgEAyd46gaLlglRY9ylG0eq+GOGxWPMH9XX4mEjvrYO0bdyCWDk3zwTQQxWt
# k49zaf0enetjWT4rUqUAqJoP+hLVBIjhguDGJtdwcedpMXc/Ig9TxXNOTCM8md5T
# c+uUUnwlVE2wGS67qapT8/P7W/gkNIKoXmFlMbkrXgKyruLSx13O1Mnfn1A0sGln
# lmfd9PtcTxqtMHbbmxi17je05C/wrUYNc2blQMHu41qFMhvAscLx7n+pncjWLNWQ
# H/4wnLJgWuCp9O8v+1e2HTtrKWmY0oeJhxd5djAxt7Kf5kQC78vCIpPJJTf7BywZ
# bevRyw+aSvCTI7Yt1zr0tAKhJO+qRU1N+q+63Yz8jnqHxTcgTeDgjMcLFg10750Y
# xxAJCgLRD7DLaAOmjPNdAtCQvfLAnA8jlBVvy3ZNNAk71GFQEHPfdHwCBQlZHO98
# E3NQoI1AeTzp1OtMJhlE+GHnm4wn8HkXcZoklb0l+U4IAGbYrBAHJQaOUp2okIMC
# nFkh+dnC5SR6hbuhmd3CBXMdIVyYUTGImSTvGDwf5HvinPF6Z4pdDjshja/q7SAC
# rQZKpD8OfYdE9HJn5P7OmvoBF0uQ46qUprS0j6CzBs01q1CMJ0bYFO8q0AkDWhCn
# hy5U7d9a8u9uKWRqLMsTjHMuVS/NRj7exciMtDSqe0B1Rnyta6wxggIoMIICJAIB
# ATCBhjBvMRMwEQYKCZImiZPyLGQBGRYDbWlsMRQwEgYKCZImiZPyLGQBGRYEYXJt
# eTEUMBIGCgmSJomT8ixkARkWBGpydGMxFDASBgoJkiaJk/IsZAEZFgRpcy11MRYw
# FAYDVQQDEw1KUlRDLUVOVC1ST09UAhMfAAAKgAztETY9V0V7AAAAAAqAMAkGBSsO
# AwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqG
# SIb3DQEJBDEWBBRThVPiqHopTfV0vPwbq94GIVnG8DANBgkqhkiG9w0BAQEFAASC
# AQBb9ZgqWE2RdG+awAwlhHXCArT6ebtGXGfiEOLvloZPf46tzbR+ostVPBb0XsSb
# 0Y4kaPxFFM/ijmUkp1CLctTGA+zPNwsxLa9vqzhziEEIy7+7QATVzHwI3h2TvAbl
# i2MgRTVpfQieE6Zz1HRvnPIzBnb1r25z3XUtYykXhMVvhED2Q4pliOW/JX6W0v9m
# FjbaqA5mYworFXdT03urokASU9m+cgYMlsUjixeqZolemoxV4fMGd3ny5f3oBrjL
# ll6CHXDhlb9GE8eeAeTPZCgDJP9cPX1+590huT8N2OSOW7s4mgnngZLXphavgkRN
# usbnddOs7yVVixuYZqqM9MZ5
# SIG # End signature block
