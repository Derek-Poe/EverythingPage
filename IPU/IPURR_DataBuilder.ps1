Write-Host -f Cyan "IPURR Data Builder"

Stop-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\IPURR_DataBuilder--PID.txt") -ErrorAction SilentlyContinue
$PID | Set-Content C:\Automation\AutoServerMonitor\IPURR_DataBuilder--PID.txt -Force
$host.UI.RawUI.WindowTitle = "IPURR_DataBuilder"

While($true){
  $startTime = (Get-Date)
  Write-Host "StartTime: $($startTime.ToString(`"MM/dd/yyyy hh:mm:ss tt"))" -NoNewline
  #Write-Host "$((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")): Collecting IPU Data..."
  #$allIPUData = Get-Content \\fileshare01\gateway\StatusLog.csv
  Remove-Item C:\Automation\IPU\temp\StatusLog.csv -Force
  Copy-Item \\i-nasl\RDMS_Logs\StatusLog.csv C:\Automation\IPU\temp -Force
  #$allIpus = Import-Csv \\i-nasl\RDMS_Logs\StatusLog.csv -Header @("IPUName","MsgNum","Serial","Created","Distance","Time","Heading","Speed","EPE","Battery") | Select -Last 10000
  $allIpus = Get-Content C:\Automation\IPU\temp\StatusLog.csv -Tail 10000 | ConvertFrom-Csv -Header @("IPUName","MsgNum","Serial","Created","Distance","Time","Heading","Speed","EPE","Battery")
  $creationTime = (Get-Date)
  #$allIpus = @()
  $sessKey = ""
  for($i = 0; $i -lt 4; $i++){
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

  <#
  forEach($row in $allIPUData){
    $row = $row.Split(",")
    $props = [ordered]@{IPUName=$row[0];MsgNum=$row[1];Serial=$row[2];Created=$row[3];Distance=$row[4];Time=$row[5];Heading=$row[6];Speed=$row[7];EPE=$row[8];Battery=$row[9]}
    $allIpus += New-Object PSCustomObject -Property $props
  }
  #>
  $rates = $allIpus | Select -Unique -ExpandProperty Time
  $ipus = New-Object PSCustomObject
  $inComms = @()
  forEach($rate in $rates){
    $ipus | Add-Member -MemberType NoteProperty -Name $rate -Value $null
    $ipuCon = @()
    $ref = @()
    forEach($ipu in (($allIpus | ? {$_.Time -eq $rate}) | Sort Created -Descending)){
      #$ipu.Created

      #if($ipu.IPUName -eq "IPU-0013655"){
      #  Write-Host -f Yellow "$($ipu.IPUName) -- $($ipu.Created)"
      #}

      if($ipu.IPUName -notin $ref -and (New-TimeSpan -Start ([DateTimeOffset]::FromUnixTimeSeconds($ipu.created)).DateTime -End (($creationTime).ToUniversalTime())).Minutes -le 2){
        $ipuCon += $ipu
        $ref += $ipu.IPUName
        $inComms += $ipu.IPUName
      }
    }
    $ipus.$rate = $ipuCon
  }
  "ICIPU`n$($inComms -join "`n")" | Set-Content C:\Automation\IPU\inCommsIPUs.csv -Force
  forEach($prop in $ipus.PSObject.Properties.Name){
    if($ipus.($prop).Length -eq 0){
      $ipus.PSObject.Properties.Remove($prop)
    }
  }
  $summaryData = New-Object PSCustomObject
  forEach($rate in $ipus.PSObject.Properties.Name){
    $summaryData | Add-Member -MemberType NoteProperty -Name $rate -Value $ipus.($rate).Length
    $ipus.$rate | Export-Csv C:\Automation\IPU\temp\IPURR_DataCollection_$sessKey`_$rate.csv  -Force -NoTypeInformation
  }
  $summaryData | Add-Member -MemberType NoteProperty -Name Time -Value $creationTime.ToString("MM/dd/yyyy hh:mm:ss tt")
  $summaryData | Export-Csv C:\Automation\IPU\temp\IPURR_DataCollection_$sessKey`_summary.csv -Force -NoTypeInformation

  forEach($file in (Get-ChildItem C:\Automation\IPU\temp | ? {$_.Name -like "IPURR_DataCollection_*"})){
    if($file.Name.split("_")[2] -ne $sessKey){
      $file | Remove-Item -Force
    }
  }
  #Write-Host "$((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")): Data Collection Completed"
  #Write-Host "-------------------------------------------------"
  $totalLength = 0
  forEach($prop in ($summaryData.PSObject.Properties.Name | ? {$_ -ne "Time"})){
    $totalLength += $summaryData.$prop
  }
  Write-Host " -- TotalEntries: $($allIpus.Length) -- InComms: $totalLength -- ExecTime: $((New-TimeSpan -Start $startTime -End (Get-Date)).ToString())"
  $execTime = (New-TimeSpan -Start $startTime -End (Get-Date))
  "StartTime: $($startTime.ToString(`"MM/dd/yyyy hh:mm:ss tt")) -- TotalEntries: $($allIpus.Length) -- InComms: $totalLength -- ExecTime: $($execTime.ToString())" | Add-Content C:\Automation\IPU\ipurrDataBuilderDebug.txt -Force
  if($execTime.TotalSeconds -lt 10){
    Start-Sleep -Milliseconds (10000 - [Math]::Round($execTime.TotalMilliseconds))
  }
}
# SIG # Begin signature block
# MIIKjgYJKoZIhvcNAQcCoIIKfzCCCnsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUqgN+kwc3BZ1BStxXUWvZDyjV
# MYmgggfQMIIHzDCCBbSgAwIBAgITHwAACoAM7RE2PVdFewAAAAAKgDANBgkqhkiG
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
# SIb3DQEJBDEWBBQk+x6L4Zxgm6zJswHID0Eyth6E2zANBgkqhkiG9w0BAQEFAASC
# AQArO34yxAQCq7t7pRy/DmhxtROc/DDtrNrFMDaU/U8aiCL0pzBTOiFDhYAEXIgK
# nj2VcC97ua29txDwM3AklaXRclS0Oj8uTQzFBos4V9Nv4SnQm0rr4+EWt2lNXXQP
# yzsrNYtJspY0XmaEJF/NRJ2J8h/Jto5YoGf/6cDZNjto20Gc4gI1MkwVIiUevXES
# qaVJYGjKShHIRGWBGMnPTNJuTCKNQ76qMkG1ZyMRK7NcYg0JdGEeQpdMJdHvQnr/
# yuB621pyRiVy1JZslwpCIZKBQeDE0i2WjuqPzXjBKa1HcosMGrQKZ/8xzwADF6zC
# cCpiUbcJycnCmYgTrz9ojQrZ
# SIG # End signature block
