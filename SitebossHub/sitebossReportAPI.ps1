Write-Host -f Cyan "Siteboss Hub Report API"

$PID | Set-Content C:\Automation\AutoServerMonitor\sitebossReportAPI--PID.txt -Force

$conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=C:\Automation\SitebossHub\sitebossData_basics.accdb;Persist Security Info=False;Mode=Read")
$conn.Open()
$cmd = $conn.CreateCommand()
$dt = New-Object System.Data.DataTable
$dbnull = [System.DBNull]::Value

function getPackedDT($datTab){
  if($datTab -ne $null){
    $allCol = $datTab[0].Columns.ColumnName
    $selCol = @()
    forEach($col in $allCol){
      try{
        if(($datTab[0].$col)[0] -ne $dbnull){
          $selCol += $col
        }
      }
      catch{}
    }
    $datTabArray = $true
    if($datTab.($selCol[0]) -isnot [array]){
      $datTabArray = $false
    }
    $packedData = @()
    if($datTab.($selCol[0]) -is [array]){
      $len = $datTab.($selCol[0]).Length
    }
    else{
      $len = 1
    }
    for($i = 0; $i -lt $len; $i++){
      $obj = New-Object -TypeName PSCustomObject
      forEach($prop in $selCol){
        if($datTabArray){
          $obj | Add-Member -Name $prop -Value ($datTab.$prop)[$i] -MemberType NoteProperty
        }
        else{
          $obj | Add-Member -Name $prop -Value $datTab.$prop -MemberType NoteProperty
        }
      }
      $packedData += $obj
    }
    return $packedData
  }
  else{
    return $null
  }
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:9749/")
$listener.Start()
$enc = [System.Text.Encoding]::ASCII


do{
  $context = $listener.GetContext()
  $requester = $context.Request.RemoteEndPoint
  $request = $context.Request.RawUrl
  #Write-Host -f Yellow "$requester -- $request -- $((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt"))"
  "SBR__API  $((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: $requester -- $request" | Add-Content -Force -Path c:\Automation\SitebossHub\sbh_web_log.txt
  $request = $request.Substring(1,$request.Length-1)
  $request = $request.split("/")
    
  switch($request[0]){
    "status" {
      $byteMess = $enc.GetBytes("online")
      $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
      break
    }
    
    "report" {
      $query = "SELECT * FROM LiveData;"
      $cmd.CommandText = $query
      $rdr = $cmd.ExecuteReader()
      $dt.Clear() 
      $dt.Load($rdr) 
      
      $excel = New-Object -ComObject excel.application
      #$excel.Visible = $true
      $null = $excel.Workbooks.Add()
      $sheet = $excel.Worksheets.Item(1)
      $sheet.Name = "Siteboss Report"
      $data = getPackedDT($dt)
      $headers = $data[0].PSObject.Properties.Name
      forEach($row in $data){
        forEach($col in $headers){
          if($row.$col -eq "_NP"){
            $row.$col = ""
          }
        }
      }
      for($i = 0; $i -lt $headers.Length; $i++){
        Switch($headers[$i]){
          "Temp"{
            $excel.Cells.Item(2,($i + 1)) = "Temperature"
          }
          "Humid"{
            $excel.Cells.Item(2,($i + 1)) = "Humidity"
          }
          default{
            $excel.Cells.Item(2,($i + 1)) = $headers[$i]
          }
        }
      }
      $excel.Cells.Item(2,1) = "Site"
      $cellVals = New-Object "object[,]" ($data.Length),($headers.Length)
      for($i = 0; $i -lt $data.Length; $i++){
        for($ii = 0; $ii -lt $headers.Length; $ii++){
          switch($headers[$ii]){
            "Temp"{
              $val = (($data[$i].($headers[$ii])).Replace(" F","") -as [int])
              if($val -ge 90){
                $excel.Cells.Item(($i + 3),$($ii + 1)).Interior.Color = [Microsoft.Office.Interop.Excel.XlRgbColor]::rgbRed
              }
              elseIf($val -ge 80){
                $excel.Cells.Item(($i + 3),$($ii + 1)).Interior.Color = [Microsoft.Office.Interop.Excel.XlRgbColor]::rgbOrange
              }
              $cellVals[$i,$ii] = $data[$i].($headers[$ii])
            }
            "Humid"{
              $val = ($data[$i].($headers[$ii]) -as [int])
              if($val -ge 85){
                $excel.Cells.Item(($i + 3),$($ii + 1)).Interior.Color = [Microsoft.Office.Interop.Excel.XlRgbColor]::rgbRed
              }
              elseIf($val -ge 70){
                $excel.Cells.Item(($i + 3),$($ii + 1)).Interior.Color = [Microsoft.Office.Interop.Excel.XlRgbColor]::rgbOrange
              }
              if($data[$i].($headers[$ii]) -ne ""){
                $cellVals[$i,$ii] = "$($data[$i].($headers[$ii]))%"
              }
              else{
                $cellVals[$i,$ii] = ""
              }
            }
            "Door"{
              if($data[$i].($headers[$ii]) -ne "Door Closed" -and $data[$i].($headers[$ii]) -ne ""){
                $excel.Cells.Item(($i + 3),$($ii + 1)).Interior.Color = [Microsoft.Office.Interop.Excel.XlRgbColor]::rgbRed
              }
              $cellVals[$i,$ii] = $data[$i].($headers[$ii])
            }
            "Battery"{
              if($data[$i].($headers[$ii]) -ne "Battery Charging" -and $data[$i].($headers[$ii]) -ne ""){
                $excel.Cells.Item(($i + 3),$($ii + 1)).Interior.Color = [Microsoft.Office.Interop.Excel.XlRgbColor]::rgbRed
              }
              $cellVals[$i,$ii] = $data[$i].($headers[$ii])
            }
            "Propane"{
              $val = (($data[$i].($headers[$ii])).Replace(" Gallons","") -as [float])
              if($val -le 100 -and $data[$i].($headers[$ii]) -ne ""){
                $excel.Cells.Item(($i + 3),$($ii + 1)).Interior.Color = [Microsoft.Office.Interop.Excel.XlRgbColor]::rgbRed
              }
              elseIf($val -le 200 -and $data[$i].($headers[$ii]) -ne ""){
                $excel.Cells.Item(($i + 3),$($ii + 1)).Interior.Color = [Microsoft.Office.Interop.Excel.XlRgbColor]::rgbOrange
              }
              $cellVals[$i,$ii] = $data[$i].($headers[$ii])
            }
            "Generator"{
              if($data[$i].($headers[$ii]) -ne "Generator OFF" -and $data[$i].($headers[$ii]) -ne ""){
                $excel.Cells.Item(($i + 3),$($ii + 1)).Interior.Color = [Microsoft.Office.Interop.Excel.XlRgbColor]::rgbRed
              }
              $cellVals[$i,$ii] = $data[$i].($headers[$ii])
            }
            "Uptime"{
              $cellVals[$i,$ii] = (New-TimeSpan -Seconds (($data[$i].($headers[$ii]) -as [int]) / 100)).ToString()
            }
            "Ping"{
              if($data[$i].($headers[$ii]) -ne "Reachable" -and $data[$i].($headers[$ii]) -ne ""){
                $excel.Cells.Item(($i + 3),$($ii + 1)).Interior.Color = [Microsoft.Office.Interop.Excel.XlRgbColor]::rgbRed
              }
              $cellVals[$i,$ii] = $data[$i].($headers[$ii])
            }
            default{
              $cellVals[$i,$ii] = $data[$i].($headers[$ii])
            }
          }
        }
      }
      $sheet.Range($sheet.Cells.Item(3,1),$sheet.Cells.Item($data.Length + 2,$headers.Length)) = $cellVals
      $null = $sheet.ListObjects.Add([Microsoft.Office.Interop.Excel.XlListObjectSourceType]::xlSrcRange, $sheet.Range($sheet.Cells.Item(2,1),$sheet.Cells.Item($data.Length + 2,$headers.Length)), $null, [Microsoft.Office.Interop.Excel.XlYesNoGuess]::xlYes)
      $sheet.ListObjects.Item(1).TableStyle = "TableStyleMedium15"
      $null = ($sheet.UsedRange).EntireColumn.AutoFit()
      $sheet.Cells.Item(1,1) = "Siteboss Hub Report"
      $null = $sheet.Range($sheet.Cells.Item(1,1),$sheet.Cells.Item(1,$headers.Length)).Merge()
      $sheet.Cells.Item(1,1).Font.Size = 12
      $sheet.Cells.Item(1,1).Font.Color = [Microsoft.Office.Interop.Excel.XlRgbColor]::rgbWhite
      $sheet.Cells.Item(1,1).Interior.Color = [Microsoft.Office.Interop.Excel.XlRgbColor]::rgbCornflowerBlue
      $sheet.Range($sheet.Cells.Item(1,1),$sheet.Cells.Item(1,$headers.Length)).Borders.LineStyle = 1
      $sheet.Range($sheet.Cells.Item(1,1),$sheet.Cells.Item(1,$headers.Length)).Borders.Weight = [Microsoft.Office.Interop.Excel.XlBorderWeight]::xlThin
      ($sheet.UsedRange).HorizontalAlignment = [Microsoft.Office.Interop.Excel.XlHAlign]::xlHAlignCenter
      $sheet.PageSetup.Orientation = [Microsoft.Office.Interop.Excel.XlPageOrientation]::xlLandscape
      $sheet.PageSetup.Zoom = $false
      $sheet.PageSetup.FitToPagesTall = 1
      $sheet.PageSetup.FitToPagesWide = 1
      $sheet.PageSetup.CenterHorizontally = $true
      $sheet.PageSetup.CenterVertically = $true
      $excel.Application.DisplayAlerts = $false
      $excel.Workbooks.Item(1).SaveAs("C:\Automation\SitebossHub\SitebossHubReport.xlsx")
      $excel.Application.DisplayAlerts = $true
      $excel.Quit()
      $content = Get-Content -Encoding Byte -Path C:\Automation\SitebossHub\SitebossHubReport.xlsx
      $content = [Convert]::ToBase64String($content)
      $content = $enc.GetBytes($content)
      $context.Response.OutputStream.Write($content,0,$content.Length)
      break
    }

    default{
      $context.Response.StatusCode = 404;
    }
  }
  $context.Response.Close()
}
while($true)
# SIG # Begin signature block
# MIIHuwYJKoZIhvcNAQcCoIIHrDCCB6gCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU23H6B1hbdBMeNitXgYwMj1lG
# kFCgggUrMIIFJzCCBM2gAwIBAgIKZ5YFbgAAAABWmjAKBggqhkjOPQQDAjBLMRUw
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
# DQEJBDEWBBRiFsSCPTjjDQps3Vivc8sMZm33GjANBgkqhkiG9w0BAQEFAASCAQAD
# V6TNEjZraEjBRW+UsYabezEAh9wOi9b53iqJdrelduDRMlkyu47IpEMTg1j+/SGn
# gE95XAyW05TUKOlk7Eblh+xCCz75JFtHma/DpwXAqqYTy9v8DAoFw9c+97/XkAQ+
# h/d6hvmbdvqS4MrYwxhPyNlC5IROlyRtk6iGf3faJvyQ1xlX/ySvKmMPK7IYuTpj
# hXDvHa6qm8Se7EAJ0u89ghKeBl+fLCGIxrJu6ONfvN9xPQU6Xh/hQNc0+yiKEKoD
# tWiTl98UEyNYIgkSpvtRVt3EsuP0HTcn8V3TlClbg/HigCXP72b/atNeB+4ea6tb
# t+eQCo+t0dAlL3cRpYL6
# SIG # End signature block
