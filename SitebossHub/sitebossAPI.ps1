Write-Host -f Cyan "Siteboss Hub API"

$PID | Set-Content C:\Automation\AutoServerMonitor\sitebossAPI--PID.txt -Force
$host.UI.RawUI.WindowTitle = "sitebossAPI"

#$conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=\\fileshare01\home\dpoe\sitebossScripts\sitebossData.accdb;Persist Security Info=False;Mode=ReadWrite")
#$conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=C:\OfflineSitebossHub\sitebossData.accdb;Persist Security Info=False;Mode=ReadWrite")
#$conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=C:\OfflineSitebossHub\sitebossData_basics.accdb;Persist Security Info=False;Mode=ReadWrite")
#$conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=C:\Users\ctiaadmin\Desktop\Temp_SitebossHub\sitebossData_basics.accdb;Persist Security Info=False;Mode=ReadWrite")
#$conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.Jet.OLEDB.4.0;Data Source=C:\Users\ctiaadmin\Desktop\Temp_SitebossHub\sitebossData_basics.mdb;Persist Security Info=False;Mode=ReadWrite")
$conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=C:\Automation\SitebossHub\sitebossData_basics.accdb;Persist Security Info=False;Mode=ReadWrite")
$conn.Open()
$cmd = $conn.CreateCommand()
$dt = New-Object System.Data.DataTable
$dbnull = [System.DBNull]::Value
$snmp = New-Object -ComObject olePrn.oleSNMP

$listener = New-Object System.Net.HttpListener
#$apiPort = Get-Content \\fileshare01\home\dpoe\sitebossScripts\apiPort.txt
#$apiPort = Get-Content C:\OfflineSitebossHub\apiPort.txt
$apiPort = 9747
#$hostName = "$env:COMPUTERNAME.ctcis.local"
$hostName = "$env:COMPUTERNAME.is-u.jrtc.army.mil"
$listener.Prefixes.Add("https://$hostName`:$apiPort/")
#$listener.Prefixes.Add("http://127.0.0.1`:$apiPort/")
#$listener.Prefixes.Add("http://s-sw-01:9747/")
$listener.Start()
$enc = [System.Text.Encoding]::ASCII

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

function getPackedDT($datTab){
  if($datTab -ne $null){
    $allCol = $datTab[0].Columns.ColumnName
    $selCol = @()
    forEach($col in $allCol){
      if(($datTab[0].$col)[0] -ne $dbnull){
        $selCol += $col
      }
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

$query = "SELECT * FROM SitebossData;"
$cmd.CommandText = $query
$rdr = $cmd.ExecuteReader()
$dt.Clear() 
$dt.Load($rdr)
$snmpData = getPackedDT($dt)

do{
  #$apiKey = Get-Content \\fileshare01\home\dpoe\sitebossScripts\apiKey.txt
  #$apiKey = Get-Content C:\OfflineSitebossHub\apiKey.txt
  $apiKey = "B3kd9a3radf3"
  $context = $listener.GetContext()
  $requester = $context.Request.RemoteEndPoint
  $request = $context.Request.RawUrl
  #Write-Host -f Yellow "$requester -- $request -- $((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt"))"
  "SBH__API  $((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: $requester -- $request" | Add-Content -Force -Path c:\Automation\SitebossHub\sbh_web_log.txt
  $request = $request.Substring(1,$request.Length-1)
  $request = $request.split("/")
  if($request[0] -eq $apiKey){
    
    switch($request[1]){
      "all" {
        $query = "SELECT * FROM LiveData;"
        $cmd.CommandText = $query
        $rdr = $cmd.ExecuteReader()
        $dt.Clear() 
        $dt.Load($rdr) 
        $byteMess = $enc.GetBytes((getPackedDT($dt) | ConvertTo-JSON))
        $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        break
      }

      "hist" {
        $get = $request[2].Split(",")
        $query = "SELECT [$($get[1])1],[$($get[1])2],[$($get[1])3],[$($get[1])4],[$($get[1])5],[$($get[1])6],[$($get[1])7] FROM HistoricalData WHERE [CellSite] LIKE '$($get[0])';"
        #$query = "SELECT TOP 7 * FROM HistoricalData2 WHERE ([ID] NOT IN (SELECT [ID] FROM (SELECT TOP 1 * FROM HistoricalData2 WHERE [ChangeType] LIKE '%$($get[1])%' AND [CellSite] LIKE '$($get[0])' AND [ChangeTime] > Date() ORDER BY [ID] DESC) as tbl1) AND [ChangeType] LIKE '%$($get[1])%' AND [CellSite] LIKE '$($get[0])' AND [ChangeTime] > Date()) ORDER BY [ID] ASC;"
        $cmd.CommandText = $query
        $rdr = $cmd.ExecuteReader()
        $dt.Clear() 
        $dt.Load($rdr) 
        #$byteMess = $enc.GetBytes((getPackedDT($dt) | ConvertTo-JSON))
        $mess = $null
        #$mess = (getPackedDT($dt) | Select $get[1],ChangeTime | ConvertTo-JSON)
        $mess = (getPackedDT($dt) | ConvertTo-JSON)
        if($mess -ne $null){
          $byteMess = $enc.GetBytes($mess)
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        }
        break
      }

      "hist2" {
        $get = $request[2].Split(",")
        $site = $get[0]
        $type = $get[1]
        $time = "$($get[2]) $($get[3])"
        $histLen = $get[4]
        $query = "SELECT TOP $histLen * FROM HistoricalData2 WHERE ([ID] NOT IN (SELECT [ID] FROM (SELECT TOP 1 * FROM HistoricalData2 WHERE [ChangeType] LIKE '%$type`%' AND [CellSite] LIKE '$site' AND [ChangeTime] <= #$time# ORDER BY [ID] DESC) as tbl1) AND [ChangeType] LIKE '%$type`%' AND [CellSite] LIKE '$site' AND [ChangeTime] <= #$time#) ORDER BY [ID] DESC;"
        $cmd.CommandText = $query
        $rdr = $cmd.ExecuteReader()
        $dt.Clear() 
        $dt.Load($rdr)
        $byteMess = $enc.GetBytes(((getPackedDT($dt) | Select CellSite,$type,ChangeTime) | ConvertTo-JSON))
        $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        break        
      }

      "histAll" {
        $query = "SELECT * FROM HistoricalData;"
        $cmd.CommandText = $query
        $rdr = $cmd.ExecuteReader()
        $dt.Clear() 
        $dt.Load($rdr) 
        $byteMess = $enc.GetBytes((getPackedDT($dt) | ConvertTo-JSON))
        $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        break
      }

      "report" {
        $statusReq = $null
        $status = $null
        $statusReq = Invoke-WebRequest -Uri "http://127.0.0.1:9749/status" -Method Get
        $status = $enc.GetString($statusReq.Content)
        if($status -eq "online"){
          $reportReq = Invoke-WebRequest -Uri "http://127.0.0.1:9749/report" -Method Get
          $context.Response.OutputStream.Write($reportReq.Content,0,$reportReq.Content.Length)
        }
        else{
          $byteMess = $enc.GetBytes("offline")
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        }
        break
      }

      "sysGet" {
        $byteMess = $enc.GetBytes((Import-Csv C:\Automation\SitebossHub\activeSyslog.csv | Select -First ($request[2]) | ConvertTo-JSON))
        $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        break
      }

      "proGet" {
        $query = "SELECT [Propane] FROM LiveData WHERE [CellSite] LIKE '$($request[2])';"
        $cmd.CommandText = $query
        $rdr = $cmd.ExecuteReader()
        $dt.Clear() 
        $dt.Load($rdr) 
        $byteMess = $enc.GetBytes((getPackedDT($dt) | ConvertTo-JSON))
        $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        break
      }

      "genStatGet" {
        $query = "SELECT [Generator] FROM LiveData WHERE [CellSite] LIKE '$($request[2])';"
        $cmd.CommandText = $query
        $rdr = $cmd.ExecuteReader()
        $dt.Clear() 
        $dt.Load($rdr) 
        $byteMess = $enc.GetBytes((getPackedDT($dt) | ConvertTo-JSON))
        $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        break
      }

      "genRunsGet"{
        $genRuns = Import-Csv C:\Automation\SitebossHub\LatestGeneratorRuns.csv
        if($genRuns -ne $null){
          $byteMess = $enc.GetBytes("$(($genRuns | ConvertTo-Json))<~~~~~>$(Get-Content C:\Automation\SitebossHub\GenRunDataDate.txt)")
        }
        else{
          $byteMess = $enc.GetBytes("ND")
        }
        $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        break
      }

      "pollSite"{
        $query = "SELECT * FROM Sensors_$($request[2]);"
        $cmd.CommandText = $query
        $rdr = $cmd.ExecuteReader()
        $dt.Clear() 
        $dt.Load($rdr) 
        $sensors = getPackedDT($dt)
        if($request[2] -notlike "*MAN*"){
          $snmp.Open(($snmpData | ? {$_.CellSite -eq $request[2]}).IP, "sitebossRead",2,1000)
        }
        else{
          $snmp.Open(($snmpData | ? {$_.CellSite -eq $request[2]}).IP, "CTCIS",2,1000)
        }
        forEach($sensor in $sensors){
          $poll = $snmp.Get(".1.3.6.1.4.1.3052.10.1.1.1.1.10.1.2.$($sensor.OID.Split(".")[16])")
          if($poll -eq ""){
            $poll = $snmp.Get(".1.3.6.1.4.1.3052.10.1.1.1.1.7.1.2.$($sensor.OID.Split(".")[16])")
          }
          $query = "UPDATE Sensors_$($request[2]) SET [PollValue]='$poll',[LastPoll]='$((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt"))' WHERE [SensorName] LIKE '$($sensor.SensorName)';"
          $cmd.CommandText = $query
          $execute = $cmd.ExecuteNonQuery()
        }
        $query = "SELECT * FROM Sensors_$($request[2]);"
        $cmd.CommandText = $query
        $rdr = $cmd.ExecuteReader()
        $dt.Clear() 
        $dt.Load($rdr) 
        $sensors = getPackedDT($dt)
        $byteMess = $enc.GetBytes((($sensors | Select SensorName,PollValue,LastPoll) | ConvertTo-JSON))
        $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        break
      }
    
      default{
        $context.Response.StatusCode = 404
      }
    }
    $context.Response.Close()
  }
  elseIf($request[0] -eq "favicon.ico"){
    $content = Get-Content -Encoding Byte -Path C:\Automation\SitebossHub\favicon.ico
    #$content = [Convert]::ToBase64String($content)
    $context.Response.OutputStream.Write($content,0,$content.Length)
  }
  elseIf($request[0] -eq "rd"){
    if($hopping){
      $url = $context.Request.RawUrl.Replace("_*_","#")
      $url = $hopHost + $url.Substring($url.IndexOf("/",1))
      #Write-Host $url
    }
    else{
      $url = $context.Request.RawUrl.Replace("_*_","#")
      $url = ($url.Split("?*"))[2]
      $hopHost = $url
    }
    $hopRequester = $context.Request.RemoteEndPoint.Address.IPAddressToString
    #Write-Host -f Cyan $url
    $hop = Invoke-WebRequest -Uri $url
    $byteMess = $hop.RawContentStream.ToArray()
    $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
    $hopping = $true
  }
  elseIf($request[0] -eq "sh"){
    $hopping = $false;
  }
  elseIf($hopping){
    if($hopRequester -eq $context.Request.RemoteEndPoint.Address.IPAddressToString){
      $url = $hopHost + $context.Request.RawUrl
      #Write-Host -f Cyan "HopFollow: $url"
      $hop = Invoke-WebRequest -Uri $url
      $byteMess = $hop.RawContentStream.ToArray()
      $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
    }
  }
  elseIf($request[0] -eq "SitebossHub"){
    #$content = Get-Content -Encoding Byte -Path \\fileshare01\home\dpoe\sitebossScripts\dataOverviewPage.html
    #$content = Get-Content -Encoding Byte -Path C:\OfflineSitebossHub\dataOverviewPage.html
    #$content = Get-Content -Encoding Byte -Path C:\Users\ctiaadmin\Desktop\Temp_SitebossHub\dataOverviewPage.html
    $content = Get-Content -Encoding Byte -Path C:\Automation\SitebossHub\dataOverviewPage.html
    $context.Response.OutputStream.Write($content,0,$content.Length)
  }
  elseIf($request[0] -eq "EP_SitebossHub"){
    $content = Get-Content -Encoding Byte -Path C:\Automation\SitebossHub\ep_dataOverviewPage.html
    $context.Response.OutputStream.Write($content,0,$content.Length)
  }
  elseIf($request[0] -eq "SitebossHistory"){
    $content = Get-Content -Encoding Byte -Path C:\Automation\SitebossHub\historyViewPage.html
    $context.Response.OutputStream.Write($content,0,$content.Length)
  }
  elseIf($request[0] -eq "debugPage"){
    $content = Get-Content -Encoding Byte -Path C:\Automation\SitebossHub\debugPage.html
    $context.Response.OutputStream.Write($content,0,$content.Length)
  }
  <#
  elseIf($request[0] -eq "configureTestSite"){
    #$content = Get-Content -Encoding Byte -Path \\fileshare01\home\dpoe\sitebossScripts\configureTestPage.html
    $content = Get-Content -Encoding Byte -Path C:\OfflineSitebossHub\configureTestPage.html
    $context.Response.OutputStream.Write($content,0,$content.Length)
  }
  #>
  $context.Response.Close()
  Start-Sleep -Milliseconds 500
}
while($true)
# SIG # Begin signature block
# MIIKjgYJKoZIhvcNAQcCoIIKfzCCCnsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUha39hUZ2Bym9buC0hEIiWgxt
# g4ygggfQMIIHzDCCBbSgAwIBAgITHwAACoAM7RE2PVdFewAAAAAKgDANBgkqhkiG
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
# SIb3DQEJBDEWBBTDy1S/in1LCBdMBg/SAmHFGdeVmDANBgkqhkiG9w0BAQEFAASC
# AQCDyTxaVAGXHoQh1dj3sarEt0/5EEujDm9uRLAReLZ7cH1qOkI6DOI7j3E4q+lP
# eTH5B4YeyENaw9LWVM0KV7pOyEzDArV9O9sttQE1N3JUzGMyg1BJbB4UIjarAOTr
# iy8GNe+pvVJUA7ievXhYDU4J/2Xqe0TZ/uKsh/RGYucy2HnKVJqZttNWsYY/KmN0
# l5Opg5nUKHnCy1lH58AqMrKmggcgkHMnrTfw6RMgyY7Is+ZLNGlGfbElWfSvfdA+
# gowE22ui+w92RYoyC8U0AHARf9jb7dW9aSpHeXuxWANUPW1glubO/F35TweIeVZx
# N300P1IW/k4QMkO37Lic+L/q
# SIG # End signature block
