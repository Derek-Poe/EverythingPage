Write-Host -f Cyan "Everything API"

Stop-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\everythingAPI--PID.txt") -ErrorAction SilentlyContinue
$PID | Set-Content C:\Automation\AutoServerMonitor\everythingAPI--PID.txt -Force
$host.UI.RawUI.WindowTitle = "everythingAPI"

$sessionTimeout = 30
$authUsers = @("derek.poe.sa","james.roberts.sa","diandra.burk.sa","kenny.grevemberg.sa","mathew.morris.sa","barron.williams.sa","robert.hood.sa","zelda.rogers.sa","zakk.rogerson.sa","john.millender.sa","quincy.courtney.sa","isidro.holguin.sa","heath.jewett.sa")

$listener = New-Object System.Net.HttpListener
$apiPort = 1320
#$hostName = "$env:COMPUTERNAME.ctcis.local"
#$hostName = "127.0.0.1"
$hostName = "$env:COMPUTERNAME.is-u.jrtc.army.mil"
#$listener.Prefixes.Add("http://$hostName`:$apiPort/")
$listener.Prefixes.Add("https://$hostName`:$apiPort/")
#$listener.Prefixes.Add("http://10.2.6.1:$apiPort/")
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
  #"Runspace Flow ::$currentRS:: Login -- $user" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force
  return $enc.GetString((Invoke-WebRequest -UseBasicParsing -Uri "https://127.0.0.1:9740/2k3b4j2h4j5tb/LI" -Method POST -Body $user).Content)
}

function checkLogin($session){
  #"Runspace Flow ::$currentRS:: Check Login -- $session" | Add-Content C:\Automation\IPU\runspaceDebug.txt -Force
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
  $apiKey = "v29b4v293uhgfqy"
  $adApiKey = "q8nwv7r90qw87er"
  $adApiPort = 1322
  $context = $listener.GetContext()
  $execStart = Get-Date
  $requester = $context.Request.RemoteEndPoint
  $request = $context.Request.RawUrl
  "EP_API $((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: $requester -- $request" | Add-Content -Force -Path c:\Automation\HelpDeskHub\ep_web.log
  $request = $request.Substring(1,$request.Length-1)
  if($request -like "*?*"){
    $request = $request -split "\?"
  }
  $request = $request.split("/")
  if($request -isnot [array]){
    $request = @($request)
  }
  $reqSess = $null
  $byteMess = $null
  if(($context.Request.Cookies | ? {$_.Name -eq "ipuSess"}) -ne $null){
    $reqSess = ($context.Request.Cookies | ? {$_.Name -eq "ipuSess"}).Value.Trim()
  }
  #write-Host "$reqSess $($request[0]) $($request -join "/")"
  if($request[0] -eq $apiKey){
    if((checkLogin $reqSess) -or $request[1] -like "IPURR*" -or $reqSess -eq "2O2KHyBfBrXl1vUnF31yqeQY"){
      #Write-Host "passed check: $($request -join "/")"
      switch($request[1]){

        "getEverythingPage" {
          $content = Get-Content -Encoding Byte -Path C:\Automation\HelpDeskHub\everythingPageFull.html
          $context.Response.OutputStream.Write($content,0,$content.Length)
          break
        }

        "landingPage" {
          $content = Get-Content -Encoding Byte -Path C:\Automation\HelpDeskHub\landingPage.html
          $context.Response.OutputStream.Write($content,0,$content.Length)
          break
        }

        "accountManagement" {
          $content = Get-Content -Encoding Byte -Path C:\Automation\HelpDeskHub\ep_accMgmtPage.html
          $context.Response.OutputStream.Write($content,0,$content.Length)
          break
        }

        "accountSearch" {
          $content = Get-Content -Encoding Byte -Path C:\Automation\HelpDeskHub\ep_accSearchPage.html
          $context.Response.OutputStream.Write($content,0,$content.Length)
          break
        }

        "swSyslogSearch" {
          $content = Get-Content -Encoding Byte -Path C:\Automation\HelpDeskHub\ep_swSyslogSearch.html
          $context.Response.OutputStream.Write($content,0,$content.Length)
          break
        }

        "shiftSummary" {
          $content = Get-Content -Encoding Byte -Path C:\Automation\HelpDeskHub\ep_shiftSummaryPage.html
          $context.Response.OutputStream.Write($content,0,$content.Length)
          break
        }

        "autoServerMonitor" {
          $content = Get-Content -Encoding Byte -Path C:\Automation\AutoServerMonitor\ep_autoServerMonitorPageFull.html
          $context.Response.OutputStream.Write($content,0,$content.Length)
          break
        }

        "accountBuilder" {
          $content = Get-Content -Encoding Byte -Path C:\Automation\HelpDeskHub\ep_accountBuilderPage.html
          $context.Response.OutputStream.Write($content,0,$content.Length)
          break
        }

        "EverythingPageWorkspace" {
          $content = Get-Content -Encoding Byte -Path C:\Automation\HelpDeskHub\everythingPageWorkspace.html
          $context.Response.OutputStream.Write($content,0,$content.Length)
          break
        }

        "debugPage" {
          $content = Get-Content -Encoding Byte -Path C:\Automation\HelpDeskHub\debugPage.html
          $context.Response.OutputStream.Write($content,0,$content.Length)
          break
        }

        "ad" {
          ##Write-Host -f Yellow "$requester -- $request -- $((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt"))"
          #$adApiKey = Get-Content \\fileshare01\home\dpoe\CRM\adApiKey.txt
          #$adApiKey = Get-Content C:\Automation\CRM\adApiKey.txt
          #$adApiKey = "q8nwv7r90qw87er"
          #$adApiPort = Get-Content \\fileshare01\home\dpoe\CRM\adApiPort.txt
          #$adApiPort = Get-Content C:\Automation\CRM\adApiPort.txt   
          #$adApiPort = 1322
          if($context.Request.HttpMethod -eq "PUT"){
            $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
            $body = $bodyRead.ReadToEnd()
            #Write-Host "http://127.0.0.1:$adApiPort/$adApiKey/$($request[2]) -- Hopping: $body"
            $hopReq = Invoke-WebRequest -Uri "http://127.0.0.1:$adApiPort/$adApiKey/$($request[2])" -Method Put -Body $body
            if($hopReq.Content.length -gt 0){
              $context.Response.OutputStream.Write($hopReq.Content,0,$hopReq.Content.Length)
              #$context.Response.Close()
            }
            else{
              #$context.Response.Close()
            }
          }
          else{
            $hopReq = Invoke-WebRequest -Uri "http://127.0.0.1:$adApiPort/$adApiKey/$($request[2])" -Method Get
            if($hopReq.Content.length -gt 0){
              $context.Response.OutputStream.Write($hopReq.Content,0,$hopReq.Content.Length)
              #$context.Response.Close()
            }
            else{
              #$context.Response.Close()
            }
          }
          break
        }

        "getAlerts" {
          <#
          $activeSWAlerts = Import-Csv C:\Automation\HelpDeskHub\temp\currentSWActiveAlerts.csv
          $activeSWAlertsObjects = Import-Csv C:\Automation\HelpDeskHub\temp\currentSWActiveAlertsObjects.csv
          $alertsStatus = Import-Csv C:\Automation\HelpDeskHub\temp\currentAlertsStatus.csv
          $alerts = @()
          $date = (Get-Date).ToUniversalTime()
          #$activeSWAlertsObjects = $activeSWAlertsObjects | Sort LastTriggeredDateTime -Descending 
          forEach($alert in $activeSWAlertsObjects){
            $activeTime = New-TimeSpan ([DateTime]::Parse($alert.LastTriggeredDateTime)) $date
            if($activeTime.Days -gt 0){
              $activeTime = "$($activeTime.Days)d $($activeTime.Hours)h $($activeTime.Minutes)m"
            }
            elseIf($activeTime.Hours -gt 0){
              $activeTime = "$($activeTime.Hours)h $($activeTime.Minutes)m"
            }
            else{
              $activeTime = "$($activeTime.Minutes)m"
            }
            if($alert.AlertNote.Length -gt 0){
              $notes = "..."
            }
            else{
              $notes = ""
            }
            $props = [ordered]@{
              AlertID = "$(($activeSWAlerts | ? {$_.AlertObjectID -eq $alert.AlertObjectID}).AlertActiveID)<~>$(($activeSWAlerts | ? {$_.AlertObjectID -eq $alert.AlertObjectID}).AlertObjectID)"
              AlertURI = "/Orion/NetPerfMon/ActiveAlertDetails.aspx?NetObject=AAT:$($alert.AlertObjectID)"
              ObjectURI = $alert.EntityDetailsUrl
              NodeURI = $alert.RelatedNodeDetailsUrl
              NotesData = $alert.AlertNote
              LastTriggeredDate = [DateTime]::Parse($alert.LastTriggeredDateTime)
              Alert = ($activeSWAlerts | ? {$_.AlertObjectID -eq $alert.AlertObjectID}).TriggeredMessage
              Object = $alert.EntityCaption
              TimesTriggered = $alert.TriggeredCount
              LastTriggered = $activeTime
              Node = $alert.RelatedNodeCaption
              AcknowledgedBy = ($activeSWAlerts | ? {$_.AlertObjectID -eq $alert.AlertObjectID}).AcknowledgedBy
              Notes = $notes
              Silenced = ($alertsStatus | ? {$_.AlertObjectId -eq $alert.AlertObjectId}).Silenced
            }
            $alerts += New-Object PSCustomObject -Property $props
          }
          $alerts = $alerts | Sort LastTriggeredDate -Descending
          #>
          $alerts = Import-Csv C:\Automation\HelpDeskHub\alertsData.csv
          $byteMess = $enc.GetBytes(((checkLength ($alerts | ? {$_.Silenced -eq $false})) -as [String]) + "<~~~>" + ($alerts | ConvertTo-JSON))
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          break
        }

        "silenceAlarm" {
          $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
          $alarm = $bodyRead.ReadToEnd()
          $null = Invoke-WebRequest "http://127.0.0.1:1321/29nb83werhtweh/updateAlerts/$($request[2])" -Method PUT -Body $alarm

          $null = Invoke-WebRequest http://127.0.0.1:1321/29nb83werhtweh/updateAlertsData

          break
        }

        "alarm.wav" {
          $content = Get-Content -Encoding Byte -Path C:\Automation\HelpDeskHub\alarm.wav
          #$content = [Convert]::ToBase64String($content)
          $context.Response.OutputStream.Write($content,0,$content.Length)
          break
        }

        "warning.wav" {
          $content = Get-Content -Encoding Byte -Path C:\Automation\HelpDeskHub\warning.wav
          $context.Response.OutputStream.Write($content,0,$content.Length)
          break
        }

        "newNote.wav" {
          $content = Get-Content -Encoding Byte -Path C:\Automation\HelpDeskHub\newNote.wav
          $context.Response.OutputStream.Write($content,0,$content.Length)
          break
        }

        "syslogSearchSubmit" {         
          $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
          $body = $bodyRead.ReadToEnd()
          #Write-Host "http://127.0.0.1:$adApiPort/$adApiKey/$($request[2]) -- Hopping: $body"
          $hopReq = Invoke-WebRequest -Uri "http://127.0.0.1:1321/29nb83werhtweh/syslogSearch" -Method Put -Body $body
          $context.Response.OutputStream.Write($hopReq.Content,0,$hopReq.Content.Length)              
          break
        }

        "swAlertNotesEdit" {         
          $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
          $body = $bodyRead.ReadToEnd()
          $hopReq = Invoke-WebRequest -Uri "http://127.0.0.1:1321/29nb83werhtweh/alertNotesEdit" -Method Put -Body $body
          $context.Response.OutputStream.Write($hopReq.Content,0,$hopReq.Content.Length)              
          break
        }

        "swAcknowledgeAlert" {         
          $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
          $bodyContent = $bodyRead.ReadToEnd()
          $hopReq = Invoke-WebRequest -Uri "http://127.0.0.1:1321/29nb83werhtweh/acknowledgeAlert" -Method Put -Body "$(getSessionUser $reqSess)<~>$bodyContent"
          $context.Response.OutputStream.Write($hopReq.Content,0,$hopReq.Content.Length)              
          break
        }

        "removeDownNeighborAlerts" {         
          $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
          $bodyContent = $bodyRead.ReadToEnd()
          $req = Invoke-WebRequest -Uri "http://127.0.0.1:1321/29nb83werhtweh/removeDownNeighborAlerts" -Method Get             
          break
        }

        "shiftSummaryData" {
          $pack = New-Object PSCustomObject
          $pack | Add-Member NoteProperty "SW Unacknowledged Alerts" (((Import-Csv C:\Automation\HelpDeskHub\temp\currentSWActiveAlerts.csv) | ? {$_.AcknowledgedBy -eq ""}).Length)
          $pack | Add-Member NoteProperty "Legacy IPU Count" (Get-Content C:\Automation\IPU\instrDataLength.txt).ToString()
          #$tceLt2 = Import-Csv (Get-ChildItem C:\Automation\IPU\temp | ? {$_.Name -like "IPU_Compare_*_summary.csv"}).FullName
          #$pack | Add-Member NoteProperty "TCE / LT2 Entities" "$($tceLt2.tceDataCount) / $($tceLt2.lt2DataCount)"
          #$pack | Add-Member NoteProperty "Last IPU Report **Will Change" ((ls "\\i-file\jrtc\TACSS\IPU Report" | ? {!$_.PSIsContainer -and $_.Name -like "*IPU Reporting Rates*"} | Sort LastWriteTime -Descending)[0].LastWriteTime.ToString("hh:mm:ss tt - MM/dd/yyyy"))
          $instrCount = Import-Csv C:\Automation\IPU\instrCommsCount.csv
          $pack | Add-Member NoteProperty "Instrumentation Count" "$($instrCount.In) / $($instrCount.Out) :: $([int]$instrCount.In + [int]$instrCount.Out)"
          $pack | Add-Member NoteProperty "Last IPU Report" (Get-Content C:\Automation\IPU\ep_IPUReportSummary.txt)
          #$pack.'Last IPU Report' = $pack.'Last IPU Report' -join "`r`n"
          $pack.'Last IPU Report' = $pack.'Last IPU Report' -join "<br/>"
          $tabLogSum = Import-Csv C:\Automation\HelpDeskHub\rotationTabletLogonSummary.csv
          #$pack | Add-Member NoteProperty "Tablet Logons" "$($tabLogSum.Rotation)`r`nCTCSD - $($tabLogSum.CTCSD)`r`nCTCSM - $($tabLogSum.CTCSM)`r`nCTCSR - $($tabLogSum.CTCSR)`r`n$($tabLogSum.LastUpdate)"
          $pack | Add-Member NoteProperty "Tablet Logons" "$($tabLogSum.Rotation)<br/><br/>CTCSD - $($tabLogSum.CTCSD)<br/>CTCSM - $($tabLogSum.CTCSM)<br/>CTCSR - $($tabLogSum.CTCSR)<br/><br/>$($tabLogSum.LastUpdate)"
          #$pack | Add-Member NoteProperty "This Data Last Updated" (Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")
          $byteMess = $enc.GetBytes(($pack | ConvertTo-JSON))
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          break
        }

        "maintenanceStatus" {
          $byteMess = $enc.GetBytes((Import-Csv C:\Automation\HelpDeskHub\maintenanceStatus.csv | ConvertTo-JSON))
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          break
        }

        "resourceStats" {
          $byteMess = $enc.GetBytes((Import-Csv C:\Automation\AutoServerMonitor\resourceStats.csv | ConvertTo-JSON))
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          break
        }

        "getFirstName" {
          #$byteMess = $enc.GetBytes(($enc.GetString(((Invoke-WebRequest -Uri "http://127.0.0.1:$adApiPort/$adApiKey/getFirstName/$(getSessionUser $reqSess)")).Content)))
          $byteMess = (Invoke-WebRequest -Uri "http://127.0.0.1:$adApiPort/$adApiKey/getFirstName/$(getSessionUser $reqSess)").Content
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          break
        }

        "restartAllServices" {
          ps -id (cat C:\Automation\AutoServerMonitor\everythingChaperone--PID.txt) | kill -Force
          Start-Process "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" "C:\Automation\HelpDeskHub\everythingChaperone.ps1"
          break
        }

        "restartSitebossHub" {
          $pidwl = @(
            "sitebossPoller",
            "sitebossAPI",
            "sitebossHistoryBuilder",
            "sitebossSyslogBuilder"
          )
          forEach($pro in $pidwl){
            ps -Id (cat "C:\Automation\AutoServerMonitor\$pro--PID.txt") | kill -Force
          }
          break
        }

        "restartIPUOTA" {
          $pidwl = @(
            "IPURR_DataBuilder",
            "WebSessionAPI",
            "IPUAPI",
            "IPUOTADataBuilder_multiInstance",
            "IPUOTAResultsAPI",
            "IPUOTATracker",
            "IPUOTAAuto",
            "IPUOTAServerDataAutoReload"
          )
          forEach($pro in $pidwl){
            ps -Id (cat "C:\Automation\AutoServerMonitor\$pro--PID.txt") | kill -Force
          }
          break
        }

        "restartEverythingServices" {
          $pidwl = @(
            "everythingAPI",
            "resourceDataBuilder",
            "adAPI",
            "solarwindsAPI",     
            "everythingAlertMonitor",   
            "autoRDPSessionConversion"
          )
          forEach($pro in $pidwl){
            ps -Id (cat "C:\Automation\AutoServerMonitor\$pro--PID.txt") | kill -Force
          }
          break
        }

        "restartAuto1" {
          shutdown -r -t 0 -f
          break
        }

        "teamNotes" {
          $notes = cat C:\Automation\HelpDeskHub\teamNotes.csv | ConvertFrom-Csv | Sort {[int]$_.ID} -Descending 
          $byteMess = $enc.GetBytes(($notes | ConvertTo-JSON))
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          break
        }

        "teamNotesSubmit" {
          $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
          $bodyContent = $bodyRead.ReadToEnd()
          $teamNote = $bodyContent | ConvertFrom-JSON
          $pos = [int](Import-Csv C:\automation\HelpDeskHub\teamNotes.csv | Select Id | Sort {[int]$_.Id} -Descending)[0].Id + 1
          $pos | Set-Content C:\Automation\HelpDeskHub\teamNotesPos.txt -Force
          "`"$pos`",`"$($teamNote.User)`",`"$($teamNote.Note)`",`"$(([DateTime]::Parse($teamNote.Time)).ToString("MM/dd/yyyy hh:mm:ss tt"))`"" | Add-Content C:\Automation\HelpDeskHub\teamNotes.csv -Force
          break
        }

        "teamNotesPos" {
          $byteMess = $enc.GetBytes((cat C:\Automation\HelpDeskHub\teamNotesPos.txt))
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          break
        }

        "userTeamNotesPos" {
          $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
          $bodyContent = $bodyRead.ReadToEnd()
          $userData = $bodyContent.Split(",")
          $allUserPos = Import-Csv C:\Automation\HelpDeskHub\teamNotesUserPos.csv
          if($userData[0] -eq "get"){
            $userPos = ($allUserPos | ? {$_.User -eq $userData[1]}).Position
            #msg * /server:10.2.6.11 "UserPosCon: $($userPos -ne $null); UserPos: $($userPos)"
            if($userPos -ne $null){
              $pos = $userPos
            }
            else{
              $pos = [int](Import-Csv C:\automation\HelpDeskHub\teamNotes.csv | Select Id | Sort {[int]$_.Id})[0].Id - 1
              "`"$($userData[1])`",`"$pos`"" | Add-Content C:\Automation\HelpDeskHub\teamNotesUserPos.csv -Force
            }
            $byteMess = $enc.GetBytes($pos)
            $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          }
          elseIf($userData[0] -eq "set"){
            ($allUserPos | ? {$_.User -eq $userData[1]}).Position = $userData[2]
            $allUserPos | Export-Csv C:\Automation\HelpDeskHub\teamNotesUserPos.csv -Force -NoTypeInformation
          }
          break
        }

        "lc" {
          if(checkLogin $reqSess){
            $byteMess = $enc.GetBytes("LI")
            $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          }
          else{
            $byteMess = $enc.GetBytes("NLI")
            $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          }
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
    if(checkCredentials $cr[0].Trim() $cr[1].Trim()){
      $byteMess = $enc.GetBytes((loginUser ($cr[0].Trim())))
      $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
    }
    else{
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
  }<#
  elseIf($request[0] -eq "IPURR"){
    $content = Get-Content -Encoding Byte -Path C:\Automation\IPU\IPURRpage.html
    $context.Response.OutputStream.Write($content,0,$content.Length)
  }
  elseIf($request[0] -eq "IPUOTA"){
    $content = Get-Content -Encoding Byte -Path C:\Automation\IPU\IPUOTApage.html
    $context.Response.OutputStream.Write($content,0,$content.Length)
  }
  elseIf($request[0] -eq "TCELT2Comp"){
    $content = Get-Content -Encoding Byte -Path C:\Automation\IPU\TCELT2CompPage.html
    $context.Response.OutputStream.Write($content,0,$content.Length)
  }#>
  elseIf($request[0] -eq "TheEverythingPage"){
    $content = Get-Content -Encoding Byte -Path C:\Automation\HelpDeskHub\everythingPage.html
    $context.Response.OutputStream.Write($content,0,$content.Length)
  }
  elseIf($request[0] -eq "hangCheck"){
    $byteMess = $enc.GetBytes("Alive")
    $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
  }
  #####################################
  #elseIf($request[0] -eq "superDebug"){
  #  $content = Get-Content -Encoding Byte -Path C:\Automation\HelpDeskHub\everythingPageFull.html
  #  $context.Response.OutputStream.Write($content,0,$content.Length)
  #}
  #elseIf($request[0] -eq "ultraDebug"){
  #  $content = Get-Content -Encoding Byte -Path "C:\Automation\$(($request[1] -split "~~")[1] -replace "~","\")"
  #  $context.Response.OutputStream.Write($content,0,$content.Length)
  #}
  #elseIf($request[0] -eq "image"){
  #  $content = Get-Content -Encoding Byte -Path "C:\Automation\22.4_CTCSD.tib"
  #  $context.Response.OutputStream.Write($content,0,$content.Length)
  #}
  #####################################
  elseIf($request[0] -eq "chaperoneCheckin"){
    #Do Nothing...
  }
  elseIf($request[0] -eq "favicon.ico"){
    $content = Get-Content -Encoding Byte -Path C:\Automation\HelpDeskHub\favicon.ico
    #$content = [Convert]::ToBase64String($content)
    $context.Response.OutputStream.Write($content,0,$content.Length)
  }
  else{
    $context.Response.StatusCode = 404;
  }
  $context.Response.Close()
  "`"$($execStart.ToString("MM/dd/yyyy hh:mm:ss"))`",`"$($request -join "/")`",`"$requester`",`"$((New-TimeSpan $execStart (Get-Date)).ToString())`"" | Add-Content C:\Automation\HelpDeskHub\execTimeDebug.csv -Force
  Start-Sleep -Milliseconds 50
}
