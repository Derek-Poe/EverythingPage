Write-Host -f Cyan "Siteboss Alarm Report Builder"

$PID | Set-Content C:\Automation\AutoServerMonitor\SitebossAlarmReportBuilder_multiInstance--PID.txt -Force

$listener = New-Object System.Net.HttpListener
$apiPort = 1483
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
  Param($con,$enc,$currentRS,$checkLength,$enableWebRequests,$reportChunk,$reportChunksLength,$instType,$u,$pp,$urlsChunk,$totalSites)
  #"Begin -- $instType" | Add-Content C:\Automation\SitebossHub\temp\debug.txt
  if($instType -eq "run"){
    ([ScriptBlock]::Create($enableWebRequests)).Invoke()
    #"Error1 - $($Error[0])"  | Add-Content C:\Automation\SitebossHub\temp\debug.txt
    #"Started -- $($urlsChunk[0].ip)" | Add-Content C:\Automation\SitebossHub\temp\debug.txt
    #Try{
      #$debugNum = 0
      forEach($site in $urlsChunk){
        $url = "https://$($site.ip)"
        #"URL -- $url -- User -- $u" | Add-Content C:\Automation\SitebossHub\temp\debug.txt
        $login = Invoke-WebRequest -Uri "$url/index.html?commit=login" -Headers @{"Origin" = "$url";"Accept-Encoding" = "gzip, deflate, br";"Accept-Language" = "en-US,en;q=0.9";"User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36";"Content-Type" = "application/x-www-form-urlencoded";"Accept" = "*/*";"Referer" = "$url/UnitLogin.html";"X-Requested-With" = "XMLHttpRequest"} -Body @{username="$u";password="$pp"} -SessionVariable sess
        #"Content -- $($login.RawContent)"  | Add-Content C:\Automation\SitebossHub\temp\debug.txt
        $sess.Cookies.SetCookies($url,$sess.Cookies.GetCookieHeader("$url/index.html?commit=login"))
        #"Cookies -- $($sess.Cookies.GetCookieHeader("$url/index.html?commit=login"))"  | Add-Content C:\Automation\SitebossHub\temp\debug.txt
        $xmlData = (Invoke-WebRequest -Uri "$url/SiteStatus.xml" -Headers @{"Upgrade-Insecure-Requests" = "1";"User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36";"Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3";"Accept-Encoding" = "gzip, deflate, br";"Accept-Language" = "en-US,en;q=0.9"} -WebSession $sess).Content
        
        $report = @()
        $sb = [xml]($xmlData)
        $name = $sb.Unit.Unit_Sitename
        #"Error2 - $($Error[0])"  | Add-Content C:\Automation\SitebossHub\temp\debug.txt
        #"Name -- $name" | Add-Content C:\Automation\SitebossHub\temp\debug.txt
        #$date = $sb.Unit.Unit_Date
        #$time = $sb.Unit.Unit_Time
        #$uptime = $sb.Unit.Unit_UpTime
     
        $sbPingResult = "Error"
        $siteNum = $site.site
        #$xmlData | Export-Clixml C:\Automation\SitebossHub\temp\debugXML$siteNum-$reportChunk-$debugNum`_$name.xml
        #$sb | Export-Clixml C:\Automation\SitebossHub\temp\debugSB$siteNum-$reportChunk-$debugNum`_$name.xml
        #$debugNum++
        #forEach($char in [char[]]$fileName){
        #  if($char -notmatch "_" -and $char -notmatch "[A-Z]"){
        #    $siteNum += $char
        #  }
        #  else{
        #    break
        #  }
        #}
        #$sbIndex = $sbs.Site.IndexOf($siteNum)
        #$sbIP = $sbs[$sbIndex].ip
        #$sbPing = ping -n 2 $sbIP
        #$sbPing = ping -n 1 -w 1000 $url.Split("://")[3]
        #if($sbPing -like "Reply from $sbIP*"){
        #  $sbPingResult = "Reachable"
        #}
        #elseIf($sbIndex -eq "-1"){
        #  $sbPingResult = "Error"
        #}
        #else{
        #  $sbPingResult = "Unreachable"
        #}
        #$exReport = @()
        forEach($es in $sb.Unit.EventSensor){
          $exReport = @()
          if($es.ES_State -eq "Unresponsive" -and $es.ES_Name -ne "Outdoor Sensor"){
            $props = [ordered]@{
              Site = $siteNum
              SiteName = $name
              SensorName = $es.ES_Name
              SensorStatus = "Unresponsive"
              SensorReading = "N/A"
              #SitebossDate = $date
              #SitebossTime = $time
              #SitebossUptime = $uptime
              #Ping = $sbPingResult
            }
            $obj = New-Object -TypeName PSCustomObject -Property $props
            $report += $obj
          }
          $esNum = $es.ES_Number
          ForEach($sensor in ($sb.Unit.EventSensor | ? {$_.ES_Number -eq $esNum}).Sensor){
            if($sensor.Sensor_Status_String -ne "Normal" -and $sensor.Sensor_Status_String -ne "Inactive" -and $sensor.Sensor_Status_Value -ne ""){
              $props = [ordered]@{
                Site = $siteNum
                SiteName = $name
                SensorName = $sensor.Sensor_Name
                SensorStatus = $sensor.Sensor_Status_String
                SensorReading = $sensor.Sensor_Value_String
                #SitebossDate = $date
                #SitebossTime = $time
                #SitebossUptime = $uptime
                #Ping = $sbPingResult
              }
            $obj = New-Object -TypeName PSCustomObject -Property $props
            $report += $obj
            }
            if($sensor.Sensor_Name -ne "unnamed"){
              #$exReport += New-Object PSCustomObject ([Ordered]@{ES=$enc.GetString($enc.GetBytes($esNum));Number=$enc.GetString($enc.GetBytes($sensor.Sensor_Number));Name=$enc.GetString($enc.GetBytes($sensor.Sensor_Name));Enabled=$enc.GetString($enc.GetBytes($sensor.Sensor_Enabled))})
              $exReport += New-Object PSCustomObject -Property ([Ordered]@{Site=$siteNum;ES=$esNum;Number=$sensor.Sensor_Number;Name=$sensor.Sensor_Name;Enabled=$sensor.Sensor_Enabled})
            }
          }
          #$exReport | Export-Csv "C:\Automation\SitebossHub\temp\SitebossAlarmReportChunk_$reportChunk`_$siteNum`_$name`_SensorReport_$esNum.csv" -Force -NoTypeInformation
          $exReport | Export-Csv "C:\Automation\SitebossHub\temp\SitebossAlarmReportChunk_$reportChunk`_$siteNum`_$name`_SensorReport_$(($sb.Unit.EventSensor | ? {$_.ES_Number -eq $esNum}).ES_Name)_$esNum.csv" -Force -NoTypeInformation
        }
        #$name = ([xml]$xmlData).Unit.Unit_Sitename
        #forEach($er in $error){
        #  "All Error -- $er" | Add-Content C:\Automation\SitebossHub\temp\debug.txt
        #}
        $report | % {$_.Site = $_.Site -as [int]}
        $report = $report | Sort Site
        $report | Export-Csv "C:\Automation\SitebossHub\temp\SitebossAlarmReportChunk_$reportChunk`_$siteNum`_$name.csv" -Force -NoTypeInformation
        #$exReport | Export-Csv "C:\Automation\SitebossHub\temp\SitebossAlarmReportChunk_$reportChunk`_$siteNum`_$name`_SensorReport.csv" -Force -NoTypeInformation
      }   
    #}
    #Catch{
    #  "CTIA PROBLEM!" | Set-Content "C:\Automation\SitebossHub\temp\OTAtempRecordChunk_$recordChunk.csv"
    #}
    $contFiles = (Get-ChildItem C:\Automation\SitebossHub\temp | ? {$_.Name -like "SitebossAlarmReportChunk_*.csv"})
    if($contFiles.Length -ge $totalSites -and $contFiles -is [Array]){
      $in = Invoke-WebRequest http://127.0.0.1:1483/d8a76sd8fa69d/e
    } 
  }
  elseIf($instType -eq "end"){
    $sbs = Import-Csv C:\Automation\SitebossHub\temp\sitebossIPs.csv
    $allCont = "`"Site`",`"Name`",`"SensorName`",`"SensorStatus`",`"SensorReading`"`n"
    forEach($chunk in (Get-ChildItem C:\Automation\SitebossHub\temp | ? {$_.Name -like "SitebossAlarmReportChunk_*.csv" | Sort Name})){
      $cont = Get-Content $chunk.FullName -Delimiter `n | Select -Skip 1
      if($cont -ne $null){
        $allCont += $cont
      }
      else{
        $sbIP = ($sbs | ? {$_.site -eq $chunk.Name.Split("_")[2]}).ip
        $ping = ping -n 1 -w 1000 $sbIP
        if($ping -like "Reply from $sbIP*"){
          #$allCont += "`"$($chunk.Name.Split("_")[2])`",`"$($chunk.Name.Split("_")[3].split(".")[0])`",`"Error`",`"Error`",`"Error`"`n"
        }
        else{
          $allCont += "`"$($chunk.Name.Split("_")[2])`",`"$($chunk.Name.Split("_")[3].split(".")[0])`",`"Unreachable`",`"Unreachable`",`"Unreachable`"`n"
        }
      }
    }
    $allCont | Set-Content C:\Automation\SitebossHub\temp\alarmReportData.csv -Force
    (Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt") | Set-Content C:\Automation\SitebossHub\temp\alarmReportDate.txt -Force

    $report = $allCont | ConvertFrom-Csv
    $report | % {$_.Site = $_.Site -as [int]}
    $report | Sort Site
    $creationDate = [Datetime]::Parse((Get-Content C:\Automation\SitebossHub\temp\alarmReportDate.txt))
    $excel = New-Object -ComObject excel.application
    #$excel.Visible = $true
    $null = $excel.Workbooks.Add()    
    $excel.Worksheets.Item(1).Name = "Tower Alarms"
    $excel.Worksheets.Item("Tower Alarms").Cells.Item(1,1) = "Tower Alarms -- $($creationDate.ToString("MM/dd/yyyy"))"
    $headers = @("Site","Site Name","Sensor Name","Sensor Status","Sensor Reading")
    $headersLength  = $headers.Length
    $reportLength = $report.Length
    $dataArray = New-Object "object[,]" $reportLength,$headersLength
    for($i = 0; $i -lt $reportLength; $i++){
      for($ii = 0; $ii -lt $headersLength; $ii++){
       $dataArray[$i,$ii] = $report[$i].(($report[$i].PSObject.Properties.Name)[$ii])
      }
    }
    #"Report -- $($report.Length)"  | Add-Content C:\Automation\SitebossHub\temp\debug.txt
    #"DataArray -- $($dataArray.Length)"  | Add-Content C:\Automation\SitebossHub\temp\debug.txt
    $excel.Worksheets.Item("Tower Alarms").Range($excel.Worksheets.Item("Tower Alarms").Cells.Item(2,1),$excel.Worksheets.Item("Tower Alarms").Cells.Item(2,$headersLength)) = $headers
    $excel.Worksheets.Item("Tower Alarms").Range($excel.Worksheets.Item("Tower Alarms").Cells.Item(3,1),$excel.Worksheets.Item("Tower Alarms").Cells.Item($reportLength + 2, $headersLength)) = $dataArray
    $null = $excel.Worksheets.Item("Tower Alarms").Range($excel.Worksheets.Item("Tower Alarms").Cells.Item(1,1),$excel.Worksheets.Item("Tower Alarms").Cells.Item(1,$headersLength)).Merge()
    $excel.Worksheets.Item("Tower Alarms").Range($excel.Worksheets.Item("Tower Alarms").Cells.Item(1,1),$excel.Worksheets.Item("Tower Alarms").Cells.Item($reportLength + 2, $headersLength)).HorizontalAlignment = [Microsoft.Office.Interop.Excel.XlHAlign]::xlHAlignCenter
    $excel.Worksheets.Item("Tower Alarms").Range($excel.Worksheets.Item("Tower Alarms").Cells.Item(1,1),$excel.Worksheets.Item("Tower Alarms").Cells.Item($reportLength + 2, $headersLength)).Borders.LineStyle = 1
    $null = $excel.Worksheets.Item("Tower Alarms").ListObjects.Add([Microsoft.Office.Interop.Excel.XlListObjectSourceType]::xlSrcRange, $excel.Worksheets.Item("Tower Alarms").Range($excel.Worksheets.Item("Tower Alarms").Cells.Item(2,1),$excel.Worksheets.Item("Tower Alarms").Cells.Item($reportLength + 2, $headersLength)), $null, [Microsoft.Office.Interop.Excel.XlYesNoGuess]::xlYes)
    $excel.Worksheets.Item("Tower Alarms").ListObjects.Item(1).TableStyle = "TableStyleMedium15"
    #$null = $excel.Worksheets.Item("Tower Alarms").Cells.Item(1,1).EntireColumn.ColumnWidth = 25.5
    #$null = $excel.Worksheets.Item("Tower Alarms").Cells.Item(1,2).EntireColumn.ColumnWidth = 39
    $excel.Worksheets.Item("Tower Alarms").Cells.Item(1,1).Font.Size = 12
    $excel.Worksheets.Item("Tower Alarms").Cells.Item(1,1).Font.Color = [Microsoft.Office.Interop.Excel.XlRgbColor]::rgbWhite
    $excel.Worksheets.Item("Tower Alarms").Cells.Item(1,1).Interior.Color = [Microsoft.Office.Interop.Excel.XlRgbColor]::rgbCornflowerBlue
    $null = ($excel.Worksheets.Item("Tower Alarms").UsedRange).EntireColumn.AutoFit()
    $excel.Worksheets.Item("Tower Alarms").PageSetup.Orientation = [Microsoft.Office.Interop.Excel.XlPageOrientation]::xlLandscape
    $excel.Worksheets.Item("Tower Alarms").PageSetup.Zoom = $false
    $excel.Worksheets.Item("Tower Alarms").PageSetup.FitToPagesTall = 10000
    $excel.Worksheets.Item("Tower Alarms").PageSetup.FitToPagesWide = 1
    $excel.Worksheets.Item("Tower Alarms").PageSetup.CenterHorizontally = $true
    $excel.Worksheets.Item("Tower Alarms").PageSetup.CenterVertically = $true
    $excel.Application.DisplayAlerts = $false
    Get-ChildItem C:\Automation\SitebossHub\ | ? {$_.Name -like "* - Siteboss Alarms Report.xlsx"} | Remove-Item -Force
    $reportDate = $creationDate.ToString("ddMMMyyyy (HHmm)")
    $excel.Workbooks.Item(1).SaveAs("C:\Automation\SitebossHub\temp\$reportDate - Siteboss Alarms Report.xlsx")
    #$excel.Application.DisplayAlerts = $true
    $excel.Quit() 
    Get-ChildItem C:\Automation\SitebossHub\temp | ? {$_.Name -like "* - Siteboss Alarms Report.xlsx"} | Remove-Item -Force
    Copy-Item "C:\Automation\SitebossHub\temp\$reportDate - Siteboss Alarms Report.xlsx" -Destination "C:\Automation\SitebossHub\" -Force

    $in = Invoke-WebRequest http://127.0.0.1:1483/d8a76sd8fa69d/f
  }
  exit
}

$maxRun = 80
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
function startRunspace($runspace,$enc,$reportChunk,$reportChunksLength,$instType,$u,$pp,$urlsChunk,$enableWebRequests,$totalSites){
  $psInst.Inst.([String]$context.CurrentCon) = [PowerShell]::Create()
  $psInst.Inst.([String]$context.CurrentCon).RunspacePool = $runspace
  $null = $psInst.Inst.([String]$context.CurrentCon).AddScript($main).`
          AddArgument($context.Con.([String]$context.CurrentCon)).AddArgument($enc).`
          AddArgument([String]$context.CurrentCon).AddArgument($checkLength).AddArgument($enableWebRequests).`
          AddArgument($reportChunk).AddArgument($reportChunksLength).AddArgument($instType).`
          AddArgument($u).AddArgument($pp).AddArgument($urlsChunk).AddArgument($totalSites)
  $psInst.Stat.([String]$context.CurrentCon) = $psInst.Inst.([String]$context.CurrentCon).BeginInvoke()
}
function cleanup($context,$psInst){
  1..$maxRun | % {
    $i = $_
    if(!($context.ConAvail.([String]$i))){
      if($psInst.Stat.([String]$i).IsCompleted){
        $context.ConAvail.([String]$i) = $true
      }
    }
  }
  return New-Object -TypeName PSCustomObject -Property @{context=$context;psInst=$psInst}
}

$k = Get-Content \\fileshare01\home\dpoe\Reports\reportData\b1n9rk322ndh29dn39d.key
$u = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((Get-Content \\fileshare01\home\dpoe\reports\reportData\dpkj4b1lk32j4b341bd12.txt | ConvertTo-SecureString -Key $k)))
$pp = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((Get-Content \\fileshare01\home\dpoe\reports\reportData\dpp34l1k23b4lkj2134bb.txt | ConvertTo-SecureString -Key $k)))

$runningCollect = $false
$chunkSize = 1
$cleanCycle = 0
do{
  $conTemp = $listener.GetContext()
  if(($conTemp.Request.RawUrl).Split("/")[1] -eq "d8a76sd8fa69d"){
    if(($conTemp.Request.RawUrl).Split("/")[2] -eq "s" -and $runningCollect -eq $false){
      $startTime = (Get-Date)
      Write-Host "StartTime: $($startTime.ToString(`"MM/dd/yyyy hh:mm:ss tt"))" -NoNewline
      $startCon = $conTemp
      $runningCollect = $true
      Get-ChildItem C:\Automation\SitebossHub\temp\ | ? {$_.Name -like "SitebossAlarmReportChunk_*"} | Remove-Item -Force
      Get-ChildItem C:\Automation\SitebossHub\temp\ | ? {$_.Name -eq "sitebossIPs.csv"} | Remove-Item -Force
      Copy-Item C:\Automation\SitebossHub\sitebossIPs.csv -Destination C:\Automation\SitebossHub\temp\ -Force
      $sbs = Import-Csv C:\Automation\SitebossHub\temp\sitebossIPs.csv
      $totalSites = $sbs.Length
      $reportChunksLength = [Math]::Ceiling(($sbs.Length / $chunkSize))
      $startPos = 0
      $reportChunk = 0
      for($i = 0; $i -lt $reportChunksLength; $i++){
        assignContext #-conTemp $conTemp
        startRunspace -runspace $runspace -enc $enc -enableWebRequests $enableWebRequests -instType "run" -u $u -pp $pp -reportChunk $reportChunk -reportChunksLength $reportChunksLength -totalSites $totalSites -urlsChunk ($sbs | Select site,ip -First $chunkSize -Skip $startPos)
        $startPos += $chunkSize
        $reportChunk++
      }
    }
    elseIf(($conTemp.Request.RawUrl).Split("/")[2] -eq "e"){
      assignContext #-conTemp $conTemp
      startRunspace -runspace $runspace -enc $enc -instType "end" 
    }
    elseIf(($conTemp.Request.RawUrl).Split("/")[2] -eq "f"){
      $startCon.Response.Close()
      $runningCollect = $false
      Write-Host " -- Exec Time: $((New-TimeSpan -Start $startTime -End (Get-Date)).ToString("hh\:mm\:ss"))"
      #
        $listener.Close()
        break
      #
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
