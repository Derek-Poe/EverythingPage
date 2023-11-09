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

function buildTable($liveDataRef){
  Write-Host -f Yellow "Building New History"
  $query = "DROP TABLE HistoricalData2;"
  $cmd.CommandText = $query
  $execute = $cmd.ExecuteNonQuery()

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
      $colNames += ",$($liveDataRef[0].PSObject.Properties.Name[$i]) varchar(255)"
    }
  }
  $colNames += ",ChangeType varchar(255)"
  $colNames += ",ChangeTime varchar(255)"
  $colNames = $colNames.Substring(1)

  $query = "CREATE TABLE HistoricalData2 (ID AUTOINCREMENT (1,1),$colNames);"
  $cmd.CommandText = $query
  $execute = $cmd.ExecuteNonQuery()

  $query = "ALTER TABLE HistoricalData2 ADD PRIMARY KEY (ID);"
  $cmd.CommandText = $query
  $execute = $cmd.ExecuteNonQuery()

}
#if(!(history table exist)){
  #buildTable($liveDataRef)
#}
function buildObjects($liveDataRef){
  #$Global:sbs = New-Object -TypeName PSCustomObject
  $Global:liveDataObj = New-Object -TypeName PSCustomObject
  $cols = $liveDataRef[0].PSObject.Properties.Name #| ? {$_ -ne "CellSite"}
  $props = ""
  1..($cols.Length - 1) | % {
    $i = $_
    $props += "`n$($cols[$i])=_NP"
  }
  $props = $props.Substring(1)
  0..($liveDataRef.Length-1) | % {
    $i = $_
    #$Global:sbs | Add-Member -MemberType NoteProperty -Name $liveDataRef[$i].CellSite -Value $null
    #$Global:sbs.($liveDataRef[$i].CellSite) = ($props | ConvertFrom-StringData)
    $Global:liveDataObj | Add-Member -MemberType NoteProperty -Name $liveDataRef[$i].CellSite -Value $null
    $Global:liveDataObj.($liveDataRef[$i].CellSite) = ($props | ConvertFrom-StringData)
  }
  #$props += "`nCellSite=_NP"

  #$Global:liveDataObj = New-Object -TypeName PSCustomObject -Property ($props | ConvertFrom-StringData)
}


$conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=C:\Automation\SitebossHub\sitebossData_basics.accdb;Persist Security Info=False;Mode=ReadWrite")
$conn.Open()
$cmd = $conn.CreateCommand()
$dt = New-Object System.Data.DataTable
$dbnull = [System.DBNull]::Value

$query = "SELECT * FROM LiveData;"
$cmd.CommandText = $query
$rdr = $cmd.ExecuteReader()
$dt.Clear() 
$dt.Load($rdr)
$liveDataRef = getPackedDT($dt)

#if(!(history table exist)){
  #buildTable($liveDataRef)
#}

buildObjects($liveDataRef)
$placeHoldersRemoved = $false

while($true){
  Write-Host -f DarkYellow "Starting..."
  
  $query = "SELECT * FROM LiveData;"
  $cmd.CommandText = $query
  $rdr = $cmd.ExecuteReader()
  $dt.Clear() 
  $dt.Load($rdr)
  $liveData = getPackedDT($dt)

  forEach($liveRow in $liveData){
    $changeType = ""
    forEach($liveCol in $liveRow.PSObject.Properties.Name){
      #$Global:liveDataObj.CellSite = $liveRow.CellSite
      $Global:liveDataObj.($liveRow.CellSite).ChangeTime = $liveRow.LastUpdated
      if($liveCol -ne "CellSite" -and $liveCol -ne "IP" -and $liveCol -ne "Uptime" -and $liveCol -ne "LastUpdated"){
        #$Global:liveDataObj.($liveCol) = $liveRow.$liveCol
        if($Global:liveDataObj.($($liveRow.CellSite)).($liveCol) -ne $liveRow.$liveCol){ 
        #if($Global:sbs.($($liveRow.CellSite)).($liveCol) -ne $liveRow.$liveCol){       
          $changeType += ",$liveCol"
          $Global:liveDataObj.($($liveRow.CellSite)).($liveCol) = $liveRow.$liveCol
        }
      }
    }
    
    if($changeType -ne ""){
      $changeType = $changeType.Substring(1)

      $query = "INSERT INTO HistoricalData2 (CellSite,Temp,Humid,Door,Battery,Propane,Generator,Ping,ChangeType,ChangeTime) VALUES ('$($liveRow.CellSite)','$($Global:liveDataObj.($liveRow.CellSite).Temp)','$($Global:liveDataObj.($liveRow.CellSite).Humid)','$($Global:liveDataObj.($liveRow.CellSite).Door)','$($Global:liveDataObj.($liveRow.CellSite).Battery)','$($Global:liveDataObj.($liveRow.CellSite).Propane)','$($Global:liveDataObj.($liveRow.CellSite).Generator)','$($Global:liveDataObj.($liveRow.CellSite).Ping)','$changeType','$($Global:liveDataObj.($liveRow.CellSite).ChangeTime)');"
      $cmd.CommandText = $query
      $execute = $cmd.ExecuteNonQuery()
      
      
      if(!($placeHoldersRemoved)){
        $query = "DELETE * FROM HistoricalData2 WHERE [ChangeTime] LIKE '_NP';"
        $cmd.CommandText = $query
        $execute = $cmd.ExecuteNonQuery()
        $placeHoldersRemoved = $true
      }
      
    }
    
  }
  
  $inter = 30
  Write-Host -f DarkYellow "Complete. Waiting $inter Seconds..."
  $inter..1 | % {
    $i = $_
    Start-Sleep -Seconds 1
  }
}

$site = "14"
$type = "door"
$histLen = 7
$query = "SELECT TOP $histLen * FROM HistoricalData2 WHERE ([ID] NOT IN (SELECT [ID] FROM (SELECT TOP 1 * FROM HistoricalData2 WHERE [ChangeType] LIKE '%$type`%' AND [CellSite] LIKE '$site' ORDER BY [ID] DESC) as tbl1) AND [ChangeType] LIKE '%$type`%' AND [CellSite] LIKE '$site') ORDER BY [ID] DESC;"
$cmd.CommandText = $query
$rdr = $cmd.ExecuteReader()
$dt.Clear() 
$dt.Load($rdr)
$test = getPackedDT($dt) | Select ID,CellSite,$type
getPackedDT($dt) | Select ID,CellSite,$type
# SIG # Begin signature block
# MIIHuwYJKoZIhvcNAQcCoIIHrDCCB6gCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU0MRvfjfP9x96nJ5nYI/CpFPn
# 09+gggUrMIIFJzCCBM2gAwIBAgIKZ5YFbgAAAABWmjAKBggqhkjOPQQDAjBLMRUw
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
# DQEJBDEWBBS7iuNfWia/tGnGBvAvf02y+hzBwTANBgkqhkiG9w0BAQEFAASCAQBR
# rWYjfEtb7/NV6xPFXcQqGzgSItWl32Pam1dAj82RuFY2iMnvUH4VU6xj1T+l1jXc
# CHfZ8JnLRLlgrAOA2+CSmCZoh/TDuObJZaXOzqoAepp12mldSJ9BcGpESRUoNJne
# jZAYnI2+pbS97twE3Pne2qG3xuxVvp9XXt1/iIazy/ZA8qRiDpSD+17SOCTw+OCc
# NRDRj7Uax7697aGyztY+wpUCUAPEagAIv2f+8AQize8U9mShBGF2yIJWZjEazYht
# sdK0LkwTW720PwcuBEKOcC5gIoJbAZnHLH+B3aoWbGGZcaQLC2+0BsmCpHbI+/OQ
# 38q+AB9vDGhrNlSUSHI9
# SIG # End signature block
