Write-Host -f Cyan "Stomp Controller"

$PID | Set-Content C:\Automation\AutoServerMonitor\StompController--PID.txt -Force

$listener = New-Object System.Net.HttpListener
$apiPort = 9734
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

$trackingList = @()
forEach($ipu in (Import-Csv C:\Automation\IPU\trackingList.csv)){
  $trackingList += New-Object PSCustomObject -Property ([ordered]@{IPU=$ipu.IPU;UUID=$ipu.UUID;})
}

while($true){
  $apiKey = "09faswerdf9qg"
  $context = $listener.GetContext()
  $requester = $context.Request.RemoteEndPoint
  $request = $context.Request.RawUrl
  #"STP_CON $((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: $requester -- $request" | Add-Content -Force -Path c:\Automation\IPU\ipu_web_log.txt
  Write-Host -f Yellow "$((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: $requester -- $request"
  $request = $request.Substring(1,$request.Length-1)
  $request = $request.split("/")
  $reqSess = $null
  $byteMess = $null
  if($request[0] -eq $apiKey){
    switch($request[1]){
      "checkIn"{
        if((checkLength $trackingList) -ge 1){
          $byteMess = $enc.GetBytes("$($trackingList.IPU -join ",")|$($trackingList.UUID -join ",")")
        }
        else{
          $byteMess = $enc.GetBytes("...")
        }
        $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        break
      }
      "list"{     
        $uuid = $null
        if($request[2] -eq "add"){
          if($trackingList.IPU -notcontains $request[3]){
            $uuid = getIPUID $request[3]
            $trackingList += New-Object PSCustomObject -Property ([ordered]@{IPU=$request[3];UUID=$uuid;})
            $trackingList | Export-Csv C:\Automation\IPU\trackingList.csv -Force -NoTypeInformation
          }
        }
        elseIf($request[2] -eq "remove"){
          if($trackingList.IPU -contains $request[3]){
            $trackingList = $trackingList | ? {$_.IPU -ne $request[3]}
            $trackingList | Export-Csv C:\Automation\IPU\trackingList.csv -Force -NoTypeInformation
          }
          else{
            $byteMess = $enc.GetBytes("NF")
            $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          }
        }
        break
      }
      "conSend"{
        $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
        $rxData = $bodyRead.ReadToEnd()
        #$jso = ($rxData -split "~~~~")[0] | ConvertFrom-Json
        $ipuUUID = ($rxData -split "~~~~")[0]
        $capTime = [DateTime]::Parse(((($rxData -split "~~~~")[1]) -split "GMT")[0]).ToString("MM/dd/yyyy hh:mm:ss tt")
        #$instrUpdate = New-Object PSCustomObject -Property @{IPU=($trackingList | ? {$_.UUID -eq $jso.instrumentation.current.id.uuid}).IPU}
        $ipuHit = ($trackingList | ? {$_.UUID -eq $ipuUUID}).IPU
        $instrUpdateMsg = ""
        <#
        forEach($prop in ($jso.instrumentation.current.PSObject.Properties.Name | ? {$_ -ne "id"})){
          forEach($state in @("previous","current")){
            $instrUpdate | Add-Member -MemberType NoteProperty -Name "$state`_$prop" -Value $jso.instrumentation.($state).$prop
          }
        }
        forEach($prop in $instrUpdate.PSObject.Properties.Name){
          $instrUpdateMsg += "$prop`: "
          $instrUpdateMsg += "$($instrUpdate.$prop)`n"
        }
        #>
        $instrUpdateMsg += "Found $ipuHit at $capTime!`n"
        $instrUpdateMsg += "`n"
        $byteMess = $enc.GetBytes($instrUpdateMsg)
        $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        Write-Host $instrUpdateMsg
        $webReq = Start-Job -ScriptBlock {param($ipuHit) Invoke-WebRequest "http://127.0.0.1:9733/nv273904bvfd/statusCheck" -Method PUT -Body ((New-Object PSCustomObject -Property (@{IPU=$ipuHit})) | ConvertTo-JSON)} -ArgumentList $ipuHit
      }
    
      default{
        $context.Response.StatusCode = 404;
      }
    }
  }
  elseIf($request[0] -eq "StompClient"){
    $content = Get-Content -Encoding Byte -Path C:\Automation\IPU\stompClient.html
    $context.Response.OutputStream.Write($content,0,$content.Length)
  }
  elseIf($request[0] -eq "stomp.js"){
    $content = Get-Content -Encoding Byte -Path C:\Automation\IPU\stomp.js
    $context.Response.OutputStream.Write($content,0,$content.Length)
  }
  elseIf($request[0] -eq "favicon.ico"){
    $content = Get-Content -Encoding Byte -Path C:\Automation\IPU\favicon.ico
    #$content = [Convert]::ToBase64String($content)
    $context.Response.OutputStream.Write($content,0,$content.Length)
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
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUXV8KtrhoKT60T6gdyU+hrLth
# 6YugggfQMIIHzDCCBbSgAwIBAgITHwAACoAM7RE2PVdFewAAAAAKgDANBgkqhkiG
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
# SIb3DQEJBDEWBBRQTUylGuQIlbwyIdPrmz+saft45TANBgkqhkiG9w0BAQEFAASC
# AQBOj8D77LPGc/dBBRY7OD/ZR4eUjIULOpbH5YX62uCAdN48t24m3ZS2ijy9RMmI
# qbX8Cw1SSercZjXhpl2D3+lEv/gSXBWAzaj5xsgWkrJgyN82OxQpNHLmH69XkZq0
# KkpE5LCw+8t0apUk3LZvW/ORwdwhI/T4NyXqLJ5pXkAFWqiWjETQ5EU5BnFTt2Ey
# sVMEgBFRjKRdpJR6kMRHWMZQ5MpiqRKX+RINDqHos/SgA0GB8AWGyeaAXQ7hHCu4
# uPmD5NSh90++ovVaUkdfBNNOHaUQFM1PqO+e09rRJMjVPHAIWbPZSIMfH1/RzYxY
# T0TJn/3TmW/mxHLbiGrk0aMA
# SIG # End signature block
