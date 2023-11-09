Write-Host -f Cyan "IPU OTA Data Builder"

Stop-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\IPUOTADataBuilder_multiInstance--PID.txt") -ErrorAction SilentlyContinue
$PID | Set-Content C:\Automation\AutoServerMonitor\IPUOTADataBuilder_multiInstance--PID.txt -Force
$host.UI.RawUI.WindowTitle = "IPUOTADataBuilder_multiInstance"

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
      #$instrData = Invoke-WebRequest -UseBasicParsing -Uri "http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation" -Method "POST" -Headers @{"Pragma"="no-cache"; "Sec-Fetch-Site"="same-origin"; "Origin"="http://10.224.218.12"; "Accept-Encoding"="gzip, deflate, br"; "Accept-Language"="en-US,en;q=0.9"; "User-Agent"="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36"; "Sec-Fetch-Mode"="cors"; "Accept"="application/json, text/plain, */*"; "Cache-Control"="no-cache"; "Referer"="http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation";} -ContentType "application/json" -Body "{`"queryName`":`"QueryAllInstrumentation`",`"header`":{`"id`":{`"uuid`":`"$((New-Guid).Guid)`",`"class`":`"ctia.data_model.HeaderId`"},`"sentTime`":`"$time`",`"actualTime`":`"$time`",`"serviceName`":`"SoaInstrumentationService`",`"userName`":`"$("TCE")`",`"host`":`"s-lctia4-102.ctcis.local`",`"class`":`"ctia.data_model.HeaderData`"},`"projections`":[`"serialNumber`",`"actualDistanceReportingRate`",`"actualTimeReportingRate`",`"ipuSoftwareVersion`",`"isOutOfComms`"],`"startOffset`":$startPos,`"maxResults`":$recordSize,`"class`":`"ctia.data_model.NamedQueryRequest`"}"
      #$instrData = Invoke-WebRequest -UseBasicParsing -Uri "http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation" -Method "POST" -Headers @{"Pragma"="no-cache"; "Sec-Fetch-Site"="same-origin"; "Origin"="http://10.224.218.12"; "Accept-Encoding"="gzip, deflate, br"; "Accept-Language"="en-US,en;q=0.9"; "User-Agent"="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36"; "Sec-Fetch-Mode"="cors"; "Accept"="application/json, text/plain, */*"; "Cache-Control"="no-cache"; "Referer"="http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation";} -ContentType "application/json" -Body "{`"queryName`":`"QueryAllInstrumentation`",`"header`":{`"id`":{`"uuid`":`"$((New-Guid).Guid)`",`"class`":`"ctia.data_model.HeaderId`"},`"sentTime`":`"$time`",`"actualTime`":`"$time`",`"serviceName`":`"SoaInstrumentationService`",`"userName`":`"$("TCE")`",`"host`":`"s-lctia4-102.ctcis.local`",`"class`":`"ctia.data_model.HeaderData`"},`"projections`":[`"serialNumber`",`"actualDistanceReportingRate`",`"actualTimeReportingRate`",`"ipuSoftwareVersion`"],`"startOffset`":$startPos,`"maxResults`":$recordSize,`"class`":`"ctia.data_model.NamedQueryRequest`"}"
      $instrData = $instrData = Invoke-WebRequest -UseBasicParsing -Uri "http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation" -Method "POST" -Headers @{"Pragma"="no-cache"; "Sec-Fetch-Site"="same-origin"; "Origin"="http://10.224.218.12"; "Accept-Encoding"="gzip, deflate, br"; "Accept-Language"="en-US,en;q=0.9"; "User-Agent"="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36"; "Sec-Fetch-Mode"="cors"; "Accept"="application/json, text/plain, */*"; "Cache-Control"="no-cache"; "Referer"="http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation";} -ContentType "application/json" -Body "{`"queryName`":`"QueryAllInstrumentation`",`"header`":{`"id`":{`"uuid`":`"$((New-Guid).Guid)`",`"class`":`"ctia.data_model.HeaderId`"},`"sentTime`":`"$time`",`"actualTime`":`"$time`",`"serviceName`":`"SoaInstrumentationService`",`"userName`":`"$("TCE")`",`"host`":`"s-lctia4-102.ctcis.local`",`"class`":`"ctia.data_model.HeaderData`"},`"projections`":[`"serialNumber`",`"actualDistanceReportingRate`",`"actualTimeReportingRate`",`"ipuSoftwareVersion`",`"isOutOfComms`"],`"startOffset`":$startPos,`"maxResults`":$recordSize,`"class`":`"ctia.data_model.NamedQueryRequest`"}"
      $instrData = ($instrData.Content | ConvertFrom-Json).payload.instrumentationList
      $instrData = $instrData  | Select * -ExcludeProperty class
     #$instrData | Export-Clixml "C:\Automation\IPU\temp\OTAtempRecordChunk_$recordChunk`_all.txt" -Force          
      "`"In`",`"Out`"`n$(($instrData | ? {!($_.isOutOfComms)}).Length),$(($instrData | ? {$_.isOutOfComms}).Length)" | Set-Content "C:\Automation\IPU\temp\commsCountChunk_$recordChunk.csv" -Force
      $ICIPU = Import-Csv C:\Automation\IPU\temp\inCommsIPUs.csv
      $instrData = $instrData | ? {$_.serialNumber -in $ICIPU.ICIPU}
      #$instrData | Export-Clixml C:\Automation\IPU\temp\test2.xml
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
    $allCont = "`"isOutOfComms`",`"serialNumber`",`"actualDistanceReportingRate`",`"actualTimeReportingRate`",`"ipuSoftwareVersion`"`n"
    forEach($chunk in (Get-ChildItem C:\Automation\IPU\temp | ? {$_.Name -like "OTAtempRecordChunk_*.csv" | Sort Name}).FullName){
      $allCont += Get-Content $chunk -Delimiter `n | Select -Skip 1
    }
    $inCount = 0
    $outCount = 0
    forEach($chunk in ((Get-ChildItem C:\Automation\IPU\temp | ? {$_.Name -like "commsCountChunk_*"})).FullName){
      $chunk = Import-Csv $chunk
      $inCount += [int]$chunk.In
      $outCount += [int]$chunk.Out
    }
    "`"In`",`"Out`"`n$inCount,$outCount" | Set-Content C:\Automation\IPU\instrCommsCount.csv -Force
    #
    #$allCont | Export-Clixml C:\Automation\IPU\temp\test.xml
    $allCont = $allCont | ConvertFrom-Csv | Select serialNumber,actualDistanceReportingRate,actualTimeReportingRate,ipuSoftwareVersion
    $allCont | Export-Csv C:\Automation\IPU\instrData.csv -Force -NoTypeInformation
    #
    #$allCont | Set-Content C:\Automation\IPU\instrData.csv -Force
    #(Invoke-Command -ScriptBlock $checkLength -ArgumentList (Import-Csv C:\Automation\IPU\instrData.csv)) | Set-Content C:\Automation\IPU\instrDataLength.txt -Force
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
      Get-ChildItem C:\Automation\IPU\temp\ | ? {$_.Name -like "commsCountChunk_*"} | Remove-Item -Force
      Get-ChildItem C:\Automation\IPU\temp\ | ? {$_.Name -eq "inCommsIPUs.csv"} | Remove-Item -Force
      Copy-Item C:\Automation\IPU\inCommsIPUs.csv -Destination C:\Automation\IPU\temp\ -Force
      $inCommsCount = (Import-Csv C:\Automation\IPU\temp\inCommsIPUs.csv).Length
      $time = ((Get-Date).ToUniversalTime()).ToString("yyyy-MM-ddhh:mm:ss")
      $time = $time.Insert(10,"T")
      $time = $time.Insert($time.Length,".000Z")
      $instrDataSample = Invoke-WebRequest -UseBasicParsing -Uri "http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation" -Method "POST" -Headers @{"Pragma"="no-cache"; "Sec-Fetch-Site"="same-origin"; "Origin"="http://10.224.218.12"; "Accept-Encoding"="gzip, deflate, br"; "Accept-Language"="en-US,en;q=0.9"; "User-Agent"="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36"; "Sec-Fetch-Mode"="cors"; "Accept"="application/json, text/plain, */*"; "Cache-Control"="no-cache"; "Referer"="http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation";} -ContentType "application/json" -Body "{`"queryName`":`"QueryAllInstrumentation`",`"header`":{`"id`":{`"uuid`":`"$((New-Guid).Guid)`",`"class`":`"ctia.data_model.HeaderId`"},`"sentTime`":`"$time`",`"actualTime`":`"$time`",`"serviceName`":`"SoaInstrumentationService`",`"userName`":`"$("TCE")`",`"host`":`"s-lctia4-102.ctcis.local`",`"class`":`"ctia.data_model.HeaderData`"},`"maxResults`":1,`"projections`":[`"serialNumber`"],`"class`":`"ctia.data_model.NamedQueryRequest`"}" -ErrorVariable webError
      $instrDataRecordCount = ($instrDataSample.Content | ConvertFrom-Json).payload.totalCount -as [int]
      "Record Count: $instrDataRecordCount  --- Error: $webError -- Error2: $($Error[0])" | Add-Content C:\Automation\IPU\otaDataBuilderDebug.txt -Force
      if($inCommsCount -ge 3000){
        $recordSize = 300
      }
      elseIf($inCommsCount -ge 2000){
        $recordSize = 750
      }
      elseIf($inCommsCount -ge 1000){
        $recordSize = 1500
      }
      elseIf($inCommsCount -ge 500){
        $recordSize = 2500
      }
      else{
        $recordSize = 5000
      }
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
      assignContext #-conTemp $conTemp
      startRunspace -runspace $runspace -enc $enc -instType "end" 
    }
    elseIf(($conTemp.Request.RawUrl).Split("/")[2] -eq "f"){
      "Finish" | Add-Content C:\Automation\IPU\otaDataBuilderDebug2.txt -Force
      $instrDataFinal = (Import-Csv C:\Automation\IPU\instrData.csv) 
      if($instrDataFinal -is [Array]){
        $instrDataFinal.Length | Set-Content C:\Automation\IPU\instrDataLength.txt -Force
      }
      elseIf($instrDataFinal -eq 0 -or $instrDataFinal -eq $null){
        0 | Set-Content C:\Automation\IPU\instrDataLength.txt -Force
      }
      else{
        1 | Set-Content C:\Automation\IPU\instrDataLength.txt -Force
      }
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
# MIIKjgYJKoZIhvcNAQcCoIIKfzCCCnsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUBxjMMR0kyuB629SfA0zi89uB
# M+WgggfQMIIHzDCCBbSgAwIBAgITHwAACoAM7RE2PVdFewAAAAAKgDANBgkqhkiG
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
# SIb3DQEJBDEWBBQLWNfXzb/u8WY5+BImsC89QAbpoTANBgkqhkiG9w0BAQEFAASC
# AQCZGgl+B90Fjwwwy0tuz+yRbonue23pLfgSqk1t+YffLl1PXl7m2JBUxsznUky6
# klajMp8NTdeI524eB25sruSTvMvOWrT8/e1GwqH/OkUglNHTKQ2UJb8//4CX5Gkr
# 94NVu573vizOuTxRStQ22jFOs3UE7l6ZA+2haZyjapOVx/Rx9gng/H3RzFHr/L21
# QpSiBGns/g2aIvRWegMvEkDsPRzJDQehK2SQfCtTmO5FAQpmBWQCZPWuvPp1etsr
# CyBKQAAcQPtU8V1ouJrz6slRmtErEJSepiNHVIzzMkmpMPaEACK7VZ0Hh/8UZhui
# T0YtgFI/Pwj5iwG0JVnNU1UB
# SIG # End signature block
