Write-Host -f Cyan "IPU API"

Stop-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\IPUAPI--PID.txt") -ErrorAction SilentlyContinue
$PID | Set-Content C:\Automation\AutoServerMonitor\IPUAPI--PID.txt -Force
$host.UI.RawUI.WindowTitle = "IPUAPI"

$sessionTimeout = 30
$authUsers = @("derek.poe.sa","james.roberts.sa","diandra.burk.sa","kenny.grevemberg.sa","mathew.morris.sa","barron.williams.sa","robert.hood.sa","zelda.rogers.sa","zakk.rogerson.sa","john.millender.sa","quincy.courtney.sa","isidro.holguin.sa","heath.jewett.sa","lauren.carruth")

$listener = New-Object System.Net.HttpListener
$apiPort = 9748
#$hostName = "$env:COMPUTERNAME.ctcis.local"
$hostName = "$env:COMPUTERNAME.is-u.jrtc.army.mil"
$listener.Prefixes.Add("https://$hostName`:$apiPort/")
$listener.Start()
$enc = [System.Text.Encoding]::ASCII

<#
[void][System.Reflection.Assembly]::LoadFrom("C:\Automation\IPU\System.Data.SQLite.dll")
$conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=C:\Automation\IPU\ws.sqlite;Persist Security Info=false;Mode=ReadWrite;")
$conn.Open()
$cmd = $conn.CreateCommand()
$dt = New-Object System.Data.DataTable


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
#>

function checkLength($in){
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

function getSessionKey(){
  $sessKey = ""
  for($i = 0; $i -lt 24; $i++){
    switch(Get-Random -Minimum 1 -Maximum 4){
      1 {
        $sessKey += "$(Get-Random -Minimum 0 -Maximum 10)"
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
  "Session Key -- $sessKey" | Add-Content C:\Automation\IPU\debugLog.txt -Force
  return $sessKey
}

function checkCredentials($u,$p){
  #"Cred Check -- $u" | Add-Content C:\Automation\IPU\testLog.txt -Force
  $adCheck = $null
  $adCheck = New-Object System.DirectoryServices.DirectoryEntry -ArgumentList "LDAP://is-u.jrtc.army.mil",$u,$p
  if($adCheck.name -ne $null -and $u -in $authUsers){
    return $true
  }
  return $false
}

<#
function loginUser($user,$cmd,$rdr,$dt){
  $userData = $null
  $query = "SELECT * FROM Sessions WHERE User LIKE '$user';"
  $cmd.CommandText = $query
  $rdr = $cmd.ExecuteReader()
  $dt.Clear() 
  $dt.Load($rdr)
  $userData = getPackedDT($dt)
  if($userData -ne $null){
    $newTime = ((Get-Date).AddMinutes($sessionTimeout)).ToString("MM/dd/yyyy hh:mm:ss tt")
    $session = getSessionKey
    $query = "UPDATE OR REPLACE Sessions SET Session = '$session', Time = '$newTime' WHERE User LIKE '$user';"
    $cmd.CommandText = $query
    $ex = $cmd.ExecuteNonQuery()
  }
  else{
    $newTime = ((Get-Date).AddMinutes($sessionTimeout)).ToString("MM/dd/yyyy hh:mm:ss tt")
    $session = getSessionKey
    $query = "INSERT INTO Sessions ([User], [Session], [Time]) VALUES ('$user', '$session', '$newTime');"
    $cmd.CommandText = $query
    $ex = $cmd.ExecuteNonQuery()
  }
  return $session
}

function checkLogin($session,$cmd,$rdr,$dt){
  $userData = $null
  $query = "SELECT * FROM Sessions WHERE Session LIKE '$session';"
  $cmd.CommandText = $query
  $rdr = $cmd.ExecuteReader()
  $dt.Clear() 
  $dt.Load($rdr)
  $userData = getPackedDT($dt)
  "Checklogin -- Session: $session ; UserData: $($userData.User)" | Add-Content C:\Automation\IPU\debugLog.txt -Force
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

function loginUser($user){
  "Runspace Flow ::$currentRS:: Login -- $user" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force
  return $enc.GetString((Invoke-WebRequest -UseBasicParsing -Uri "https://127.0.0.1:9740/2k3b4j2h4j5tb/LI" -Method POST -Body $user).Content)
}

function checkLogin($session){
  "Runspace Flow ::$currentRS:: Check Login -- $session" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force
  $result = $enc.GetString((Invoke-WebRequest -UseBasicParsing -Uri "https://127.0.0.1:9740/2k3b4j2h4j5tb/CL" -Method POST -Body $session).Content)
  if($result -eq "t"){
    return $true
  }
  else{
    return $false
  }
}

function getSessionUser($session){
  return $enc.GetString((Invoke-WebRequest -UseBasicParsing -Uri "https://127.0.0.1:9740/2k3b4j2h4j5tb/GU" -Method POST -Body $session).Content)
}

function getIPUID($ipu){
  $time = ((Get-Date).ToUniversalTime()).ToString("yyyy-MM-ddhh:mm:ss")
  $time = $time.Insert(10,"T")
  $time = $time.Insert($time.Length,".000Z")
  $instrData = Invoke-WebRequest -UseBasicParsing -Uri "http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation" -Method "POST" -Headers @{"Pragma"="no-cache"; "Sec-Fetch-Site"="same-origin"; "Origin"="http://10.224.218.12"; "Accept-Encoding"="gzip, deflate, br"; "Accept-Language"="en-US,en;q=0.9"; "User-Agent"="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36"; "Sec-Fetch-Mode"="cors"; "Accept"="application/json, text/plain, */*"; "Cache-Control"="no-cache"; "Referer"="http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation";} -ContentType "application/json" -Body "{`"queryName`":`"QueryInstrumentationWithLike`",`"header`":{`"id`":{`"uuid`":`"$((New-Guid).Guid)`",`"class`":`"ctia.data_model.HeaderId`"},`"sentTime`":`"$time`",`"actualTime`":`"$time`",`"serviceName`":`"SoaInstrumentationService`",`"userName`":`"$("TCE")`",`"host`":`"s-lctia4-102.ctcis.local`",`"class`":`"ctia.data_model.HeaderData`"},`"criteria`":[{`"name`":`"LIKE_QUERY`",`"stringValue`":`"%$ipu%`",`"class`":`"ctia.data_model.Criterion`"}],`"maxResults`":5,`"projections`":[],`"startOffset`":0,`"isRecovered`":false,`"class`":`"ctia.data_model.NamedQueryRequest`"}"
  $instrData = ($instrData.Content | ConvertFrom-Json).payload.instrumentationList
  if($instrData.id.uuid -ne $null){
    if($instrData.id.uuid -is [array]){
      return "MR"
    }
    else{
      return $instrData.id.uuid
    }
  }
  else{
    return "NF"
  }
}

function getIPUSW($ipu){
  $time = ((Get-Date).ToUniversalTime()).ToString("yyyy-MM-ddhh:mm:ss")
  $time = $time.Insert(10,"T")
  $time = $time.Insert($time.Length,".000Z")
  $instrData = Invoke-WebRequest -UseBasicParsing -Uri "http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation" -Method "POST" -Headers @{"Pragma"="no-cache"; "Sec-Fetch-Site"="same-origin"; "Origin"="http://10.224.218.12"; "Accept-Encoding"="gzip, deflate, br"; "Accept-Language"="en-US,en;q=0.9"; "User-Agent"="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36"; "Sec-Fetch-Mode"="cors"; "Accept"="application/json, text/plain, */*"; "Cache-Control"="no-cache"; "Referer"="http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation";} -ContentType "application/json" -Body "{`"queryName`":`"QueryInstrumentationWithLike`",`"header`":{`"id`":{`"uuid`":`"$((New-Guid).Guid)`",`"class`":`"ctia.data_model.HeaderId`"},`"sentTime`":`"$time`",`"actualTime`":`"$time`",`"serviceName`":`"SoaInstrumentationService`",`"userName`":`"$("TCE")`",`"host`":`"s-lctia4-102.ctcis.local`",`"class`":`"ctia.data_model.HeaderData`"},`"criteria`":[{`"name`":`"LIKE_QUERY`",`"stringValue`":`"%$ipu%`",`"class`":`"ctia.data_model.Criterion`"}],`"maxResults`":2,`"projections`":[`"ipuSoftwareVersion`"],`"startOffset`":0,`"isRecovered`":false,`"class`":`"ctia.data_model.NamedQueryRequest`"}"
  $instrData = ($instrData.Content | ConvertFrom-Json).payload.instrumentationList
  if($instrData.ipuSoftwareVersion -ne $null){
    if($instrData.ipuSoftwareVersion -is [array]){
      return "MR"
    }
    else{
      return $instrData.ipuSoftwareVersion
    }
  }
  else{
    return "NF"
  }
}

function TFToED($in){
  if($in -eq $true){
    return "Enabled"  
  }
  elseIf($in -eq $false){
    return "Disabled"
  }
  else{
    return "Error"
  }
}

#Get-Process -Id (Get-Content C:\Automation\AutoServerMonitor\IPUAPIChaperone--PID.txt) | Stop-Process
#Start-Process "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" "C:\Automation\IPU\IPUAPIChaperone.ps1"

while($true){
  $apiKey = "16dsfSFfgsf3"
  $context = $listener.GetContext()
  $requester = $context.Request.RemoteEndPoint
  $request = $context.Request.RawUrl
  "IPU_API $((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: $requester -- $request" | Add-Content -Force -Path c:\Automation\IPU\ipu_web_log.txt
  $request = $request.Substring(1,$request.Length-1)
  $request = $request.split("/")
  $reqSess = $null
  $byteMess = $null
  #$request | Add-Content C:\Automation\IPU\testLog.txt -Force
  if(($context.Request.Cookies | ? {$_.Name -eq "ipuSess"}) -ne $null){
    $reqSess = ($context.Request.Cookies | ? {$_.Name -eq "ipuSess"}).Value.Trim()
  }
  if($request[0] -eq $apiKey){
    if((checkLogin $reqSess) -or $request[1] -like "IPURR*" -or $reqSess -eq "2O2KHyBfBrXl1vUnF31yqeQY" -or $reqSess -eq "NksC6K10MElHFpj8E7OUgBJk" -or $request[1] -like "tcelt2comp" -or $request[1] -like "compOTAGet"){
      switch($request[1]){

        "IPURRSummaryData" {
          $byteMess = $enc.GetBytes((Import-Csv (Get-ChildItem "C:\Automation\IPU\temp" | ? {$_.Name -like "IPURR_DataCollection_*_summary.csv"}).FullName | ConvertTo-JSON))
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          break
        }

        "IPURRRateData" {
          $file = (Get-ChildItem "C:\Automation\IPU\temp" | ? {$_.Name -like "IPURR_DataCollection_*_$($request[2]).csv"}).FullName
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
          forEach($file in (Get-ChildItem "C:\Automation\IPU\temp" | ? {$_.Name -like "IPURR_DataCollection_*.csv"}).FullName){
            $rate = ($file.Split("_")[3]).Split(".")[0]
            if($rate -ne "summary"){
              $rates += $rate
              $ipus | Add-Member -MemberType NoteProperty -Name $rate -Value (Import-Csv $file)
              forEach($ipu in $ipus.$rate){
                $ipu.Created = [DateTimeOffset]::FromUnixTimeSeconds($ipu.Created).DateTime
              }
            }
          }
          $creationDate = (Get-Date)
          Stop-Service -Force Spooler
          $excel = New-Object -ComObject excel.application
          #$excel.Visible = $true
          $null = $excel.Workbooks.Add()
          $sheetNum = 1
          $exSheetCount = 0
          forEach($chCheck in $rates){
            if(checkLength(($ipus.($chCheck))) -gt 0){
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
            $excel.Worksheets.Item("Summary").Cells.Item($rowCount,2) = checkLength($ipus.($rate))
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
            $dataArray = New-Object "object[,]" (checkLength($ipus.($rate))),($headers.Length)
            for($i = 0; $i -lt (checkLength($ipus.($rate))); $i++){
              for($ii = 0; $ii -lt $headers.Length; $ii++){
               $dataArray[$i,$ii] = ($ipus.($rate)[$i]).((($ipus.($rate))[$i].PSObject.Properties.Name)[$ii])
              }
            }
            $excel.Worksheets.Item($sheetNum).Name = $rate
            $excel.Worksheets.Item("$rate").Cells.Item(1,1) = "IPUs -- Rate: $rate -- $($creationDate.ToString("MM/dd/yyyy"))"
            $excel.Worksheets.Item("$rate").Range($excel.Worksheets.Item("$rate").Cells.Item(2,1),$excel.Worksheets.Item("$rate").Cells.Item(2,$headers.Length)) = $headers
            $excel.Worksheets.Item("$rate").Range($excel.Worksheets.Item("$rate").Cells.Item(3,1),$excel.Worksheets.Item("$rate").Cells.Item((checkLength($ipus.($rate))) + 2, $headers.Length)) = $dataArray
            $null = $excel.Worksheets.Item("$rate").Range($excel.Worksheets.Item("$rate").Cells.Item(1,1),$excel.Worksheets.Item("$rate").Cells.Item(1,$headers.Length)).Merge()
            $null = $excel.Worksheets.Item("$rate").ListObjects.Add([Microsoft.Office.Interop.Excel.XlListObjectSourceType]::xlSrcRange, $excel.Worksheets.Item("$rate").Range($excel.Worksheets.Item("$rate").Cells.Item(2,1),$excel.Worksheets.Item("$rate").Cells.Item((checkLength($ipus.($rate))) + 2, $headers.Length)), $null, [Microsoft.Office.Interop.Excel.XlYesNoGuess]::xlYes)
            $excel.Worksheets.Item("$rate").ListObjects.Item(1).TableStyle = "TableStyleMedium15"
            $null = ($excel.Worksheets.Item("$rate").UsedRange).EntireColumn.AutoFit()
            $excel.Worksheets.Item("$rate").Cells.Item(1,1).Font.Size = 12
            $excel.Worksheets.Item("$rate").Cells.Item(1,1).Font.Color = [Microsoft.Office.Interop.Excel.XlRgbColor]::rgbWhite
            $excel.Worksheets.Item("$rate").Cells.Item(1,1).Interior.Color = [Microsoft.Office.Interop.Excel.XlRgbColor]::rgbCornflowerBlue
            $excel.Worksheets.Item("$rate").Range($excel.Worksheets.Item("$rate").Cells.Item(1,1),$excel.Worksheets.Item("$rate").Cells.Item(1,$headers.Length)).Borders.LineStyle = 1
            $excel.Worksheets.Item("$rate").Range($excel.Worksheets.Item("$rate").Cells.Item(1,1),$excel.Worksheets.Item("$rate").Cells.Item(1,$headers.Length)).Borders.Weight = [Microsoft.Office.Interop.Excel.XlBorderWeight]::xlThin
            ($excel.Worksheets.Item("$rate").UsedRange).HorizontalAlignment = [Microsoft.Office.Interop.Excel.XlHAlign]::xlHAlignCenter
            $excel.Worksheets.Item("$rate").Range($excel.Worksheets.Item("$rate").Cells.Item(3,1),$excel.Worksheets.Item("$rate").Cells.Item((checkLength($ipus.($rate))) + 2,1)).HorizontalAlignment = [Microsoft.Office.Interop.Excel.XlHAlign]::xlHAlignLeft
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

        "ep_getOTAPage" {
          $content = Get-Content -Encoding Byte -Path C:\Automation\IPU\ep_IPUOTApageFull.html
          $context.Response.OutputStream.Write($content,0,$content.Length)
          break
        }

        "instrDataPull" {
          $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
          $filData = ($bodyRead.ReadToEnd()).Split(",")
          #Page,RecordSize,SortProp,SortDirection
          $instrDataLength = Get-Content C:\Automation\IPU\instrDataLength.txt
          if((($filData[0] - 1) * $filData[1]) -lt $instrDataLength){
          #Try{
            #$instrData = Import-Clixml C:\Automation\IPU\instrData.xml
            if($filData[3] -eq "Ascending"){
              $instrData = Import-Csv C:\Automation\IPU\instrData.csv | Sort $filData[2] | Select -Skip (($filData[0] - 1) * $filData[1]) -First $filData[1]
            }
            else{
              $instrData = Import-Csv C:\Automation\IPU\instrData.csv | Sort $filData[2] -Descending | Select -Skip (($filData[0] - 1) * $filData[1]) -First $filData[1]
            }
            $byteMess = $enc.GetBytes(($instrData | ConvertTo-Json))
          #}
          #Catch{
          #  $byteMess = $enc.GetBytes("CTIA PROBLEM!")
          #}
          }
          elseIf($instrDataLength -eq 0){
            $byteMess = $enc.GetBytes("ND")
          }
          else{
            $byteMess = $enc.GetBytes("LP")
          }
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          break
        }

        "instrDataSearch" {
          $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
          $ipuSearch = $bodyRead.ReadToEnd()
          $instrDataLength = Get-Content C:\Automation\IPU\instrDataLength.txt      
          $search = $null
          $search = Import-Csv C:\Automation\IPU\instrData.csv | ? {$_.serialNumber -like "*$ipuSearch*"}
          if($search -ne $null){
            if($search.Length -le 25){
              $byteMess = $enc.GetBytes(($search | ConvertTo-Json))
            }
            else{
              $byteMess = $enc.GetBytes("TM")
            }
          }
          else{
            $byteMess = $enc.GetBytes("NF")
          }
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          break
        }

        "instrDataReload" {
          <#
          #$exerData = ((Invoke-WebRequest -UseBasicParsing -WebSession $webSess -Uri "http://10.224.218.12:8080/ctia.exercise/exercises" -Headers @{"Pragma"="no-cache"; "Sec-Fetch-Site"="same-origin"; "Accept-Encoding"="gzip, deflate, br"; "Accept-Language"="en-US,en;q=0.9"; "User-Agent"="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36"; "Sec-Fetch-Mode"="cors"; "Accept"="application/json, text/plain, */*"; "Cache-Control"="no-cache"; "Referer"="http://10.224.218.12:8080/ctia.exercise/exercises";} -ContentType "application/json").Content) | ConvertFrom-Json
          #$exer = $exerData.payload.exercises.id.uuid
          $time = ((Get-Date).ToUniversalTime()).ToString("yyyy-MM-ddhh:mm:ss")
          $time = $time.Insert(10,"T")
          $time = $time.Insert($time.Length,".000Z")
          #$instrData = Invoke-WebRequest -UseBasicParsing -Uri "http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation" -Method "POST" -Headers @{"Pragma"="no-cache"; "Sec-Fetch-Site"="same-origin"; "Origin"="http://10.224.218.12"; "Accept-Encoding"="gzip, deflate, br"; "Accept-Language"="en-US,en;q=0.9"; "User-Agent"="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36"; "Sec-Fetch-Mode"="cors"; "Accept"="application/json, text/plain, */*"; "Cache-Control"="no-cache"; "Referer"="http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation";} -ContentType "application/json" -Body "{`"queryName`":`"QueryAllInstrumentation`",`"header`":{`"id`":{`"uuid`":`"$((New-Guid).Guid)`",`"class`":`"ctia.data_model.HeaderId`"},`"sentTime`":`"$time`",`"actualTime`":`"$time`",`"serviceName`":`"SoaInstrumentationService`",`"userName`":`"$("TCE")`",`"host`":`"s-lctia4-102.ctcis.local`",`"class`":`"ctia.data_model.HeaderData`"},`"projections`":[],`"class`":`"ctia.data_model.NamedQueryRequest`"}"
          #$instrData = $instrData = Invoke-WebRequest -UseBasicParsing -Uri "http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation" -Method "POST" -Headers @{"Pragma"="no-cache"; "Sec-Fetch-Site"="same-origin"; "Origin"="http://10.224.218.12"; "Accept-Encoding"="gzip, deflate, br"; "Accept-Language"="en-US,en;q=0.9"; "User-Agent"="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36"; "Sec-Fetch-Mode"="cors"; "Accept"="application/json, text/plain, */*"; "Cache-Control"="no-cache"; "Referer"="http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation";} -ContentType "application/json" -Body "{`"queryName`":`"QueryAllInstrumentation`",`"header`":{`"id`":{`"uuid`":`"$((New-Guid).Guid)`",`"class`":`"ctia.data_model.HeaderId`"},`"sentTime`":`"$time`",`"actualTime`":`"$time`",`"serviceName`":`"SoaInstrumentationService`",`"userName`":`"$("TCE")`",`"host`":`"s-lctia4-102.ctcis.local`",`"class`":`"ctia.data_model.HeaderData`"},`"projections`":[`"serialNumber`",`"batteryLevel`",`"bitResult`",`"timeOfLastBitResult`",`"actualDistanceReportingRate`",`"actualTimeReportingRate`",`"periodicBitRate`",`"ipuSoftwareVersion`",`"isOutOfComms`"],`"maxResults`":1000000,`"class`":`"ctia.data_model.NamedQueryRequest`"}"
          $instrData = $instrData = Invoke-WebRequest -UseBasicParsing -Uri "http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation" -Method "POST" -Headers @{"Pragma"="no-cache"; "Sec-Fetch-Site"="same-origin"; "Origin"="http://10.224.218.12"; "Accept-Encoding"="gzip, deflate, br"; "Accept-Language"="en-US,en;q=0.9"; "User-Agent"="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36"; "Sec-Fetch-Mode"="cors"; "Accept"="application/json, text/plain, */*"; "Cache-Control"="no-cache"; "Referer"="http://10.224.218.12:8080/ctia.instrumentation/query/instrumentation";} -ContentType "application/json" -Body "{`"queryName`":`"QueryAllInstrumentation`",`"header`":{`"id`":{`"uuid`":`"$((New-Guid).Guid)`",`"class`":`"ctia.data_model.HeaderId`"},`"sentTime`":`"$time`",`"actualTime`":`"$time`",`"serviceName`":`"SoaInstrumentationService`",`"userName`":`"$("TCE")`",`"host`":`"s-lctia4-102.ctcis.local`",`"class`":`"ctia.data_model.HeaderData`"},`"projections`":[`"serialNumber`",`"actualDistanceReportingRate`",`"actualTimeReportingRate`",`"ipuSoftwareVersion`"],`"maxResults`":1000000,`"class`":`"ctia.data_model.NamedQueryRequest`"}"
          $instrData = ($instrData.Content | ConvertFrom-Json).payload.instrumentationList
          #$instrData | Select serialNumber,batteryLevel,bitResult,timeOfLastBitResult,actualDistanceReportingRate,actualTimeReportingRate,periodicBitRate,ipuSoftwareVersion,isOutOfComms | Export-Clixml C:\Automation\IPU\instrDataAll.xml -Force
          $instrData | Export-Clixml C:\Automation\IPU\instrDataAll.xml -Force          
          $ICIPU = Import-Csv C:\Automation\IPU\inCommsIPUs.csv
          $instrData = $instrData | ? {$_.serialNumber -in $ICIPU.ICIPU}
          #$instrData | Select serialNumber,batteryLevel,bitResult,timeOfLastBitResult,actualDistanceReportingRate,actualTimeReportingRate,periodicBitRate,ipuSoftwareVersion,isOutOfComms | Export-Clixml C:\Automation\IPU\instrData.xml -Force
          $instrData | Export-Clixml C:\Automation\IPU\instrData.xml -Force
          (Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt") | Set-Content C:\Automation\IPU\instrDataDate.txt -Force
          #>
          $in = Invoke-WebRequest http://127.0.0.1:1482/jh23bk54jhb23/s
          break
        }

        "instrDate" {
          $byteMess = $enc.GetBytes((Get-Content C:\Automation\IPU\instrDataDate.txt))
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          break
        }

        "inCommsLength" {
          $byteMess = $enc.GetBytes((Get-Content C:\Automation\IPU\instrDataLength.txt))
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          break
        } 

        "otaSend" {
          $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
          $jso = $bodyRead.ReadToEnd() | ConvertFrom-Json
          #$jso | Add-Content C:\Automation\IPU\debugLog.txt
          $ep = New-Object System.Net.IPEndPoint([IPAddress]::Parse("10.2.17.0"),9792)
          $uc = New-Object System.Net.Sockets.UdpClient
          $enc = [System.Text.Encoding]::ASCII

          $rate = $jso.rate
          $swupBytes = $enc.GetBytes("http://10.2.2.78/rdms/ipu_upgrade_1-7-1-1_1-7-1-2_JRTC.tar.gz")
          $ipus = @()
          forEach($ipu in $jso.IPUs){
            "$ipu,$rate,$((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt"))" | Add-Content C:\Automation\IPU\otaJobs.csv -Force
            $ipus += $ipu.Split("-")[1]
          }

          #$jso.rate | Add-Content C:\Automation\IPU\debugLog.txt
          #$jso.IPUs | Add-Content C:\Automation\IPU\debugLog.txt
          #$jso | Export-Clixml C:\Automation\IPU\jsoDebug.txt -Force

          $statusUpdatePack = @()
          forEach($ipu in $ipus){
            "$ipu -- $rate" | Add-Content C:\Automation\IPU\debugLog.txt
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

                $statusUpdatePack += New-Object PSCustomObject -Property ([ordered]@{ID="UD";IPU="IPU-$ipu";Type="T -- D";Goal="15 -- 10";Complete=$false;Initiator="Unknown";Date=(Get-Date)})
                break
              }
              "30" {
                $bytes1 = @(0x08, 0x81, 0x80, 0x80, 0xf8, 0x07, 0x10, 0xa5, 0x4c, 0x18, 0x80, 0xf0, 0xff, 0xfe, 0x85, 0x2f, 0x20, 0x07, 0x2a, 0x31, 0x08, 0x02, 0x10, 0x01, 0x18, 0x01, 0x22, 0x0b, 0x49, 0x50, 0x55, 0x2d)
                $bytes2 = @(0x28, 0x00, 0x30, 0x00, 0x3a, 0x18, 0xbb, 0x01, 0x18, 0x02, 0x00, 0x00, 0x00, 0x1e, 0x00, 0x00, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x01, 0x5c, 0x32, 0x0b, 0x49, 0x50, 0x55, 0x2d)
                $bytes1 | % {$allBytes += $_}
                $ipuBytes | % {$allBytes += $_}
                $bytes2 | % {$allBytes += $_}
                $ipuBytes | % {$allBytes += $_}

                $statusUpdatePack += New-Object PSCustomObject -Property ([ordered]@{ID="UD";IPU="IPU-$ipu";Type="T -- D";Goal="30 -- 100";Complete=$false;Initiator="Unknown";Date=(Get-Date)})
                break
              }
              "300" {
                $bytes1 = @(0x08, 0x81, 0x80, 0x80, 0xf8, 0x07, 0x10, 0xa5, 0x4c, 0x18, 0xa8, 0x8e, 0xa7, 0xa4, 0x86, 0x2f, 0x20, 0x07, 0x2a, 0x31, 0x08, 0x02, 0x10, 0x01, 0x18, 0x01, 0x22, 0x0b, 0x49, 0x50, 0x55, 0x2d)   
                $bytes2 = @(0x28, 0x00, 0x30, 0x00, 0x3a, 0x18, 0xbb, 0x01, 0x18, 0x02, 0x00, 0x00, 0x01, 0x2c, 0x00, 0x00, 0x00, 0x0a, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x01, 0x11, 0x32, 0x0b, 0x49, 0x50, 0x55, 0x2d)
                $bytes1 | % {$allBytes += $_}
                $ipuBytes | % {$allBytes += $_}
                $bytes2 | % {$allBytes += $_}
                $ipuBytes | % {$allBytes += $_}

                $statusUpdatePack += New-Object PSCustomObject -Property ([ordered]@{ID="UD";IPU="IPU-$ipu";Type="T -- D";Goal="300 -- 10";Complete=$false;Initiator="Unknown";Date=(Get-Date)})
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

                $statusUpdatePack += New-Object PSCustomObject -Property ([ordered]@{ID="UD";IPU="IPU-$ipu";Type="SWUP";Goal="1.7.1.2";Complete=$false;Initiator="Unknown";Date=(Get-Date)})
                break
              } 
            } 

            $ms = $allBytes
            $send = $uc.Send($ms,$ms.Length,$ep)
            "$((Get-Date).ToString(`"MM/dd/yyyy hh:mm:ss tt")): $rate >>>> $ipu" | Add-Content C:\Automation\IPU\ota_action_log.txt -Force
          }

          $byteMess = $enc.GetBytes("Sent")
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          $initiator = $null
          $initiator = getSessionUser $reqSess
          if($initiator -ne "NF"){
            forEach($ipuWLI in $statusUpdatePack){
             $ipuWLI.Initiator = $initiator
            }
          }
          $statusUpdatePack | Export-Csv C:\Automation\IPU\temp\statusUpdatePack.csv -Force -NoTypeInformation
          $webReq = Start-Job -ScriptBlock {$statusUpdatePack = Import-Csv C:\Automation\IPU\temp\statusUpdatePack.csv; Invoke-WebRequest "http://127.0.0.1:9733/nv273904bvfd/manageWatch/add" -Method PUT -Body ($statusUpdatePack | ConvertTo-JSON)} -ArgumentList $statusUpdatePack
          #Start-Sleep -Seconds 2
          break
        }
        
        "watchGet"{
          $rxIDs = $null
          $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
          $rxIDs = $bodyRead.ReadToEnd()
          $refreshData = $false
          if($rxIDs -ne "fresh"){
            $rxIDs = $rxIDs -split ","
            $watchList = Import-Csv C:\Automation\IPU\OTAWatchlist.csv | Sort Type,Date,IPU -Descending | Select Complete,IPU,Type,Goal,Initiator,ID
            if($rxIDs -isnot [array]){
              $rxIDs = @($rxIDs)
            }
            if($watchList -isnot [array]){
              $watchList = @($watchList)
            }
            $wlPackComp = @()
            forEach($wl in $watchList){
              $wlBubbleStatus = $null
              if($wl.Complete -eq $true){
                $wlBubbleStatus = "True"
              }
              else{
                $wlBubbleStatus = "False"
              }
              $wlPackComp += "$($wl.ID)<~>$wlBubbleStatus"
            }
            #Write-Host "1:",(($rxIDs | Sort) -join ","),"2:",(($wlPackComp | Sort) -join ","),"3:",((($rxIDs | Sort) -join ",") -eq (($wlPackComp | Sort) -join ",")),"4:",$requester
            if((($rxIDs | Sort) -join ",") -ne (($wlPackComp | Sort) -join ",")){
              $refreshData = $true
            }
          }
          else{
            $watchList = Import-Csv C:\Automation\IPU\OTAWatchlist.csv | Sort Type,Date,IPU -Descending | Select Complete,IPU,Type,Goal,Initiator,ID
            $refreshData = $true
          }
          if($refreshData){
            if((checkLength $watchList) -gt 0){
              $byteMess = $enc.GetBytes(($watchList | ConvertTo-JSON))            
            }
            else{
              $byteMess = $enc.GetBytes("ND")
            }
          }
          else{
            $byteMess = $enc.GetBytes("NC")
          }
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          break
        }

        "compOTAGet"{
          $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
          $qData = $bodyRead.ReadToEnd()
          $qData = $qData -split "<~~~>"
          $compOTAList = Import-Csv C:\Automation\IPU\OTAWatchlistComplete.csv | ? {$_.Type -eq "SWUP"} | Select Date,IPU,Goal,Initiator -Last 250
          if($qData[1] -ne ($compOTAList | Select -Last 1).IPU -or $qData -eq "fresh"){
            $currentDate = (Get-Date)
            $OTAsToday = $compOTAList | ? {$_.Date -like "$(($currentDate).ToString("MM/dd/yyyy"))*"}
            $compLength = checkLength $OTAsToday
            $usersToday = $OTAsToday | Select -ExpandProperty Initiator -Unique
            $leaderboardToday = @()
            forEach($user in $usersToday){
              $userOTAs = checkLength ($OTAsToday | ? {$_.Initiator -eq $user})
              $leaderboardToday += New-Object PSCustomObject -Property ([ordered]@{User=$user;OTAs=$userOTAs})
            }
            $todaysLeader = $null
            $todaysLeader = $leaderboardToday | Sort OTAs -Descending | Select -ExpandProperty User -First 1
            if($todaysLeader -eq $null){
              $todaysLeader = "N/A"
            }
            $compOTAList = $compOTAList | Select -Last $qData[0]
            [array]::Reverse($compOTAList)
            $byteMess = $enc.GetBytes("$compLength<~~~~~>$todaysLeader<~~~~~>$(($compOTAList | ConvertTo-JSON))")
          }
          else{
            $byteMess = $enc.GetBytes("NC")
          }
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          break
        }

        "OTABotToggle"{
          $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
          $toggleAction = $bodyRead.ReadToEnd()
          $OTABotConf = Import-Csv C:\Automation\IPU\autoOTAConf.csv
          switch($toggleAction){
            "getSWUP" {
              $byteMess = $enc.GetBytes((TFToED $OTABotConf.SWUP))
              break
            }
            "enableSWUP" {
              $OTABotConf.SWUP = $true
              $byteMess = $enc.GetBytes((TFToED $OTABotConf.SWUP))
              $OTABotConf | Export-Csv C:\Automation\IPU\autoOTAConf.csv -NoTypeInformation -Force
              $intiator = getSessionUser $reqSess
              if($initiator -eq $null){
                $initiator = "Public"
              }
              "$((Get-Date).ToString(`"MM/dd/yyyy hh:mm:ss tt")): $initiator -- Activated SWUP" | Add-Content C:\Automation\IPU\ota_bot_activation_log.txt -Force
              break
            }
            "disableSWUP" {
              $OTABotConf.SWUP = $false
              $byteMess = $enc.GetBytes((TFToED $OTABotConf.SWUP))
              $OTABotConf | Export-Csv C:\Automation\IPU\autoOTAConf.csv -NoTypeInformation -Force
              $intiator = getSessionUser $reqSess
              if($initiator -eq $null){
                $initiator = "Public"
              }
              "$((Get-Date).ToString(`"MM/dd/yyyy hh:mm:ss tt")): $initiator -- Deactivated SWUP" | Add-Content C:\Automation\IPU\ota_bot_activation_log.txt -Force
              break
            }
            default {
              $byteMess = $enc.GetBytes("Error")
            }
          }
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          break
        }

        "otaBotQueueGet"{
          $queue = Import-Csv C:\Automation\IPU\temp\OTABotUpdateQueue.csv
          if((checkLength $queue) -gt 0){
            $byteMess = $enc.GetBytes(($queue| ConvertTo-JSON))
          }
          else{
            $byteMess = $enc.GetBytes("ND")
          }
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          break
        }

        "serialBotWatchlistUpdate"{
          $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
          $body = $bodyRead.ReadToEnd()
          $statusType = ($body -split "<~~~>")[0]
          $statusData = ($body -split "<~~~>")[1] -split ","
          switch($statusType){
            "add" {
              $ipuName = $statusData[0]
              $ipuAction = $statusData[1]
              $statusUpdatePack = @(); $statusUpdatePack += New-Object PSCustomObject -Property ([ordered]@{ID="UD";IPU=$ipuName;Type="Serial";Goal=$ipuAction;Complete=$false;Initiator="Serial_Bot";Date=(Get-Date)})
              $null = Invoke-WebRequest "http://127.0.0.1:9733/nv273904bvfd/manageWatch/add" -Method PUT -Body ($statusUpdatePack | ConvertTo-JSON)
              break
            }
            "complete" {
              $ipuName = $statusData[0]
              $ipuAction = $statusData[1]
              $wl = Import-Csv C:\Automation\IPU\OTAWatchlist.csv
              $ipuWLID = ($wl | ? {$_.IPU -eq $ipuName -and $_.Goal -eq $ipuAction}).ID
              $null = Invoke-WebRequest "http://127.0.0.1:9733/nv273904bvfd/statusUpdate/complete/$ipuWLID"
              break
            }
          }
        }

        "dateCheck"{
          $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
          if(([DateTime]::Parse((Get-Content C:\Automation\IPU\instrDataDate.txt))) -lt ([DateTime]::Parse(($bodyRead.ReadToEnd())))){
            $byteMess = $enc.GetBytes("GD")
          }
          else{
            $byteMess = $enc.GetBytes("BD")
          }
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          break
        }

        "tcelt2comp"{
          $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
          $dataType = $bodyRead.ReadToEnd()
          #Write-Host -f Yellow $dataType
          $compData = $null
          switch($dataType){
            "summary"{
              $compData = Import-Csv (Get-ChildItem C:\Automation\IPU\temp | ? {$_.Name -like "IPU_Compare_*_summary.csv"}).FullName
              break
            }
            "tceEnt"{
              $compData = Import-Csv (Get-ChildItem C:\Automation\IPU\temp | ? {$_.Name -like "IPU_Compare_*_tceEnt.csv"}).FullName
              break
            }
            "lt2Ent"{
              $compData = Import-Csv (Get-ChildItem C:\Automation\IPU\temp | ? {$_.Name -like "IPU_Compare_*_lt2Ent.csv"}).FullName
              break
            }
            "tceDiff"{
              $compData = Import-Csv (Get-ChildItem C:\Automation\IPU\temp | ? {$_.Name -like "IPU_Compare_*_tceDiff.csv"}).FullName
              break
            }
            "lt2Diff"{
              $compData = Import-Csv (Get-ChildItem C:\Automation\IPU\temp | ? {$_.Name -like "IPU_Compare_*_lt2Diff.csv"}).FullName
              break
            }
            default {
              $byteMess = $enc.GetBytes("INV")
            }
          }
          if($compData -ne $null){
            $byteMess = $enc.GetBytes(($compData | ConvertTo-JSON))
          }
          else{
            $byteMess = $enc.GetBytes("ND")
          }
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          break
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
    #$context.Response.Close()
  }
  elseIf($request[0] -eq "login"){
    $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
    $cr = ($bodyRead.ReadToEnd()).Split(",")
    #$cr.join(",") | Add-Content C:\Automation\IPU\testLog.txt -Force
    if(checkCredentials $cr[0].Trim() $cr[1].Trim()){
      $byteMess = $enc.GetBytes((loginUser ($cr[0].Trim())))
      $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
    }
    else{
      #$cr.join(",") + " Cred Fail" | Add-Content C:\Automation\IPU\testLog.txt -Force
      $byteMess = $enc.GetBytes("ILA")
      $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
    }
  }
  elseIf($request[0] -eq "lc"){
    if(checkLogin $reqSess){
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
  elseIf($request[0] -eq "ep_IPURR"){
    $content = Get-Content -Encoding Byte -Path C:\Automation\IPU\ep_IPURRpage.html
    $context.Response.OutputStream.Write($content,0,$content.Length)
  }
  elseIf($request[0] -eq "IPUOTA"){
    $content = Get-Content -Encoding Byte -Path C:\Automation\IPU\IPUOTApage.html
    $context.Response.OutputStream.Write($content,0,$content.Length)
  }
  elseIf($request[0] -eq "TCELT2Comp"){
    $content = Get-Content -Encoding Byte -Path C:\Automation\IPU\TCELT2CompPage.html
    $context.Response.OutputStream.Write($content,0,$content.Length)
  }
  elseIf($request[0] -eq "ep_TCELT2Comp"){
    $content = Get-Content -Encoding Byte -Path C:\Automation\IPU\ep_TCELT2CompPage.html
    $context.Response.OutputStream.Write($content,0,$content.Length)
  }
  elseIf($request[0] -eq "IPUOTAView"){
    $content = Get-Content -Encoding Byte -Path C:\Automation\IPU\IPUOTAViewPage.html
    $context.Response.OutputStream.Write($content,0,$content.Length)
  }
  #elseIf($request[0] -eq "superDebug"){
  #  $content = Get-Content -Encoding Byte -Path C:\Automation\IPU\IPUOTApageFull.html
  #  $context.Response.OutputStream.Write($content,0,$content.Length)
  #}
  elseIf($request[0] -eq "chaperoneCheckin"){
    #Do Nothing...
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
  Start-Sleep -Milliseconds 100
}

# SIG # Begin signature block
# MIIKjgYJKoZIhvcNAQcCoIIKfzCCCnsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUmCcEsSniTxWyb0VMRXtT2+vB
# Nx6gggfQMIIHzDCCBbSgAwIBAgITHwAACoAM7RE2PVdFewAAAAAKgDANBgkqhkiG
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
# SIb3DQEJBDEWBBQ2MUny5gzlyt5SrRk+7QrNJcZS3jANBgkqhkiG9w0BAQEFAASC
# AQBcitG7lY1t1d1y4H82ATi/+TOkt03jLk8jcBB9bJbBPUIErbQc6IfpIZzUgzGz
# QAbu1yRq2sYzIxng6DwNRTduoh4/UnqiUvD5bup41KKg2+2kS28zk1a1MMmtBpzA
# l+ZxmKrO+rqOklVDeskHGbHhrJ2Y0ZbfMRvfOPSRORLYaryRKfB9zoX1YMbaZX7T
# tyrfcPR8eTQKnAF6xbDZQW46yij7euSWGJW/d168lZGr2e16gk2K2Vmyv8j4fpwS
# MGHJI+WMTECbroxfhWZosdsXDInmtSU2uypPWnye3abC5COqwCv9OHxXeSXj9O7W
# /s8GU7vjk4+iX/k0jtorTc2+
# SIG # End signature block
