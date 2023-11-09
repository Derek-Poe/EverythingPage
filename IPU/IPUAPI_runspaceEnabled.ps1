Write-Host -f Cyan "IPU API"

$PID | Set-Content C:\Automation\AutoServerMonitor\IPUAPI--PID.txt -Force

$listener = New-Object System.Net.HttpListener
$apiPort = 9748
$hostName = "$env:COMPUTERNAME.ctcis.local"
$listener.Prefixes.Add("https://$hostName`:$apiPort/")
$listener.Start()

#[void][System.Reflection.Assembly]::LoadFrom("C:\Automation\IPU\System.Data.SQLite.dll")
#$slBytes = [System.IO.File]::ReadAllBytes("C:\Automation\IPU\System.Data.SQLite.dll")
#$sliBytes = [System.IO.File]::ReadAllBytes("C:\Automation\IPU\SQLite.Interop.dll")
#[System.Reflection.Assembly]::Load($slBytes)
#[System.Reflection.Assembly]::Load($sliBytes)
#$conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=C:\Automation\IPU\ws.sqlite;Persist Security Info=false;Mode=ReadWrite;")
#$conn.Open()
#$cmd = $conn.CreateCommand()
$enc = [System.Text.Encoding]::ASCII
<#
$getPackedDT = {
  Param($datTab)
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
#>
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

$getSessionKey = {
  $sessKey = ""
  for($i = 0; $i -lt 24; $i++){
    switch(Get-Random -Minimum 1 -Maximum 4){
      1 {
        $sessKey += "$(Get-Random -Minimum 1 -Maximum 4)"
        break
      }
      2 {
        $sessKey += [char](Get-Random -Minimum 65 -Maximum 91)
        break
      }
      3 {
         $sessKey += [char](Get-Random -Minimum 97 -Maximum 123)
         break
      }
    }
  }
  "Session Key -- $sessKey" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force
  return $sessKey
}

$checkCredentials = {
  Param($u,$p,$authUsers)
  "Runspace Flow ::$currentRS:: Cred Check -- $u" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force
  $adCheck = $null
  $adCheck = New-Object System.DirectoryServices.DirectoryEntry -ArgumentList "LDAP://ctcis.local",$u,$p
  if($adCheck.Name -ne $null -and $u -in $authUsers){
    "Runspace Flow ::$currentRS:: Cred Check PASS -- $u" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force
    return $true
  }
  else{
    "Runspace Flow ::$currentRS:: Cred Check FAIL -- $u" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force
    return $false
  }
}

<#
$loginUser = {
  Param($user,$cmd,$rdr,$dt)
  "loginUser: Start -- $user" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force
  $userData = $null
  $query = "SELECT * FROM Sessions WHERE User LIKE '$user';"
  $cmd.CommandText = $query
  $rdr = $cmd.ExecuteReader()
  $dt.Clear() 
  $dt.Load($rdr)
  $userData = (Invoke-Command -ScriptBlock $getPackedDT -ArgumentList $dt)
  if($userData -ne $null){
    "loginUser: Already a User" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force
    $newTime = ((Get-Date).AddMinutes($sessionTimeout)).ToString("MM/dd/yyyy hh:mm:ss tt")
    $session = (Invoke-Command -ScriptBlock $getSessionKey)
    $query = "UPDATE OR REPLACE Sessions SET Session = '$session', Time = '$newTime' WHERE User LIKE '$user';"
    $cmd.CommandText = $query
    $ex = $cmd.ExecuteNonQuery()
  }
  else{
    "loginUser: New User" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force
    $newTime = ((Get-Date).AddMinutes($sessionTimeout)).ToString("MM/dd/yyyy hh:mm:ss tt")
    $session = (Invoke-Command -ScriptBlock $getSessionKey)
    $query = "INSERT INTO Sessions ([User], [Session], [Time]) VALUES ('$user', '$session', '$newTime');"
    $cmd.CommandText = $query
    $ex = $cmd.ExecuteNonQuery()
  }
  "loginUser: End -- $session" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force
  return $session
}
#>
$loginUser = {
  Param($user)
  "Runspace Flow ::$currentRS:: Login -- $user" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force
  return $enc.GetString((Invoke-WebRequest -UseBasicParsing -Uri "https://127.0.0.1:9740/2k3b4j2h4j5tb/LI" -Method POST -Body $user).Content)
}

<#
$checkLogin = {
  Param($session,$cmd,$rdr,$dt)
  "checkLogin: Start -- $session" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force
  $userData = $null
  $query = "SELECT * FROM Sessions WHERE Session LIKE '$session';"
  $cmd.CommandText = $query
  $rdr = $cmd.ExecuteReader()
  $dt.Clear() 
  $dt.Load($rdr)
  $userData = (Invoke-Command -ScriptBlock $getPackedDT -ArgumentList $dt)
  #"Checklogin -- Session: $session ; UserData: $($userData.User)" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force
  if($userData -ne $null){
    if((New-TimeSpan -Start ([DateTime]::Parse($userData.Time)) -End (Get-Date)).Minutes -gt $sessionTimeout){
      return $false
    }
    else{
      $newTime = ((Get-Date).AddMinutes($sessionTimeout)).ToString("MM/dd/yyyy hh:mm:ss tt")
      $query = "UPDATE Sessions SET Time = '$newTime' WHERE Session LIKE '$session';"
      $cmd.CommandText = $query
      $ex = $cmd.ExecuteNonQuery()
      return $true
    }
  }
  return $false
}
#>

$checkLogin = {
  Param($session)
  "Runspace Flow ::$currentRS:: Check Login -- $session" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force
  $result = $enc.GetString((Invoke-WebRequest -UseBasicParsing -Uri "https://127.0.0.1:9740/2k3b4j2h4j5tb/CL" -Method POST -Body $session).Content)
  if($result -eq "t"){
    return $true
  }
  else{
    return $false
  }
}

$main = {
  Param($con,$enc,$conn,$currentRS,$getPackedDT,$checkLength,$getSessionKey,$checkCredentials,$loginUser,$checkLogin,$enableWebRequests)
  "Runspace Flow ::$currentRS:: Beginning of Main SB" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force
  ([ScriptBlock]::Create($enableWebRequests)).Invoke()
  #[void][System.Reflection.Assembly]::LoadFrom("C:\Automation\IPU\assemblies\$currentRS\System.Data.SQLite.dll")

  #$query = "SELECT * FROM Sessions;"
  #$cmd.CommandText = $query
  #$rdr = $cmd.ExecuteReader()
  #$dt.Clear() 
  #$dt.Load($rdr)
  #$userData = (Invoke-Command -ScriptBlock $getPackedDT -ArgumentList $dt)
  #"UserData (DEBUG): $($userData.User)" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force
  #"$checkLogin.ToString()" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force

  $sessionTimeout = 30
  $authUsers = @("dpoe","jroberts","ddavis","dburk","kgrevemberg","rhood","zrogers","qcourtney","iholguin","hjewett")

  $cmd = $conn.CreateCommand()
  $dt = New-Object System.Data.DataTable
  $dbnull = [System.DBNull]::Value

  $apiKey = "16dsfSFfgsf3"
  $context = $con
  $requester = $context.Request.RemoteEndPoint
  $request = $context.Request.RawUrl
  "IPI_API $((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: $requester -- $request" | Add-Content -Force -Path c:\Automation\IPU\ipu_web_log.txt
  $request = $request.Substring(1,$request.Length-1)
  $request = $request.split("/")
  $reqSess = $null
  $byteMess = $null
  if(($context.Request.Cookies | ? {$_.Name -eq "ipuSess"}) -ne $null){
    $reqSess = ($context.Request.Cookies | ? {$_.Name -eq "ipuSess"}).Value.Trim()
  }
  if($request[0] -eq $apiKey){
    #if((Invoke-Command -ScriptBlock $checkLogin -ArgumentList ($reqSess),($cmd),($rdr),($dt)) -or $request[1] -like "IPURR*"){
     if((Invoke-Command -ScriptBlock $checkLogin -ArgumentList ($reqSess)) -or $request[1] -like "IPURR*"){
      switch($request[1]){

        "IPURRSummaryData" {
          $byteMess = $enc.GetBytes((Import-Csv (Get-ChildItem "C:\Automation\IPU" | ? {$_.Name -like "IPURR_DataCollection_*_summary.csv"}).FullName | ConvertTo-JSON))
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          break
        }

        "IPURRRateData" {
          $file = (Get-ChildItem "C:\Automation\IPU" | ? {$_.Name -like "IPURR_DataCollection_*_$($request[2]).csv"}).FullName
          if($file -ne $null){
            if($file -is [Array]){
              $ipuData = Import-Csv $file[0]
            }
            else{
              $ipuData = Import-Csv $file
            }
            $byteMess = $enc.GetBytes(($ipuData | Sort IPUName |ConvertTo-JSON))
            $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
            $context.Response.Close()
          }
          else{
            $byteMess = $enc.GetBytes("NF")
            $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          }
          break
        }

        "IPURRReport" {
          $rates = @()
          $ipus = New-Object PSCustomObject
          forEach($file in (Get-ChildItem "C:\Automation\IPU" | ? {$_.Name -like "IPURR_DataCollection_*.csv"}).FullName){
            $rate = ($file.Split("_")[3]).Split(".")[0]
            if($rate -ne "summary"){
              $rates += $rate
              $ipus | Add-Member -MemberType NoteProperty -Name $rate -Value (Import-Csv $file)
            }
          }
          $creationDate = (Get-Date)
          $excel = New-Object -ComObject excel.application
          #$excel.Visible = $true
          $null = $excel.Workbooks.Add()
          $sheetNum = 1
          $exSheetCount = 0
          forEach($chCheck in $rates){
            if((Invoke-Command -ScriptBlock $checkLength -ArgumentList ($ipus.($chCheck))) -gt 0){
              $exSheetCount++
            }
          }
          for($i = 0; $i -lt $exSheetCount; $i++){
            $null = $excel.ActiveWorkbook.Sheets.Add()
          }
          $excel.Worksheets.Item($sheetNum).Name = "Summary"
          $excel.Worksheets.Item("Summary").Cells.Item(1,1) = "IPU Reporting Rates Report -- Summary -- $($creationDate.ToString("MM/dd/yyyy"))"
          $excel.Worksheets.Item("Summary").Cells.Item(2,1) = "Reporting Rate"
          $excel.Worksheets.Item("Summary").Cells.Item(2,2) = "IPUs"
          $rowCount = 3
          forEach($rate in $rates){
            $excel.Worksheets.Item("Summary").Cells.Item($rowCount,1) = $rate
            $excel.Worksheets.Item("Summary").Cells.Item($rowCount,2) = (Invoke-Command -ScriptBlock $checkLength -ArgumentList ($ipus.($rate)))
            $rowCount++
          }
          $rowCount--
          $null = $excel.Worksheets.Item("Summary").Range($excel.Worksheets.Item("Summary").Cells.Item(1,1),$excel.Worksheets.Item("Summary").Cells.Item(1,2)).Merge()
          $excel.Worksheets.Item("Summary").Range($excel.Worksheets.Item("Summary").Cells.Item(1,1),$excel.Worksheets.Item("Summary").Cells.Item($rowCount,2)).HorizontalAlignment = [Microsoft.Office.Interop.Excel.XlHAlign]::xlHAlignCenter
          $excel.Worksheets.Item("Summary").Range($excel.Worksheets.Item("Summary").Cells.Item(1,1),$excel.Worksheets.Item("Summary").Cells.Item($rowCount,2)).Borders.LineStyle = 1
          $null = $excel.Worksheets.Item("Summary").Cells.Item(1,1).EntireColumn.ColumnWidth = 25.5
          $null = $excel.Worksheets.Item("Summary").Cells.Item(1,2).EntireColumn.ColumnWidth = 39
          $excel.Worksheets.Item("Summary").Cells.Item(1,1).Font.Size = 12
          $excel.Worksheets.Item("Summary").Cells.Item(1,1).Font.Color = [Microsoft.Office.Interop.Excel.XlRgbColor]::rgbWhite
          $excel.Worksheets.Item("Summary").Cells.Item(1,1).Interior.Color = [Microsoft.Office.Interop.Excel.XlRgbColor]::rgbCornflowerBlue
          $excel.Worksheets.Item("Summary").PageSetup.Orientation = [Microsoft.Office.Interop.Excel.XlPageOrientation]::xlLandscape
          $excel.Worksheets.Item("Summary").PageSetup.Zoom = $false
          $excel.Worksheets.Item("Summary").PageSetup.FitToPagesTall = 10000
          $excel.Worksheets.Item("Summary").PageSetup.FitToPagesWide = 1
          $excel.Worksheets.Item("Summary").PageSetup.CenterHorizontally = $true
          $excel.Worksheets.Item("Summary").PageSetup.CenterVertically = $true
          $sheetNum++
          forEach($rate in $rates){
            $headers = @("IPU Name","Msg #","Serial","Creation Date","Distance","Rate","Heading","Speed","EPE","Battery")
            $dataArray = New-Object "object[,]" (Invoke-Command -ScriptBlock $checkLength -ArgumentList ($ipus.($rate))),($headers.Length)
            for($i = 0; $i -lt ((Invoke-Command -ScriptBlock $checkLength -ArgumentList ($ipus.($rate)))); $i++){
              for($ii = 0; $ii -lt $headers.Length; $ii++){
               $dataArray[$i,$ii] = ($ipus.($rate)[$i]).((($ipus.($rate))[$i].PSObject.Properties.Name)[$ii])
              }
            }
            $excel.Worksheets.Item($sheetNum).Name = $rate
            $excel.Worksheets.Item("$rate").Cells.Item(1,1) = "IPUs -- Rate: $rate -- $($creationDate.ToString("MM/dd/yyyy"))"
            $excel.Worksheets.Item("$rate").Range($excel.Worksheets.Item("$rate").Cells.Item(2,1),$excel.Worksheets.Item("$rate").Cells.Item(2,$headers.Length)) = $headers
            $excel.Worksheets.Item("$rate").Range($excel.Worksheets.Item("$rate").Cells.Item(3,1),$excel.Worksheets.Item("$rate").Cells.Item((Invoke-Command -ScriptBlock $checkLength -ArgumentList ($ipus.($rate))) + 2, $headers.Length)) = $dataArray
            $null = $excel.Worksheets.Item("$rate").Range($excel.Worksheets.Item("$rate").Cells.Item(1,1),$excel.Worksheets.Item("$rate").Cells.Item(1,$headers.Length)).Merge()
            $null = $excel.Worksheets.Item("$rate").ListObjects.Add([Microsoft.Office.Interop.Excel.XlListObjectSourceType]::xlSrcRange, $excel.Worksheets.Item("$rate").Range($excel.Worksheets.Item("$rate").Cells.Item(2,1),$excel.Worksheets.Item("$rate").Cells.Item((Invoke-Command -ScriptBlock $checkLength -ArgumentList ($ipus.($rate))) + 2, $headers.Length)), $null, [Microsoft.Office.Interop.Excel.XlYesNoGuess]::xlYes)
            $excel.Worksheets.Item("$rate").ListObjects.Item(1).TableStyle = "TableStyleMedium15"
            $null = ($excel.Worksheets.Item("$rate").UsedRange).EntireColumn.AutoFit()
            $excel.Worksheets.Item("$rate").Cells.Item(1,1).Font.Size = 12
            $excel.Worksheets.Item("$rate").Cells.Item(1,1).Font.Color = [Microsoft.Office.Interop.Excel.XlRgbColor]::rgbWhite
            $excel.Worksheets.Item("$rate").Cells.Item(1,1).Interior.Color = [Microsoft.Office.Interop.Excel.XlRgbColor]::rgbCornflowerBlue
            $excel.Worksheets.Item("$rate").Range($excel.Worksheets.Item("$rate").Cells.Item(1,1),$excel.Worksheets.Item("$rate").Cells.Item(1,$headers.Length)).Borders.LineStyle = 1
            $excel.Worksheets.Item("$rate").Range($excel.Worksheets.Item("$rate").Cells.Item(1,1),$excel.Worksheets.Item("$rate").Cells.Item(1,$headers.Length)).Borders.Weight = [Microsoft.Office.Interop.Excel.XlBorderWeight]::xlThin
            ($excel.Worksheets.Item("$rate").UsedRange).HorizontalAlignment = [Microsoft.Office.Interop.Excel.XlHAlign]::xlHAlignCenter
            $excel.Worksheets.Item("$rate").Range($excel.Worksheets.Item("$rate").Cells.Item(3,1),$excel.Worksheets.Item("$rate").Cells.Item((Invoke-Command -ScriptBlock $checkLength -ArgumentList ($ipus.($rate))) + 2,1)).HorizontalAlignment = [Microsoft.Office.Interop.Excel.XlHAlign]::xlHAlignLeft
            $null = ($excel.Worksheets.Item("$rate").UsedRange).EntireColumn.AutoFit()
            $excel.Worksheets.Item("$rate").PageSetup.Orientation = [Microsoft.Office.Interop.Excel.XlPageOrientation]::xlLandscape
            $excel.Worksheets.Item("$rate").PageSetup.Zoom = $false
            $excel.Worksheets.Item("$rate").PageSetup.FitToPagesTall = 10000
            $excel.Worksheets.Item("$rate").PageSetup.FitToPagesWide = 1
            $excel.Worksheets.Item("$rate").PageSetup.CenterHorizontally = $true
            $excel.Worksheets.Item("$rate").PageSetup.CenterVertically = $true
            $sheetNum++
          }
          $excel.Application.DisplayAlerts = $false
          Get-ChildItem C:\Automation\IPU | ? {$_.Name -like "* - IPU Reporting Rates.xlsx"} | Remove-Item -Force
          $reportDate = $creationDate.ToString("ddMMMyyyy (HHmm)")
          $excel.Workbooks.Item(1).SaveAs("C:\Automation\IPU\$reportDate - IPU Reporting Rates.xlsx")
          #$excel.Application.DisplayAlerts = $true
          $excel.Quit()      
          $content = Get-Content -Encoding Byte -Path ((Get-ChildItem C:\Automation\IPU | ? {$_.Name -like "* - IPU Reporting Rates.xlsx"}).FullName)
          $content = [Convert]::ToBase64String($content)
          $content = $enc.GetBytes($content)
          $context.Response.OutputStream.Write($content,0,$content.Length)
          break
        }

        "IPURRReportDate" {
          $byteMess = $enc.GetBytes($reportDate)
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          break
        }

        "getOTAPage" {
          $content = Get-Content -Encoding Byte -Path C:\Automation\IPU\IPUOTApageFull.html
          $context.Response.OutputStream.Write($content,0,$content.Length)
          break
        }

        "instrDataPull" {
          Try{
            $instrData = Import-Clixml C:\Automation\IPU\instrData.xml
            $instrData = $instrData | Select * -ExcludeProperty batteryLevel,bitResult,timeOfLastBitResult,periodicBitRate,isOutOfComms
            $byteMess = $enc.GetBytes(($instrData | ConvertTo-Json))
          }
          Catch{
            $byteMess = $enc.GetBytes("CTIA PROBLEM!")
          }
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          break
        }

        "instrDataReload" {
          #$exerData = ((Invoke-WebRequest -UseBasicParsing -WebSession $webSess -Uri "http://10.224.218.12:8080/ctia.exercise/exercises" -Headers @{"Pragma"="no-cache"; "Sec-Fetch-Site"="same-origin"; "Accept-Encoding"="gzip, deflate, br"; "Accept-Language"="en-US,en;q=0.9"; "User-Agent"="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36"; "Sec-Fetch-Mode"="cors"; "Accept"="application/json, text/plain, */*"; "Cache-Control"="no-cache"; "Referer"="http://10.224.218.12:8080/ctia.exercise/exercises";} -ContentType "application/json").Content) | ConvertFrom-Json
          #$exer = $exerData.payload.exercises.id.uuid
          $time = ((Get-Date).ToUniversalTime()).ToString("yyyy-MM-ddhh:mm:ss")
          $time = $time.Insert(10,"T")
          $time = $time.Insert($time.Length,".000Z")
          $instrData = Invoke-WebRequest -UseBasicParsing -Uri "http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation" -Method "POST" -Headers @{"Pragma"="no-cache"; "Sec-Fetch-Site"="same-origin"; "Origin"="http://10.224.218.12"; "Accept-Encoding"="gzip, deflate, br"; "Accept-Language"="en-US,en;q=0.9"; "User-Agent"="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36"; "Sec-Fetch-Mode"="cors"; "Accept"="application/json, text/plain, */*"; "Cache-Control"="no-cache"; "Referer"="http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation";} -ContentType "application/json" -Body "{`"queryName`":`"QueryAllInstrumentation`",`"header`":{`"id`":{`"uuid`":`"$((New-Guid).Guid)`",`"class`":`"ctia.data_model.HeaderId`"},`"sentTime`":`"$time`",`"actualTime`":`"$time`",`"serviceName`":`"SoaInstrumentationService`",`"userName`":`"$("TCE")`",`"host`":`"s-lctia4-102.ctcis.local`",`"class`":`"ctia.data_model.HeaderData`"},`"projections`":[],`"class`":`"ctia.data_model.NamedQueryRequest`"}"
          $instrData = ($instrData.Content | ConvertFrom-Json).payload.instrumentationList
          $instrData | Select serialNumber,batteryLevel,bitResult,timeOfLastBitResult,actualDistanceReportingRate,actualTimeReportingRate,periodicBitRate,ipuSoftwareVersion,isOutOfComms | Export-Clixml C:\Automation\IPU\instrDataAll.xml -Force
          $ICIPU = Import-Csv C:\Automation\IPU\inCommsIPUs.csv
          $instrData = $instrData | ? {$_.serialNumber -in $ICIPU.ICIPU}
          $instrData | Select serialNumber,batteryLevel,bitResult,timeOfLastBitResult,actualDistanceReportingRate,actualTimeReportingRate,periodicBitRate,ipuSoftwareVersion,isOutOfComms | Export-Clixml C:\Automation\IPU\instrData.xml -Force
          (Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt") | Set-Content C:\Automation\IPU\instrDataDate.txt -Force
          break
        }

        "instrDate" {
          $byteMess = $enc.GetBytes((Get-Content C:\Automation\IPU\instrDataDate.txt))
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          break
        }

        "otaSend" {
          $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
          $jso = $bodyRead.ReadToEnd() | ConvertFrom-Json
          #$jso | Add-Content C:\Automation\IPU\runspaceDebug.txt
          $ep = New-Object System.Net.IPEndPoint([IPAddress]::Parse("10.2.17.0"),9792)
          $uc = New-Object System.Net.Sockets.UdpClient
          $enc = [System.Text.Encoding]::ASCII

          $rate = $jso.rate
          $swupBytes = $enc.GetBytes("http://10.2.2.78/rdms/ipu_upgrade_1-7-1-1_1-7-1-2_JRTC.tar.gz")
          $ipus = @()
          forEach($ipu in $jso.IPUs){
            $ipus += $ipu.Split("-")[1]
          }

          #$jso.rate | Add-Content C:\Automation\IPU\runspaceDebug.txt
          #$jso.IPUs | Add-Content C:\Automation\IPU\runspaceDebug.txt
          #$jso | Export-Clixml C:\Automation\IPU\jsoDebug.txt -Force

          forEach($ipu in $ipus){
            "::$currentRS:: $ipu -- $rate" | Add-Content C:\Automation\IPU\runspaceDebug.txt
            $ipuBytes = $enc.GetBytes($ipu)

            $allBytes = @()
            switch($rate){
              "15" {
                $bytes1 = @(0x08, 0x81, 0x80, 0x80, 0xf8, 0x07, 0x10, 0xa5, 0x4c, 0x18, 0x9b, 0x94, 0xd8, 0xff, 0x85, 0x2f, 0x20, 0x07, 0x2a, 0x31, 0x08, 0x02, 0x10, 0x01, 0x18, 0x01, 0x22, 0x0b, 0x49, 0x50, 0x55, 0x2d)
                $bytes2 = @(0x28, 0x00, 0x30, 0x00, 0x3a, 0x18, 0xbb, 0x01, 0x18, 0x02, 0x00, 0x00, 0x00, 0x0f, 0x00, 0x00, 0x00, 0x0a, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0xf3, 0x32, 0x0b, 0x49, 0x50, 0x55, 0x2d)
                $bytes1 | % {$allBytes += $_}
                $ipuBytes | % {$allBytes += $_}
                $bytes2 | % {$allBytes += $_}
                $ipuBytes | % {$allBytes += $_}
                break
              }
              "30" {
                $bytes1 = @(0x08, 0x81, 0x80, 0x80, 0xf8, 0x07, 0x10, 0xa5, 0x4c, 0x18, 0x80, 0xf0, 0xff, 0xfe, 0x85, 0x2f, 0x20, 0x07, 0x2a, 0x31, 0x08, 0x02, 0x10, 0x01, 0x18, 0x01, 0x22, 0x0b, 0x49, 0x50, 0x55, 0x2d)
                $bytes2 = @(0x28, 0x00, 0x30, 0x00, 0x3a, 0x18, 0xbb, 0x01, 0x18, 0x02, 0x00, 0x00, 0x00, 0x1e, 0x00, 0x00, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x01, 0x5c, 0x32, 0x0b, 0x49, 0x50, 0x55, 0x2d)
                $bytes1 | % {$allBytes += $_}
                $ipuBytes | % {$allBytes += $_}
                $bytes2 | % {$allBytes += $_}
                $ipuBytes | % {$allBytes += $_}
                break
              }
              "300" {
                $bytes1 = @(0x08, 0x81, 0x80, 0x80, 0xf8, 0x07, 0x10, 0xa5, 0x4c, 0x18, 0xa8, 0x8e, 0xa7, 0xa4, 0x86, 0x2f, 0x20, 0x07, 0x2a, 0x31, 0x08, 0x02, 0x10, 0x01, 0x18, 0x01, 0x22, 0x0b, 0x49, 0x50, 0x55, 0x2d)   
                $bytes2 = @(0x28, 0x00, 0x30, 0x00, 0x3a, 0x18, 0xbb, 0x01, 0x18, 0x02, 0x00, 0x00, 0x01, 0x2c, 0x00, 0x00, 0x00, 0x0a, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x01, 0x11, 0x32, 0x0b, 0x49, 0x50, 0x55, 0x2d)
                $bytes1 | % {$allBytes += $_}
                $ipuBytes | % {$allBytes += $_}
                $bytes2 | % {$allBytes += $_}
                $ipuBytes | % {$allBytes += $_}
                break
              }
              "SWUP" {
                $bytes1 = @(0x08, 0x81, 0x80, 0x80, 0xf8, 0x07, 0x10, 0xa5, 0x4c, 0x18, 0xca, 0xf5, 0xfe, 0xa2, 0x86, 0x2f, 0x20, 0x03, 0x2a, 0x97, 0x02, 0x08, 0x02, 0x10, 0x01, 0x18, 0x02, 0x22, 0x0b, 0x49, 0x50, 0x55, 0x2d)
                $bytes2 = @(0x28, 0x00, 0x30, 0x00, 0x3a, 0xfd, 0x01, 0xbb, 0x02, 0xfd, 0x01)
                $bytes3 = @(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x13, 0xf1, 0x32, 0x0b, 0x49, 0x50, 0x55, 0x2d)
                $bytes1 | % {$allBytes += $_}
                $ipuBytes | % {$allBytes += $_}
                $bytes2 | % {$allBytes += $_}
                $swupBytes | % {$allBytes += $_}
                $bytes3 | % {$allBytes += $_}
                $ipuBytes | % {$allBytes += $_}
                break
              } 
            } 

            $ms = $allBytes
            $send = $uc.Send($ms,$ms.Length,$ep)
          }

          $byteMess = $enc.GetBytes("Sent")
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          Start-Sleep -Seconds 5
        }
    
        default{
          $context.Response.StatusCode = 404;
        }
      }
    }
    else{
      $byteMess = $enc.GetBytes("IL")
      $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
    }
    $context.Response.Close()
  }
  elseIf($request[0] -eq "login"){
    $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
    $cr = ($bodyRead.ReadToEnd()).Split(",")
    if((Invoke-Command -ScriptBlock $checkCredentials -ArgumentList ($cr[0].Trim()),($cr[1].Trim()),$authUsers)){
      #$byteMess = $enc.GetBytes(((Invoke-Command -ScriptBlock $loginUser -ArgumentList ($cr[0].Trim()),($cmd),($rdr),($dt))))
      $byteMess = $enc.GetBytes(((Invoke-Command -ScriptBlock $loginUser -ArgumentList ($cr[0].Trim()))))
      $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
    }
    else{
      $byteMess = $enc.GetBytes("ILA")
      $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
    }
  }
  elseIf($request[0] -eq "lc"){
    #if((Invoke-Command -ScriptBlock $checkLogin -ArgumentList ($reqSess),($cmd),($rdr),($dt))){
    if((Invoke-Command -ScriptBlock $checkLogin -ArgumentList ($reqSess))){
      $byteMess = $enc.GetBytes("LI")
      $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
    }
    else{
      $byteMess = $enc.GetBytes("NLI")
      $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
    }
  }
  elseIf($request[0] -eq "IPURR"){
    $content = Get-Content -Encoding Byte -Path C:\Automation\IPU\IPURRpage.html
    $context.Response.OutputStream.Write($content,0,$content.Length)
  }
  elseIf($request[0] -eq "IPUOTA"){
    $content = Get-Content -Encoding Byte -Path C:\Automation\IPU\IPUOTApage.html
    $context.Response.OutputStream.Write($content,0,$content.Length)
  }
  elseIf($request[0] -eq "favicon.ico"){
    $content = Get-Content -Encoding Byte -Path C:\Automation\IPU\favicon.ico
    #$content = [Convert]::ToBase64String($content)
    $context.Response.OutputStream.Write($content,0,$content.Length)
  }
  else{
    $context.Response.StatusCode = 404;
  }
  $context.Response.Close()
  "Runspace Flow ::$currentRS:: End of Main SB" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force
}

#$maxRun = Read-Host "Runspaces"
$maxRun = 8
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
function startRunspace($runspace,$enc){
  $psInst.Inst.([String]$context.CurrentCon) = [PowerShell]::Create()
  $psInst.Inst.([String]$context.CurrentCon).RunspacePool = $runspace
  $null = $psInst.Inst.([String]$context.CurrentCon).AddScript($main).`
          AddArgument($context.Con.([String]$context.CurrentCon)).AddArgument($enc).AddArgument($conn).`
          AddArgument([String]$context.CurrentCon).AddArgument($getPackedDT).AddArgument($checkLength).AddArgument($getSessionKey).`
          AddArgument($checkCredentials).AddArgument($loginUser).AddArgument($checkLogin).AddArgument($enableWebRequests)
  $psInst.Stat.([String]$context.CurrentCon) = $psInst.Inst.([String]$context.CurrentCon).BeginInvoke()
}
function cleanup($context,$psInst){
  1..$maxRun | % {
    $i = $_
    if(!($context.ConAvail.([String]$i))){
      if($psInst.Stat.([String]$i).IsCompleted){
        $psInst.Res.([String]$context.CurrentCon) = $psInst.Inst.([String]$context.CurrentCon).EndInvoke($psInst.Stat.([String]$context.CurrentCon))
        $context.ConAvail.([String]$i) = $true
      }
    }
  }
  return New-Object -TypeName PSCustomObject -Property @{context=$context;psInst=$psInst}
}
<#
function createAssemblyPaths($rsCount){
  $rm = Get-ChildItem "$PSScriptRoot\assemblies" | ? {$_.Name -ne "master"} | Remove-Item -Recurse -Force
  for($i = 0; $i -lt $rsCount; $i++){
    $af = New-Item -ItemType Directory "$PSScriptRoot\assemblies\$($i + 1)"
    $cf = Copy-Item -Path "$PSScriptRoot\assemblies\master\*" -Destination "$PSScriptRoot\assemblies\$($i + 1)" -Recurse -Force
  }
}

createAssemblyPaths $maxRun
#>

$cleanCycle = 0
do{
  "Runspace Flow: Listening" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force
  $conTemp = $listener.GetContext()
  "Runspace Flow: Context Captured / Assigning Context" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force
  assignContext -conTemp $conTemp
  "Runspace Flow: Context Assigned / Starting Runspace" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force
  startRunspace -runspace $runspace -enc $enc
  if($cleanCycle -ge 2){
    "Runspace Flow: Starting Cleanup" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force
    $cleanCycle = 0
    $cleanData = cleanup -context $context -psInst $psInst
    $context = $cleanData.context
    $psInst = $cleanData.psInst
    "Runspace Flow: Cleanup Complete" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force
  }
  $cleanCycle++
}
while($true)

# SIG # Begin signature block
# MIIHuwYJKoZIhvcNAQcCoIIHrDCCB6gCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUjdbJ20N8z1h2Gyn6DdmIDAno
# uLqgggUrMIIFJzCCBM2gAwIBAgIKZ5YFbgAAAABWmjAKBggqhkjOPQQDAjBLMRUw
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
# DQEJBDEWBBR3fEiYZ1/DBDhe2HDQfj6gPcCGFDANBgkqhkiG9w0BAQEFAASCAQCd
# aI3YjuTHDL4fUzjmwrdKCyna39jM24F+MaXpktIwm/0rTcFNodIHczT6ydeyKXQr
# 0fRGCs1WBXVPUeDktAQYRKmN7o7Q7g06jUh6LLhF2yGpWux8JCs9Tw3Sd4fLVBiU
# 8rSrJLlDHx1dvyUkcF87fHrBkd81kf0c1xcJtasD20tMcx43YCtDucsVuI0mynsm
# sKn5a4ZRlINgx+XqkLn24yyeSgE752fkZP9a5ki4lKUpy/pwvIOu7DfFDCQvVH/U
# qZPkbGFPxrnIv6X4m/qUqSqOM1fp+HG4VPqWmV1iYJY9djkkPWmonTkE44W+b2Ou
# 4aaeaVTjRZgc1+ZzBW8y
# SIG # End signature block
