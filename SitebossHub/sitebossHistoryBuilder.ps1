Write-Host -f Cyan "Siteboss History Builder"

$PID | Set-Content C:\Automation\AutoServerMonitor\sitebossHistoryBuilder--PID.txt -Force
$host.UI.RawUI.WindowTitle = "sitebossHistoryBuilder"

#$conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=\\fileshare01\home\dpoe\sitebossScripts\sitebossData.accdb;Persist Security Info=False;Mode=ReadWrite")
#$conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=C:\OfflineSitebossHub\sitebossData_basics.accdb;Persist Security Info=False;Mode=ReadWrite")
#$conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=C:\Users\ctiaadmin\Desktop\Temp_SitebossHub\sitebossData_basics.accdb;Persist Security Info=False;Mode=ReadWrite")
#$conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.Jet.OLEDB.4.0;Data Source=C:\Users\ctiaadmin\Desktop\Temp_SitebossHub\sitebossData_basics.mdb;Persist Security Info=False;Mode=ReadWrite")
$conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=C:\Automation\SitebossHub\sitebossData_basics.accdb;Persist Security Info=False;Mode=ReadWrite")
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

function buildTable(){
  #if((Get-Date).Day -ne $Global:currentDay){
    "SHB__API  $((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: Building New History Table..." | Add-Content -Force -Path c:\Automation\SitebossHub\sbh_web_log.txt
    $query = "DROP TABLE HistoricalData;"
    $cmd.CommandText = $query
    $execute = $cmd.ExecuteNonQuery()
  #}

  $query = "SELECT * FROM LiveData;"
  $cmd.CommandText = $query
  $rdr = $cmd.ExecuteReader()
  $dt.Clear() 
  $dt.Load($rdr)
  $liveDataRef = getPackedDT($dt)

  forEach($prop in $liveDataRef[0].PSObject.Properties.Name){
    if($prop -eq "IP" -or $prop -eq "Uptime" -or $prop -eq "LastUpdated"){
      $liveDataRef[0].PSObject.Properties.Remove($prop)
    }
  }

  $colNames = ""
  0..($liveDataRef[0].PSObject.Properties.Name.Length - 1) | % {
    $i = $_
    if($liveDataRef[0].PSObject.Properties.Name[$i] -eq "CellSite"){
      $colNames += ",$($liveDataRef[0].PSObject.Properties.Name[$i]) varchar(255)"
    }
    else{
      1..7 | % {
        $ii = $_
        $colNames += ",$($liveDataRef[0].PSObject.Properties.Name[$i])$ii varchar(255)"
      }
    }
  }
  $colNames = $colNames.Substring(1)

  #if((Get-Date).Day -ne $Global:currentDay){
    $query = "CREATE TABLE HistoricalData ($colNames);"
    $cmd.CommandText = $query
    $execute = $cmd.ExecuteNonQuery()
  #}

  $cols = ($colNames.Replace(" varchar(255)","")).Split(",")
  $colNames = ",[CellSite]"
  $rowFill = ""
  1..($cols.Length - 1) | % {
    $i = $_
    $colNames += ",[$($cols[$i])]"
    if($i -gt 1){
      $rowFill += ",'_NP'"
    }
  }
  $colNames = "($($colNames.Substring(1)))"
  #if((Get-Date).Day -ne $Global:currentDay){
    0..($liveDataRef.Length-1) | % {
      $i = $_
      $query = "INSERT INTO HistoricalData $colNames VALUES ('$($liveDataRef[$i].CellSite)','_NP'$rowFill);"
      $cmd.CommandText = $query
      $execute = $cmd.ExecuteNonQuery()
    }

    $Global:sbs = New-Object -TypeName PSCustomObject
    $props = ""
    1..($cols.Length - 1) | % {
      $i = $_
      #
      #
      #$props += "`n$($cols[$i])=$null"
      #
      #
      $props += "`n$($cols[$i])=_NP"
    }
    $props = $props.Substring(1)
    0..($liveDataRef.Length-1) | % {
      $i = $_
      $Global:sbs | Add-Member -MemberType NoteProperty -Name $liveDataRef[$i].CellSite -Value $null
      $Global:sbs.($liveDataRef[$i].CellSite) = ($props | ConvertFrom-StringData)
    }
  #if((Get-Date).Day -ne $Global:currentDay){
    Get-Date | Set-Content C:\Automation\SitebossHub\historyDate.txt -Force
  #}
}
$Global:currentDay = ([DateTime]::Parse((Get-Content C:\Automation\SitebossHub\historyDate.txt))).Day
buildTable
do{
  "SHB__API  $((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: Collecting Data..." | Add-Content -Force -Path c:\Automation\SitebossHub\sbh_web_log.txt
  if((Get-Date).Day -ne $Global:currentDay){
    buildTable
  }
  $Global:currentDay = ([DateTime]::Parse((Get-Content C:\Automation\SitebossHub\historyDate.txt))).Day

  $query = "SELECT * FROM LiveData;"
  $cmd.CommandText = $query
  $rdr = $cmd.ExecuteReader()
  $dt.Clear() 
  $dt.Load($rdr)
  $liveData = getPackedDT($dt)

  forEach($liveRow in $liveData){
    forEach($liveCol in $liveRow.PSObject.Properties.Name){
      if($liveCol -ne "CellSite" -and $liveCol -ne "IP" -and $liveCol -ne "Uptime" -and $liveCol -ne "LastUpdated" -and $liveCol -ne "HistFull"){
        if($Global:sbs.($($liveRow.CellSite))."$liveCol`7" -ne $liveRow.$liveCol){
          2..7 | % {
            $i = $_
            $Global:sbs.($($liveRow.CellSite))."$liveCol$($i - 1)" = $Global:sbs.($($liveRow.CellSite))."$liveCol$i"
          }
          $Global:sbs.($($liveRow.CellSite))."$liveCol`7" = $liveRow.$liveCol
          $query = "UPDATE HistoricalData SET [$liveCol`1]='$($Global:sbs.($liveRow.CellSite)."$liveCol`1")',
            [$liveCol`2]='$($Global:sbs.($liveRow.CellSite)."$liveCol`2")',
            [$liveCol`3]='$($Global:sbs.($liveRow.CellSite)."$liveCol`3")',
            [$liveCol`4]='$($Global:sbs.($liveRow.CellSite)."$liveCol`4")',
            [$liveCol`5]='$($Global:sbs.($liveRow.CellSite)."$liveCol`5")',
            [$liveCol`6]='$($Global:sbs.($liveRow.CellSite)."$liveCol`6")',
            [$liveCol`7]='$($Global:sbs.($liveRow.CellSite)."$liveCol`7")' 
            WHERE [CellSite] LIKE '$($liveRow.CellSite)';"
          $cmd.CommandText = $query
          $execute = $cmd.ExecuteNonQuery()
        }
      }
    }
  }
  
  $inter = 30
  "SHB__API  $((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: Data Collected" | Add-Content -Force -Path c:\Automation\SitebossHub\sbh_web_log.txt
  $inter..1 | % {
    $i = $_
    Start-Sleep -Seconds 1
  }
}
while($true)
# SIG # Begin signature block
# MIIHuwYJKoZIhvcNAQcCoIIHrDCCB6gCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUsP0MbOPjHPWCVoastee/41LG
# 7IegggUrMIIFJzCCBM2gAwIBAgIKZ5YFbgAAAABWmjAKBggqhkjOPQQDAjBLMRUw
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
# DQEJBDEWBBQnTbHPFa7EXXexOA5D6ZARexPBLTANBgkqhkiG9w0BAQEFAASCAQBm
# kuEiWPYoPHWLIIxMylZVw4He9Nt49RocRpa81wgDc+JQ3ts1khIXlJ68sG6tZUNJ
# GxZASp38lmEl3CeSwGfdHY1u2N2IMx8e8EdrBK6+bIGzNa3AU5DeTxK4zymm30kl
# m0Hf4JMr4YkPNVyAv7HPpkv1PgkAkX/XH0qujodEND62P60No/sntRZuYl7qzwuA
# 11EB1j1B2mC1HYlwbTQ+Uv85VYArDk2H/Cn6j+XaeGdFmyFNAUv9CHFik17IQiDk
# 3N0UewqsvBhr5rqEopjicVO6sFQiBvRorylPVznQg3HAN6mNS3vjr5Ppp1lSVr7S
# fDRuHeB1BwHcwGk37eeO
# SIG # End signature block
