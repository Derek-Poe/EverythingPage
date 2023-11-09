Write-Host -f Cyan "Automation Server Monitor API"

$PID | Set-Content C:\Automation\AutoServerMonitor\autoServerMonitorAPI--PID.txt -Force
$authUsers = @("dpoe","jroberts","ddavis","dburk","kgrevemberg","rhood","zrogers","qcourtney","iholguin","hjewett")

#$conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=C:\Automation\CRM\CRM.accdb;Persist Security Info=False;Mode=ReadWrite")
#$conn.Open()
$listener = New-Object System.Net.HttpListener
$apiPort = Get-Content C:\Automation\AutoServerMonitor\apiPort.txt
$enc = [System.Text.Encoding]::ASCII
$hostName = "$env:COMPUTERNAME.ctcis.local"
$listener.Prefixes.Add("https://$hostName`:$apiPort/")

$listener.Start()

function checkLogin($sessDat,$cmd,$dt){
  $session = $sessDat
  $query = "SELECT [Time] FROM UserEntry WHERE [Session] LIKE '$session';"
  $cmd.CommandText = $query
  $rdr = $cmd.ExecuteReader()
  $dt.Clear() 
  $dt.Load($rdr)

  if($dt.Time.Length -gt 0){
    $ts = New-TimeSpan -Start (Get-Date) -End ([datetime]::Parse($dt[0].Time))
    #Write-Host "$session $($ts.Seconds)"
    if($ts.Seconds -ge 0){
      $etime = (Get-Date).AddMinutes(30).ToString("MM/dd/yyyy hh:mm:ss tt")
      $query = "UPDATE UserEntry SET [Time]='$etime' WHERE [Session] LIKE '$session';"
      $cmd.CommandText = $query
      $execute = $cmd.ExecuteNonQuery()
      #Write-Host "Session Time Set"
      return "Logged In"
    }
    else{
      return "Not Logged In"
    }
  }
  else{
    return "Not Logged In"
  }
}

while($true){
  $apiKey = Get-Content C:\Automation\AutoServerMonitor\apiKey.txt
  $context = $listener.GetContext()
  $requester = $context.Request.RemoteEndPoint
  $request = $context.Request.RawUrl
  "ASM_API $((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: $requester -- $request" | Add-Content -Force -Path c:\Automation\AutoServerMonitor\autoServMon_web_log.txt
  $request = $request.Substring(1,$request.Length-1)
  $request = $request.split("/")
  if($request[0] -eq $apiKey){
    
    switch($request[1]){

      "stats" {
        $byteMess = $enc.GetBytes((Import-Csv C:\Automation\AutoServerMonitor\resourceStats.csv | ConvertTo-JSON))
        $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        break
      }

      "getPage" {
        $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
        $cr = ($bodyRead.ReadToEnd()).Split(",")
        $pc = $false
        $adCheck = $null
        $adCheck = New-Object System.DirectoryServices.DirectoryEntry -ArgumentList "LDAP://ctcis.local",$cr[0],$cr[1]
        if($adCheck.Name -ne $null){
          $pc = $true
        }
        if($pc -and $cr[0] -in $authUsers){
          $content = Get-Content -Encoding Byte -Path C:\Automation\AutoServerMonitor\autoServerMonitorPageFull.html
          $context.Response.OutputStream.Write($content,0,$content.Length)
        }
        else{
          $byteMess = $enc.GetBytes("IL")
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        }
        break
      }

      "proUp" {
        $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
        $proReq = ($bodyRead.ReadToEnd()).Split(",")
        if($proReq[0] -eq "stop" -or $proReq[0] -eq "start"){
          $pros = $null
          $pros = @()
          switch($proReq[1]){
            "CRM" {
              $pros += "crmAPI_runspaceEnabled"
              $pros += "adAPI_runspaceEnabled"
              $startPro = "C:\Automation\CRM\startCRM.ps1"
              break
            }
            "Automation Server Monitor" {
              $pros += "resourceDataBuilder"
              $pros += "autoServerMonitorAPI"
              $startPro = "C:\Automation\AutoServerMonitor\startAutoServMon.ps1"
              break
            }
            "IPU" {
              $pros += "IPURR_DataBuilder"
              $pros += "IPUAPI"
              $pros += "IPUOTADataBuilder_multiInstance"
              $pros += "WebSessionAPI"
              $startPro = "C:\Automation\IPU\startIPU.ps1"
              break
            }
            "AutoNR" {
              $pros += "nrDataBuilder"
              $startPro = "C:\Automation\AutoNR\startAutoNR.ps1"
              break
            }
            "Siteboss Hub" {
              $pros += "sitebossPoller"
              $pros += "sitebossHistoryBuilder"
              $pros += "sitebossReportAPI"
              $pros += "sitebossAPI"
              $startPro = "C:\Automation\SitebossHub\startSitebossHub.ps1"
              break
            }
          }
          if($proReq[0] -eq "stop"){
            forEach($pro in $pros){
              Get-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\$($pro)--PID.txt") -ErrorAction SilentlyContinue | Stop-Process
            }
          }
          elseIf($proReq[0] -eq "start"){
            if($proReq[1] -eq "Automation Server Monitor"){
              Start-Process "C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" $startPro
              forEach($pro in $pros){
                Get-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\$($pro)--PID.txt") -ErrorAction SilentlyContinue | Stop-Process
              }          
            }
            else{
              forEach($pro in $pros){
                Get-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\$($pro)--PID.txt") -ErrorAction SilentlyContinue | Stop-Process
              }
              Start-Sleep -Seconds 5
              Start-Process "C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" $startPro
            }
          }
          $byteMess = $enc.GetBytes("Complete")
        }
        else{
          $byteMess = $enc.GetBytes("Error")        
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
  elseIf($request[0] -eq "AutoServMon"){
    $content = Get-Content -Encoding Byte -Path C:\Automation\AutoServerMonitor\autoServerMonitorPage.html
    $context.Response.OutputStream.Write($content,0,$content.Length)
  }
  $context.Response.Close()
  Start-Sleep -Milliseconds 500
}
# SIG # Begin signature block
# MIIHuwYJKoZIhvcNAQcCoIIHrDCCB6gCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU9VDUDuK50OtX6qeXzBAcJuVN
# 5kqgggUrMIIFJzCCBM2gAwIBAgIKZ5YFbgAAAABWmjAKBggqhkjOPQQDAjBLMRUw
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
# DQEJBDEWBBQs8BZByKRfyzcnPInPH3VQZeeb7DANBgkqhkiG9w0BAQEFAASCAQCV
# ChO69lrIHt3SSe4NlwpcNSYN44+jNyRNRsuRaWeqlPXZbNDmlSYwDSVVK6YVqj+I
# W3k8WDcQmfhigyzCny+DG16ackaFQk2VW4WFpqdAL6xE8l8g5AnGThvP19LoN27U
# diVHh8g9+qEaMVM3pwcgV9C6olHSBTtamnh5KpbeeCQrhz25YFxNkVxzaJJ7z8k/
# tiDryE+XtAdFWwfbrX/gI1QModPTbQ0Ggrkhomei6besgEzPMeTxIOzBdpYPJ6Fb
# 2Q1Zye3MZmGpjF4U5/HN/pSJ/P1uQzqiUtBMBldyFZNgF7U0UJ3ZCXXKzglUJf29
# MyCo/xOJ5/H6g71i4KPa
# SIG # End signature block
