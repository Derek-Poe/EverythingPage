Write-Host -f Cyan "IPU OTA Data Builder"

$PID | Set-Content C:\Automation\AutoServerMonitor\IPUOTADataBuilder_multiInstance--PID.txt -Force

$listener = New-Object System.Net.HttpListener
$apiPort = 1482
$hostName = "127.0.0.1"
$listener.Prefixes.Add("http://$hostName`:$apiPort/")
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

$checkLength = {
  Param($in)
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

$main = {
  Param($con,$enc,$currentRS,$checkLength,$enableWebRequests,$recordSize,$startPos,$recordChunk,$recordChunks,$instType)
  #"::$currentRS:: Started" | Add-Content C:\Automation\IPU\otaDataBuilderDebug.txt -Force
  if($instType -eq "run"){
    #"::$currentRS:: Entered run sequence" | Add-Content C:\Automation\IPU\otaDataBuilderDebug.txt -Force
    ([ScriptBlock]::Create($enableWebRequests)).Invoke()
    Try{
      $time = ((Get-Date).ToUniversalTime()).ToString("yyyy-MM-ddhh:mm:ss")
      $time = $time.Insert(10,"T")
      $time = $time.Insert($time.Length,".000Z")
      $instrData = $instrData = Invoke-WebRequest -UseBasicParsing -Uri "http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation" -Method "POST" -Headers @{"Pragma"="no-cache"; "Sec-Fetch-Site"="same-origin"; "Origin"="http://10.224.218.12"; "Accept-Encoding"="gzip, deflate, br"; "Accept-Language"="en-US,en;q=0.9"; "User-Agent"="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36"; "Sec-Fetch-Mode"="cors"; "Accept"="application/json, text/plain, */*"; "Cache-Control"="no-cache"; "Referer"="http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation";} -ContentType "application/json" -Body "{`"queryName`":`"QueryAllInstrumentation`",`"header`":{`"id`":{`"uuid`":`"$((New-Guid).Guid)`",`"class`":`"ctia.data_model.HeaderId`"},`"sentTime`":`"$time`",`"actualTime`":`"$time`",`"serviceName`":`"SoaInstrumentationService`",`"userName`":`"$("TCE")`",`"host`":`"s-lctia4-102.ctcis.local`",`"class`":`"ctia.data_model.HeaderData`"},`"projections`":[`"serialNumber`",`"actualDistanceReportingRate`",`"actualTimeReportingRate`",`"ipuSoftwareVersion`"],`"startOffset`":$startPos,`"maxResults`":$recordSize,`"class`":`"ctia.data_model.NamedQueryRequest`"}"
      $instrData = ($instrData.Content | ConvertFrom-Json).payload.instrumentationList
      $instrData = $instrData  | Select * -ExcludeProperty class
     #$instrData | Export-Clixml "C:\Automation\IPU\temp\OTAtempRecordChunk_$recordChunk`_all.txt" -Force          
      $ICIPU = Import-Csv C:\Automation\IPU\temp\inCommsIPUs.csv
      $instrData = $instrData | ? {$_.serialNumber -in $ICIPU.ICIPU}
      forEach($ipu in $instrData){
        $ipu.actualTimeReportingRate = $ipu.actualTimeReportingRate -as [int]; 
        $ipu.actualDistanceReportingRate = $ipu.actualDistanceReportingRate -as [int]
      }
      $instrData | Export-Csv "C:\Automation\IPU\temp\OTAtempRecordChunk_$recordChunk.csv" -Force -NoTypeInformation
    }
    Catch{
      "CTIA PROBLEM!" | Set-Content "C:\Automation\IPU\temp\OTAtempRecordChunk_$recordChunk.csv"
    }
    $contFiles = (Get-ChildItem C:\Automation\IPU\temp | ? {$_.Name -like "OTAtempRecordChunk_*.csv"})
    if($contFiles.Length -ge $recordChunks -and $contFiles -is [Array]){
      "::$currentRS:: Chunk -- $recordChunk; Chunks -- $recordChunks; Length -- $((Invoke-Command -ScriptBlock $checkLength -ArgumentList ((Get-ChildItem C:\Automation\IPU\temp | ? {$_.Name -like "OTAtempRecordChunk_*.csv"}).Length)))" | Add-Content C:\Automation\IPU\otaDataBuilderDebug.txt -Force
      $in = Invoke-WebRequest http://127.0.0.1:1482/jh23bk54jhb23/e
    }
  }
  elseIf($instType -eq "end"){
    $allCont = "`"serialNumber`",`"actualDistanceReportingRate`",`"actualTimeReportingRate`",`"ipuSoftwareVersion`"`n"
    forEach($chunk in (Get-ChildItem C:\Automation\IPU\temp | ? {$_.Name -like "OTAtempRecordChunk_*.csv" | Sort Name}).FullName){
      $allCont += Get-Content $chunk -Delimiter `n | Select -Skip 1
    }
    $allCont | Set-Content C:\Automation\IPU\instrData.csv -Force
    (Import-Csv C:\Automation\IPU\instrData.csv).Length | Set-Content C:\Automation\IPU\instrDataLength.txt -Force
    (Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt") | Set-Content C:\Automation\IPU\instrDataDate.txt -Force
    #"FinishTriggerStart" | Add-Content C:\Automation\IPU\otaDataBuilderDebug2.txt -Force
    $in = Invoke-WebRequest http://127.0.0.1:1482/jh23bk54jhb23/f
    #"FinishTriggerEnd" | Add-Content C:\Automation\IPU\otaDataBuilderDebug2.txt -Force
  }
  exit
  #$con.Response.Close()
}

#$maxRun = Read-Host "Runspaces"
$maxRun = 100
$maxRun = [int]$maxRun
$runspace = [RunSpaceFactory]::CreateRunspacePool(1,$maxRun)
$runspace.Open()
$psInst = New-Object -TypeName PSCustomObject
$props = "1=$null"
$availProps = "1=$true"
2..$maxRun | % {
  $props += "`n$_=$null"
  $availProps += "`n$_=$true"
}
forEach($prop in @("Inst","Stat","Res")){
  $psInst | Add-Member -MemberType NoteProperty -Name $prop -Value ($props | ConvertFrom-StringData)
}
$context = New-Object -TypeName PSCustomObject -Property @{CurrentCon=0}
$context | Add-Member -MemberType NoteProperty -Name "ConAvail" -Value ($availProps | ConvertFrom-StringData)
$context | Add-Member -MemberType NoteProperty -Name "Con" -Value ($props | ConvertFrom-StringData)
function assignContext($conTemp){
  $maxCap = $true
  for($i = 1; $i -le $maxRun; $i++){
    if($context.ConAvail.([String]$i)){
      $context.CurrentCon = $i
      $maxCap = $false
      break
    }
  }
  if($maxCap){
    $context.CurrentCon = 0
    $cleanData = cleanup -context $context -psInst $psInst
    $context = $cleanData.context
    $psInst = $cleanData.psInst
    Start-Sleep -Milliseconds 500
    assignContext
  }
  else{
    $context.ConAvail.([String]$context.CurrentCon) = $false
    $context.Con.($context.CurrentCon -as [String]) = $conTemp
  }
}
function startRunspace($runspace,$enc,$recordSize,$startPos,$recordChunk,$recordChunks,$instType){
  $psInst.Inst.([String]$context.CurrentCon) = [PowerShell]::Create()
  $psInst.Inst.([String]$context.CurrentCon).RunspacePool = $runspace
  $null = $psInst.Inst.([String]$context.CurrentCon).AddScript($main).`
          AddArgument($context.Con.([String]$context.CurrentCon)).AddArgument($enc).`
          AddArgument([String]$context.CurrentCon).AddArgument($checkLength).AddArgument($enableWebRequests).`
          AddArgument($recordSize).AddArgument($startPos).AddArgument($recordChunk).AddArgument($recordChunks).AddArgument($instType)
  $psInst.Stat.([String]$context.CurrentCon) = $psInst.Inst.([String]$context.CurrentCon).BeginInvoke()
}
function cleanup($context,$psInst){
  #Write-Host "Start Cleanup"
  1..$maxRun | % {
    $i = $_
    #Write-Host -f DarkYellow $i
    if(!($context.ConAvail.([String]$i))){
      #Write-Host -f Yellow $i
      if($psInst.Stat.([String]$i).IsCompleted){
        #Write-Host -f Magenta $i
        #Write-Host -f Magenta "Set Res"
        #break
        #$psInst.Res.([String]$context.CurrentCon) = $psInst.Inst.([String]$context.CurrentCon).EndInvoke($psInst.Stat.([String]$context.CurrentCon))
        #Write-Host -f Magenta "Set ConAvail"
        $context.ConAvail.([String]$i) = $true
      }
    }
  }
  return New-Object -TypeName PSCustomObject -Property @{context=$context;psInst=$psInst}
}

$runningCollect = $false
$recordSize = 300
$cleanCycle = 0
do{
  $conTemp = $listener.GetContext()
  "Got Context -- $($conTemp.Request.RawUrl)" | Add-Content C:\Automation\IPU\otaDataBuilderDebug.txt -Force
  if(($conTemp.Request.RawUrl).Split("/")[1] -eq "jh23bk54jhb23"){
    if(($conTemp.Request.RawUrl).Split("/")[2] -eq "s" -and $runningCollect -eq $false){
      #"Starting Instance Split" | Add-Content C:\Automation\IPU\otaDataBuilderDebug.txt -Force
      $startTime = (Get-Date)
      Write-Host "StartTime: $($startTime.ToString(`"MM/dd/yyyy hh:mm:ss tt"))" -NoNewline
      $startCon = $conTemp
      $runningCollect = $true
      Get-ChildItem C:\Automation\IPU\temp\ | ? {$_.Name -like "OTAtempRecordChunk_*"} | Remove-Item -Force
      Get-ChildItem C:\Automation\IPU\temp\ | ? {$_.Name -eq "inCommsIPUs.csv"} | Remove-Item -Force
      Copy-Item C:\Automation\IPU\inCommsIPUs.csv -Destination C:\Automation\IPU\temp\ -Force
      $time = ((Get-Date).ToUniversalTime()).ToString("yyyy-MM-ddhh:mm:ss")
      $time = $time.Insert(10,"T")
      $time = $time.Insert($time.Length,".000Z")
      $instrDataSample = Invoke-WebRequest -UseBasicParsing -Uri "http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation" -Method "POST" -Headers @{"Pragma"="no-cache"; "Sec-Fetch-Site"="same-origin"; "Origin"="http://10.224.218.12"; "Accept-Encoding"="gzip, deflate, br"; "Accept-Language"="en-US,en;q=0.9"; "User-Agent"="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36"; "Sec-Fetch-Mode"="cors"; "Accept"="application/json, text/plain, */*"; "Cache-Control"="no-cache"; "Referer"="http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation";} -ContentType "application/json" -Body "{`"queryName`":`"QueryAllInstrumentation`",`"header`":{`"id`":{`"uuid`":`"$((New-Guid).Guid)`",`"class`":`"ctia.data_model.HeaderId`"},`"sentTime`":`"$time`",`"actualTime`":`"$time`",`"serviceName`":`"SoaInstrumentationService`",`"userName`":`"$("TCE")`",`"host`":`"s-lctia4-102.ctcis.local`",`"class`":`"ctia.data_model.HeaderData`"},`"maxResults`":1,`"projections`":[`"serialNumber`"],`"class`":`"ctia.data_model.NamedQueryRequest`"}" -ErrorVariable webError
      $instrDataRecordCount = ($instrDataSample.Content | ConvertFrom-Json).payload.totalCount
      "Record Count: $instrDataRecordCount  --- Error: $webError -- Error2: $($Error[0])" | Add-Content C:\Automation\IPU\otaDataBuilderDebug.txt -Force
      $recordChunks = [Math]::Ceiling(($instrDataRecordCount / $recordSize))
      $startPos = 0
      $recordChunk = 0
      for($i = 0; $i -lt $recordChunks; $i++){
        #"Starting Runspace" | Add-Content C:\Automation\IPU\otaDataBuilderDebug.txt -Force
        assignContext #-conTemp $conTemp
        startRunspace -runspace $runspace -enc $enc -instType "run" -recordSize $recordSize -startPos $startPos -recordChunk $recordChunk -recordChunks $recordChunks
        $startPos += $recordSize
        $recordChunk++
      }
    }
    elseIf(($conTemp.Request.RawUrl).Split("/")[2] -eq "e"){
      assignContext -conTemp $conTemp
      startRunspace -runspace $runspace -enc $enc -instType "end" 
    }
    elseIf(($conTemp.Request.RawUrl).Split("/")[2] -eq "f"){
      "Finish" | Add-Content C:\Automation\IPU\otaDataBuilderDebug2.txt -Force
      $startCon.Response.Close()
      $runningCollect = $false
      Write-Host " -- InComms: $(Get-Content C:\Automation\IPU\instrDataLength.txt) -- ExecTime: $((New-TimeSpan -Start $startTime -End (Get-Date)).ToString())"
    }
    elseIf(($conTemp.Request.RawUrl).Split("/")[2] -eq "s" -and $runningCollect){
      $byteMess = $enc.GetBytes("Busy")
      $conTemp.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
      $conTemp.Response.Close()
    }
    else{
      $byteMess = $enc.GetBytes("Error")
      $conTemp.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
      $conTemp.Response.Close()
    }

    if($cleanCycle -ge 2){
      $cleanCycle = 0
      $cleanData = cleanup -context $context -psInst $psInst
      $context = $cleanData.context
      $psInst = $cleanData.psInst
    }
    $cleanCycle++
  }
}
while($true)

# SIG # Begin signature block
# MIIHuwYJKoZIhvcNAQcCoIIHrDCCB6gCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU6MiBhTVUvJcpkiw+/BtDIBvs
# q4ygggUrMIIFJzCCBM2gAwIBAgIKZ5YFbgAAAABWmjAKBggqhkjOPQQDAjBLMRUw
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
# DQEJBDEWBBTvv1sLZ5PQBtfNmgpPxvIHMOckFDANBgkqhkiG9w0BAQEFAASCAQAE
# z+iTJw4A0x/uYSKN6BAZNL6YB09Y8ByzVXhKE10E1CNHOlVuh8fo1talBasu1q3K
# zIvAG8r5U+3zvfzsI4cmz07EnoinOPlYoTqv93PC6rv8B63+UT5c2Dpg15zzlhU8
# GMi02fDvUiSOwWpC6JTA0spxSg/PS9KIxQn5dBoV08svKjQ59i4QXwqELN5LbQ0K
# Ur1bq5SMw9I/+zxqm0XyhdJCuO0tMGDGrY+O8TcfqIsLt7WNdpZfAxVrVqgx9ZZs
# 7ouRMjBH7S3M7u+yAMoJDgtGH59Wz+QCisaeVOtpajPhDu3TO4D6h/tmiA2QiywK
# 1zBuRkcCRbbCBqnNmL4L
# SIG # End signature block
