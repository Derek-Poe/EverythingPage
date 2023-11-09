Write-Host -f Cyan "Siteboss Poller"

$PID | Set-Content C:\Automation\AutoServerMonitor\sitebossPoller--PID.txt -Force
$host.UI.RawUI.WindowTitle = "sitebossPoller"

#$conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=\\fileshare01\home\dpoe\sitebossScripts\sitebossData.accdb;Persist Security Info=False;Mode=ReadWrite")
#$conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=C:\OfflineSitebossHub\sitebossData_basics.accdb;Persist Security Info=False;Mode=ReadWrite")
#$conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=C:\Users\ctiaadmin\Desktop\Temp_SitebossHub\sitebossData_basics.accdb;Persist Security Info=False;Mode=ReadWrite")
#$conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.Jet.OLEDB.4.0;Data Source=C:\Users\ctiaadmin\Desktop\Temp_SitebossHub\sitebossData_basics.mdb;Persist Security Info=False;Mode=ReadWrite")
$conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=C:\Automation\SitebossHub\sitebossData_basics.accdb;Persist Security Info=False;Mode=ReadWrite")
$conn.Open()
$cmd = $conn.CreateCommand()
$dt = New-Object System.Data.DataTable
$dbnull = [System.DBNull]::Value
$snmp = New-Object -ComObject olePrn.oleSNMP

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

$enableWebRequests = {
  function Set-UseUnsafeHeaderParsing(){
    param(
      [Parameter(Mandatory,ParameterSetName="Enable")]
      [switch]$Enable,
      [Parameter(Mandatory,ParameterSetName="Disable")]
      [switch]$Disable
    )
    $shouldEnable = $PSCmdlet.ParameterSetName -eq "Enable"
    $netAssembly = [Reflection.Assembly]::GetAssembly([System.Net.Configuration.SettingsSection])
    if($netAssembly){
      $bindingFlags = [Reflection.BindingFlags]"Static,GetProperty,NonPublic"
      $settingsType = $netAssembly.GetType("System.Net.Configuration.SettingsSectionInternal")
      $instance = $settingsType.InvokeMember("Section", $bindingFlags, $null, $null, @())   
      if($instance){
        $bindingFlags = "NonPublic","Instance"
        $useUnsafeHeaderParsingField = $settingsType.GetField("useUnsafeHeaderParsing", $bindingFlags)
        if($useUnsafeHeaderParsingField){
          $useUnsafeHeaderParsingField.SetValue($instance,$shouldEnable)
        }
      }
    }
  }
  Set-UseUnsafeHeaderParsing -Enable

  function Ignore-SSLCertificates{
      $Provider = New-Object Microsoft.CSharp.CSharpCodeProvider
      $Compiler = $Provider.CreateCompiler()
      $Params = New-Object System.CodeDom.Compiler.CompilerParameters
      $Params.GenerateExecutable = $false
      $Params.GenerateInMemory = $true
      $Params.IncludeDebugInformation = $false
      $Params.ReferencedAssemblies.Add("System.DLL") > $null
      $TASource=@"
          namespace Local.ToolkitExtensions.Net.CertificatePolicy
          {
              public class TrustAll : System.Net.ICertificatePolicy
              {
                  public bool CheckValidationResult(System.Net.ServicePoint sp,System.Security.Cryptography.X509Certificates.X509Certificate cert, System.Net.WebRequest req, int problem)
                  {
                      return true;
                  }
              }
          }
"@ 
      $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
      $TAAssembly=$TAResults.CompiledAssembly
      ## We create an instance of TrustAll and attach it to the ServicePointManager
      $TrustAll = $TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
      [System.Net.ServicePointManager]::CertificatePolicy = $TrustAll
  }
  Ignore-SSLCertificates
}
([ScriptBlock]::Create($enableWebRequests)).Invoke()


$query = "DROP TABLE LiveData;"
$cmd.CommandText = $query
$execute = $cmd.ExecuteNonQuery()

$query = "SELECT * FROM SitebossData;"
$cmd.CommandText = $query
$rdr = $cmd.ExecuteReader()
$dt.Clear() 
$dt.Load($rdr)
$snmpData = getPackedDT($dt)

###
if((Get-NetAdapter | ? {$_.InterfaceDescription -like "*Cisco AnyConnect*"}).Status -eq "Up"){
  $sbip = Import-Csv -Path C:\OfflineSitebossHub\sitebosses.csv
  0..33 | % {
    $i = $_
    $snmpData[$i].IP = ($sbip.vip[$i]).Trim()
  }
}
###

$colNames = ""
1..($snmpData[0].PSObject.Properties.Name.Length - 1) | % {
  $i = $_
  $colNames += ",$($snmpData[0].PSObject.Properties.Name[$i]) varchar(255)"
}
$colNames = $colNames.Substring(1)

$query = "CREATE TABLE LiveData ($colNames);"
$cmd.CommandText = $query
$execute = $cmd.ExecuteNonQuery()

$colNames = ""
$rowFill = ""
1..($snmpData[0].PSObject.Properties.Name.Length - 1) | % {
  $i = $_
  $colNames += ",[$($snmpData[0].PSObject.Properties.Name[$i])]"
  if($i -gt 1){
    $rowFill += ",'_NP'"
  }
}
$colNames = "($($colNames.Substring(1)))"
0..($snmpData.Length-1) | % {
  $i = $_
  $query = "INSERT INTO LiveData $colNames VALUES ('$($snmpData[$i].CellSite)'$rowFill);"
  $cmd.CommandText = $query
  $execute = $cmd.ExecuteNonQuery()
}

$sbs = New-Object -TypeName PSCustomObject
$props = ""
1..($snmpData[0].PSObject.Properties.Name.Length - 1) | % {
  $i = $_
  if($snmpData[0].PSObject.Properties.Name[$i] -ne "CellSite"){
    $props += "`n$($snmpData[0].PSObject.Properties.Name[$i])=$null"
  }
}
$props = $props.Substring(1)
0..($snmpData.Length-1) | % {
  $i = $_
  $sbs | Add-Member -MemberType NoteProperty -Name $snmpData[$i].CellSite -Value $null
  $sbs.($snmpData[$i].CellSite) = ($props | ConvertFrom-StringData)
}

while(1){
  $startTime = (Get-Date)
  0..($snmpData.Length-1) | % {
    $i = $_
    $sb = $snmpData[$i]
    if($sb.CellSite -notlike "*MAN*" -or ($sb.CellSite -like "*MAN*" -and ((Get-Content C:\Automation\SitebossHub\MANPolling.txt) -eq $true))){
      if($sb.IP -ne $sbs.($sb.CellSite).IP){
        $query = "UPDATE LiveData SET [IP]='$($sb.IP)' WHERE [CellSite] LIKE '$($sb.CellSite)';"
        $cmd.CommandText = $query
        $execute = $cmd.ExecuteNonQuery()
      }
      $sbs.($sb.CellSite).IP = $sb.IP
      
      #
      #
      $ping = "Unreachable"
      $ping = ping -n 1 -w 3000 $sb.IP
      #
      #

      #if($sb.CellSite -like "*MAN*"){
      #  $snmp.Open($sb.IP, "CTCIS",2,1000)
      #}
      #else{
      #  $snmp.Open($sb.IP, "sitebossRead",2,1000)
      #}
      $startSensorPoll = $false
      if($ping -like "*reply from $($sb.IP)*"){
      #if($true){
        $startSensorPoll = $true
        if($sb.CellSite -like "*MAN*"){
            $snmp.Open($sb.IP, "CTCIS",2,1000)
          }
          else{
            $snmp.Open($sb.IP, "sitebossRead",2,1000)
          }
      }
      else{
        #$pollAttempt = $null
        #$pollAttempt = $snmp.Get(".1.3.6.1.2.1.1.3.0")
        #if($pollAttempt -ne $null){
        #  $execute = $true
        #}
        if((Invoke-WebRequest "https://$($sb.IP)" -TimeoutSec 7).StatusCode -eq 200){
        #if(){
          $startSensorPoll = $true
          if($sb.CellSite -like "*MAN*"){
            $snmp.Open($sb.IP, "CTCIS",2,1000)
          }
          else{
            $snmp.Open($sb.IP, "sitebossRead",2,1000)
          }
        }
        else{
          $startSensorPoll = $false
          #$snmp.Close()
        }
      }
      if($startSensorPoll){
        $query = "UPDATE LiveData SET [Ping]='Reachable' WHERE [CellSite] LIKE '$($sb.CellSite)';"
        $cmd.CommandText = $query
        $execute = $cmd.ExecuteNonQuery()
        #
        #Write-Host "$($sb.CellSite) $($snmp.Get(".1.3.6.1.4.1.3052.10.1.1.1.1.4.1.2.15"))"
        #Write-Host "$($sb.CellSite) $($snmp.Get(".1.3.6.1.2.1.1.3.0"))"
        #
        0..($snmpData[0].PSObject.Properties.Name.Length-4) | % {
          $ii = $_
          if($sb.PSObject.Properties.Name[$ii+3] -ne "LastUpdated" -and $sb.PSObject.Properties.Name[$ii+3] -ne "Ping"){
            $oid = $sb.($sb.PSObject.Properties.Name[$ii+3])
            if($oid -ne "_NP" -and $oid -ne $null){
              #Write-Host -f Yellow "Polling: Site $($sb.CellSite) - $($sb.PSObject.Properties.Name[$ii+3])"
              $poll = "_NP"
              $poll = $snmp.Get($oid)
              if($poll -ne $sbs.($sb.CellSite).($sb.PSObject.Properties.Name[$ii+3])){
                $query = "UPDATE LiveData SET [$($sb.PSObject.Properties.Name[$ii+3])]='$poll' WHERE [CellSite] LIKE '$($sb.CellSite)';"
                $cmd.CommandText = $query
                $execute = $cmd.ExecuteNonQuery()
              }
              $sbs.($sb.CellSite).($sb.PSObject.Properties.Name[$ii+3]) = $poll
            }
          }
        }
        $snmp.Close()
      }
      else{
        $query = "UPDATE LiveData SET [Ping]='Unreachable' WHERE [CellSite] LIKE '$($sb.CellSite)';"
        $cmd.CommandText = $query
        $execute = $cmd.ExecuteNonQuery()
      }
    }
    elseIf($sb.CellSite -like "*MAN*" -and ((Get-Content C:\Automation\SitebossHub\MANPolling.txt) -eq $false)){
      $query = "UPDATE LiveData SET [Ping]='Offline' WHERE [CellSite] LIKE '$($sb.CellSite)';"
      $cmd.CommandText = $query
      $execute = $cmd.ExecuteNonQuery()
    }
    $query = "UPDATE LiveData SET [LastUpdated]='$((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt"))' WHERE [CellSite] LIKE '$($sb.CellSite)';"
    $cmd.CommandText = $query
    $execute = $cmd.ExecuteNonQuery()
    Write-Host -f DarkYellow "Completed Site $($sb.CellSite)"
  }
  $pollInter = 30
  <#
  $pollInter..1 | % {
    $i = $_
    if($i % 10 -eq 0){
      Write-Host -f DarkYellow "Waiting... $i of $pollInter Seconds Remaining"
    }
    Start-Sleep -Seconds 1
  }
  #>
  $execTime = (New-TimeSpan -Start $startTime -End (Get-Date))
  Write-Host "All Sites Completed in $([Math]::Round($execTime.TotalMilliseconds/1000,2))sec. Waiting $($pollInter - [Math]::Round($execTime.TotalMilliseconds/1000,2))sec."
  if($execTime.TotalSeconds -lt $pollInter){
    Start-Sleep -Milliseconds (($pollInter * 1000) - [Math]::Round($execTime.TotalMilliseconds))
  }
}
# SIG # Begin signature block
# MIIKjgYJKoZIhvcNAQcCoIIKfzCCCnsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUhRn4e0vsNpseohfOmoHOMmG2
# IDygggfQMIIHzDCCBbSgAwIBAgITHwAACoAM7RE2PVdFewAAAAAKgDANBgkqhkiG
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
# SIb3DQEJBDEWBBRp5uMAE3TzB6QzEd09HAruiYL/mzANBgkqhkiG9w0BAQEFAASC
# AQAWE2K/VQAxXNQ8W1JSm8Pz7QjglX7F/O58wSJCmyeP8291viD0Uj1FpKLu5/Ii
# lfSIQ3L3s4Kpi9BfvdWCNXJ783eQIJM8c8j0aJqnS8UbRiZm+1z6ZTeZSu2vbA70
# OXDX4LT9LzuGeihJwc1Dlj0iDLNYi2yLUEV+0Mw/M19pLipgdLQaGCu4POMgyq2J
# DcPtsnOeqFOVlClGPwvVhAn3NqzXu+eoo5vlzWIgaECWqfz+e+LBPHV48kjiIR3n
# n4md6+xpdjjWfUA7JSFjnzJW8YJb/b1fi85QAHg0+lNuBdbIWf2DGbniLOwOjcSg
# F451LuXzQ62LSvhteFgGpbfn
# SIG # End signature block
