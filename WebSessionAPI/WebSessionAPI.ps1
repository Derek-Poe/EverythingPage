Write-Host -f Cyan "WebSession API"

Stop-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\WebSessionAPI--PID.txt") -ErrorAction SilentlyContinue
$PID | Set-Content C:\Automation\AutoServerMonitor\WebSessionAPI--PID.txt -Force
$host.UI.RawUI.WindowTitle = "WebSessionAPI"

$sessionTimeout = 480
$authUsers = @("derek.poe.sa","james.roberts.sa","diandra.burk.sa","kenny.grevemberg.sa","mathew.morris.sa","barron.williams.sa","robert.hood.sa","zelda.rogers.sa","zakk.rogerson.sa","john.millender.sa","quincy.courtney.sa","isidro.holguin.sa","heath.jewett.sa","lauren.carruth")

$listener = New-Object System.Net.HttpListener
$apiPort = 9740
#$hostName = "$env:COMPUTERNAME.ctcis.local"
$hostName = "127.0.0.1"
$listener.Prefixes.Add("https://$hostName`:$apiPort/")
$listener.Start()
$enc = [System.Text.Encoding]::ASCII

function getSessionKey(){
  $sessKey = ""
  for($i = 0; $i -lt 24; $i++){
    switch(Get-Random -Minimum 1 -Maximum 4){
      1 {
        $sessKey += "$(Get-Random -Minimum 0 -Maximum 10)"
        break
      }
      2 {
        $sessKey += [char](Get-Random -Minimum 65 -Maximum 91)
        break
      }
      3 {
         $sessKey += [char](Get-Random -Minimum 97 -Maximum 123)
         break
      }
    }
  }
  return $sessKey
}

do{
  if((cat C:\Automation\WebSessionAPI\ws.csv | Select -First 1) -ne "`"User`",`"Session`",`"Time`""){
    rm C:\Automation\WebSessionAPI\ws.csv -Force
    cp C:\Automation\WebSessionAPI\backup\ws_backup.csv C:\Automation\WebSessionAPI -Force
    ren C:\Automation\WebSessionAPI\ws_backup.csv C:\Automation\WebSessionAPI\ws.csv -Force
  }
  $apiKey = "2k3b4j2h4j5tb"
  $context = $listener.GetContext()
  $requester = $context.Request.RemoteEndPoint
  $request = $context.Request.RawUrl
  "IPU_API $((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: $requester -- $request" | Add-Content -Force -Path C:\Automation\WebSessionAPI\websess_web_log.txt
  $request = $request.Substring(1,$request.Length-1)
  $request = $request.split("/")
  $reqSess = $null
  if($request[0] -eq $apiKey){
    switch($request[1]){
      "CL" {       
        $ws = Import-Csv C:\Automation\WebSessionAPI\ws.csv
        $userData = $null
        $session = $null
        $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
        $session = $bodyRead.ReadToEnd()
        $userData = $ws | ? {$_.Session -eq $session}
        if($userData -ne $null){
          if((New-TimeSpan -Start ([DateTime]::Parse($userData.Time)) -End (Get-Date)).Seconds -ge 0 -or $session -eq "2O2KHyBfBrXl1vUnF31yqeQY"){
            $byteMess = $enc.GetBytes("f")
          }
          else{
            ($ws | ? {$_.Session -eq $session}).Time = ((Get-Date).AddMinutes($sessionTimeout)).ToString("MM/dd/yyyy hh:mm:ss tt")
            $byteMess = $enc.GetBytes("t")
          }
        }
        else{
          $byteMess = $enc.GetBytes("f")
        }
        $ws | Export-Csv C:\Automation\WebSessionAPI\ws.csv -Force -NoTypeInformation
        $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        break 
      }
      "LI"{
        $ws = Import-Csv C:\Automation\WebSessionAPI\ws.csv
        $userData = $null
        $user = $null
        $session = $null
        $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
        $user = $bodyRead.ReadToEnd()
        $session = getSessionKey
        $userData = $ws | ? {$_.User -eq $user}
        if($userData -ne $null){
          ($ws | ? {$_.User -eq $user}).Session = $session
          ($ws | ? {$_.User -eq $user}).Time = ((Get-Date).AddMinutes($sessionTimeout)).ToString("MM/dd/yyyy hh:mm:ss tt")
          $ws | Export-Csv C:\Automation\WebSessionAPI\ws.csv -Force -NoTypeInformation
        }
        else{
          "`"$user`",`"$session`",`"$(((Get-Date).AddMinutes($sessionTimeout)).ToString("MM/dd/yyyy hh:mm:ss tt"))`"" | Add-Content C:\Automation\WebSessionAPI\ws.csv -Force
        }
        $byteMess = $enc.GetBytes($session)
        $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        break
      }
      "GU"{
        $ws = Import-Csv C:\Automation\WebSessionAPI\ws.csv
        $user = $null
        $session = $null
        $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
        $session = $bodyRead.ReadToEnd()
        $user = ($ws | ? {$_.Session -eq $session}).User
        if($user -ne $null){
          $byteMess = $enc.GetBytes($user)
        }
        else{
          $byteMess = $enc.GetBytes("NF")
        }
        $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        break
      }
      default{
        $context.Response.StatusCode = 404;
      }  
    }
    $context.Response.Close()
  }
  else{
    $context.Response.StatusCode = 404;
  }
  $context.Response.Close()
  Start-Sleep -Milliseconds 100
}
while($true)

# SIG # Begin signature block
# MIIKjgYJKoZIhvcNAQcCoIIKfzCCCnsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUOuded6rL6lYSGZOqvvFZmr4r
# fgagggfQMIIHzDCCBbSgAwIBAgITHwAACoAM7RE2PVdFewAAAAAKgDANBgkqhkiG
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
# SIb3DQEJBDEWBBS34aGOydJAFgfdaT25kZ0rLi95KjANBgkqhkiG9w0BAQEFAASC
# AQAbPW14faXOG2Z//2jTQ6WmwPshPQupVzIXmQJTYBRww6brUSdmoeQTMTO0z2yZ
# +5dnhSL9aYz94kEzkHcLazCNdjANmN8PxhH7zYEq+OmNHKWIx1xhCqq+E2ajNTAh
# fud6Gwvnkha6H8+36PDSFizp/Gf4S26/UPzY0agf310/wIvbikYI24+M2v4NgKXx
# MEyEa8GvSR+kBBbrtVM0g1hl52Vrukk9Wc9YcETAII9s+4u0J6GANPQzl7/sKP+R
# fA+G2sC8/jf4t6LqvQYLUWI1M4fwK+ontz+43U9EpF3WT9n7G/ZTeCB9w+0pGh5K
# e0NuEZESXS1oRi4unELnzxap
# SIG # End signature block
