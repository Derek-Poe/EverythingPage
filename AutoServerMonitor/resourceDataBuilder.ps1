Write-Host -f Cyan "Automation Server Resource Data Builder"

Stop-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\resourceDataBuilder--PID.txt") -ErrorAction SilentlyContinue
$PID | Set-Content C:\Automation\AutoServerMonitor\resourceDataBuilder--PID.txt -Force
$host.UI.RawUI.WindowTitle = "resourceDataBuilder"

$auto2Session = New-PSSession Net-Admin-TC216
While($true){
  $startTime = (Get-Date)
  $stats = New-Object PSCustomObject
  $stats | Add-Member -MemberType NoteProperty -Name Auto1_CPU -Value (GWMI win32_processor | Measure LoadPercentage -Average | Select Average).Average
  $mems = GWMI win32_operatingsystem; $stats | Add-Member -MemberType NoteProperty -Name Auto1_RAM -Value ([Math]::Round((((($mems.TotalVisibleMemorySize - $mems.FreePhysicalMemory) * 100) / $mems.TotalVisibleMemorySize)),0))
  $storage = Get-Volume c
  $stats | Add-Member -MemberType NoteProperty -Name Auto1_Storage -Value ([Math]::Round(($storage.SizeRemaining / $storage.Size), 2) * 100)
  #$auto2Stats = Invoke-Command -ComputerName Net-Admin-TC216 -ScriptBlock {
  $auto2Stats = Invoke-Command -Session $auto2Session -ScriptBlock {
    $mems = GWMI win32_operatingsystem
    $storage = Get-Volume c
    return @((GWMI win32_processor | Measure LoadPercentage -Average | Select Average).Average, [Math]::Round((((($mems.TotalVisibleMemorySize - $mems.FreePhysicalMemory) * 100) / $mems.TotalVisibleMemorySize)),0), ([Math]::Round(($storage.SizeRemaining / $storage.Size), 2) * 100))
  }
  $stats | Add-Member -MemberType NoteProperty -Name Auto2_CPU -Value $auto2Stats[0]
  $stats | Add-Member -MemberType NoteProperty -Name Auto2_RAM -Value $auto2Stats[1]
  $stats | Add-Member -MemberType NoteProperty -Name Auto2_Storage -Value $auto2Stats[2]
  forEach($compPID in (Get-ChildItem "C:\Automation\AutoServerMonitor" | ? {$_.Name -like "*--PID.txt"})){
    $name = $null
    switch($compPID.Name.Split("--")[0]){
      "autoServerMonitorAPI" {
        $name = "autoServMonAPI"
        break
      }
      "sitebossAPI" {
        $name = "sbAPI"
        break
      }
      "crmAPI_runspaceEnabled" {
        $name = "crmAPI"
        break
      }
      "nrDataBuilder" {
        $name = "nrDataBuilder"
        break
      }
      "resourceDataBuilder" {
        $name = "autoServResourceDataBuilder"
        break
      }
      "adAPI_runspaceEnabled" {
        $name = "adAPI"
        break
      }
      "IPURR_DataBuilder" {
        $name = "ipuDataBuilder"
        break
      }
      "IPUAPI" {
        $name = "ipuAPI"
        break
      }
      "sitebossHistoryBuilder" {
        $name = "sbhBuilder"
        break
      }
      "sitebossPoller" {
        $name = "sbPoller"
        break
      }
      "sitebossReportAPI" {
        $name = "sbrAPI"
        break
      }
      default {
        $name = $compPID.Name.Split("--")[0]
      }
    }
    $proCheck = $null
    $proCheck = Get-Process -Id (Get-Content $compPID.FullName) -ErrorAction SilentlyContinue
    if($proCheck -ne $null){
      $stats | Add-Member -Force -MemberType NoteProperty -Name $name -Value "Online"
    }
    else{
      $stats | Add-Member -Force -MemberType NoteProperty -Name $name -Value "Offline"
    }
  }
  forEach($folder in (Get-ChildItem C:\Automation | ? {$_.PSIsContainer})){
    $size = ((Get-ChildItem -Path $folder.FullName -Recurse) | Measure-Object -Property Length -Sum).Sum
    if($size -ge 1000000000000){
      $size /= 1TB
      $size = "$([math]::Round($size, 2)) TB"
    }
    elseIf($size -ge 1000000000){
      $size /= 1GB
      $size = "$([math]::Round($size, 2)) GB"
    }
    elseIf($size -ge 1000000){
      $size /= 1MB
      $size = "$([math]::Round($size, 2)) MB"
    }
    elseIf($size -ge 1000){
      $size /= 1KB
      $size = "$([math]::Round($size, 2)) KB"
    }
    elseIf($size -lt 1000){
      $size = "$([math]::Round($size, 2)) B"
    }
    $stats | Add-Member -MemberType NoteProperty -Name $folder.Name -Value $size
  }
  $stats | Add-Member -MemberType NoteProperty -Name Time -Value (Get-Date)
  $stats | Export-Csv -NoTypeInformation -Force C:\Automation\AutoServerMonitor\resourceStats.csv
  $execTime = (New-TimeSpan -Start $startTime -End (Get-Date))
  Write-Host "ExecTime: $($execTime.ToString())"
  if($execTime.TotalSeconds -lt 5){
    Start-Sleep -Milliseconds (5000 - [Math]::Round($execTime.TotalMilliseconds))
  }
  #Start-Sleep -Seconds 5
}
# SIG # Begin signature block
# MIIHuwYJKoZIhvcNAQcCoIIHrDCCB6gCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUuvE+zrcQi35lxB6WVSfD4Eap
# zgKgggUrMIIFJzCCBM2gAwIBAgIKZ5YFbgAAAABWmjAKBggqhkjOPQQDAjBLMRUw
# EwYKCZImiZPyLGQBGRYFbG9jYWwxFTATBgoJkiaJk/IsZAEZFgVjdGNpczEbMBkG
# A1UEAxMSQ1RDSVMtSS1DRVJULTAxLUNBMB4XDTIxMDIxMDE0MjQzNFoXDTIzMDIx
# MDE0MjQzNFowVTEVMBMGCgmSJomT8ixkARkWBWxvY2FsMRUwEwYKCZImiZPyLGQB
# GRYFY3RjaXMxDjAMBgNVBAsTBUFETUlOMRUwEwYDVQQDEwxEZXJlayBKLiBQb2Uw
# ggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCoAGCJf/9NdLKMRJ5WtRk2
# T6w3B6KBRGIfORUGY/GnUH0pGZ+wmh/billQqqcj9t392eliI/CNCL6zK3To2hSM
# pQC7n45Dgk4tSEcxaC1cEJEFNYDtLn+HpliSj+lNw+f2uUp2uL7w2NczHOUXxcx+
# LswYRzqVJKukV61bIQScuf8zS+Iv1Da4lKGO0VGTtAvIIw1MSwrpvBjHORD25gk7
# 4XzN3yGFCYb29EYR/Fbo7kYlJ0XXSe/6DAlA0MLL1IS6xUBIBvDzZ2hp1KivsSZO
# zXfzAY0fY/48p0D/LTWwxGjkGIZyuI3SLFLF/Ts1raxy+nqWZmZ9KPWSJxfw4D2F
# AgMBAAGjggLCMIICvjA5BgkrBgEEAYI3FQcELDAqBiIrBgEEAYI3FQiEt8JAgcTy
# CIONgxq0t2rkvD9E3sh00d5YAgFkAgEDMBMGA1UdJQQMMAoGCCsGAQUFBwMDMA4G
# A1UdDwEB/wQEAwIHgDAbBgkrBgEEAYI3FQoEDjAMMAoGCCsGAQUFBwMDMB0GA1Ud
# DgQWBBSuW3Q4sfdUH4spt3dl5je2QciHoDAfBgNVHSMEGDAWgBR6KcJTdM9S8jsF
# 1anrC1+iSPU0EzCCAQkGA1UdHwSCAQAwgf0wgfqggfeggfSGgbtsZGFwOi8vL0NO
# PUNUQ0lTLUktQ0VSVC0wMS1DQSxDTj1JLUNFUlQtMDEsQ049Q0RQLENOPVB1Ymxp
# YyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24s
# REM9Y3RjaXMsREM9bG9jYWw/Y2VydGlmaWNhdGVSZXZvY2F0aW9uTGlzdD9iYXNl
# P29iamVjdENsYXNzPWNSTERpc3RyaWJ1dGlvblBvaW50hjRmaWxlOi8vXFxJLUNF
# UlQtMDFcQ1JMRGlzdHJvJFxDVENJUy1JLUNFUlQtMDEtQ0EuY3JsMIHEBggrBgEF
# BQcBAQSBtzCBtDCBsQYIKwYBBQUHMAKGgaRsZGFwOi8vL0NOPUNUQ0lTLUktQ0VS
# VC0wMS1DQSxDTj1BSUEsQ049UHVibGljJTIwS2V5JTIwU2VydmljZXMsQ049U2Vy
# dmljZXMsQ049Q29uZmlndXJhdGlvbixEQz1jdGNpcyxEQz1sb2NhbD9jQUNlcnRp
# ZmljYXRlP2Jhc2U/b2JqZWN0Q2xhc3M9Y2VydGlmaWNhdGlvbkF1dGhvcml0eTAr
# BgNVHREEJDAioCAGCisGAQQBgjcUAgOgEgwQZHBvZUBjdGNpcy5sb2NhbDAKBggq
# hkjOPQQDAgNIADBFAiEAsdrdbkodm7tOfLSUt9hgVT9M/BKXN4GixGNXSvhsFOoC
# ICKX+IdDtd35lhHjWyjrMoL3KyQRpeC4DoD0CMTFr6WXMYIB+jCCAfYCAQEwWTBL
# MRUwEwYKCZImiZPyLGQBGRYFbG9jYWwxFTATBgoJkiaJk/IsZAEZFgVjdGNpczEb
# MBkGA1UEAxMSQ1RDSVMtSS1DRVJULTAxLUNBAgpnlgVuAAAAAFaaMAkGBSsOAwIa
# BQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgor
# BgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3
# DQEJBDEWBBRbutMh4tKvQYwIKcRI6Q6YRv1YkTANBgkqhkiG9w0BAQEFAASCAQAf
# 1ShiWgJoLQLRX3L1etODStSyyBxapX/ncH8q3aN4zoOYTDQqtCKGpBvoowXDL0bV
# BsIO5LCJuX0aoW2yEa/n4UPjMlep5XyOQ8kJq3tRVSpVa9n5tOkp8iTDoHlnka7F
# y4Ue2uFs+dcuJl5sioLxQBKF5o6FFgfBNQ4gfrXNN5k/7ZvO7RsPCwklGIrZVlOl
# 6B6AU4VYEMXpKBv125Um5dmt1Rk9AOLUXvkH4NMa7HpujLeX0MdBVK9z7HiUbpty
# BH37LNp0sdWTFfEdMJZLuk9oEBPpFQ/et0jM2+sYg/PD5YugpPe/4Xpe3JbiGPA/
# r6EliIbx86iCHnOesVMB
# SIG # End signature block
