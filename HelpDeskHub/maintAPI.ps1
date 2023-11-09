Write-Host -f Cyan "Maintenance API"

Stop-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\maintAPI--PID.txt") -ErrorAction SilentlyContinue
$PID | Set-Content C:\Automation\AutoServerMonitor\maintAPI--PID.txt -Force
$host.UI.RawUI.WindowTitle = "maintAPI"

$sessionTimeout = 30
$authUsers = @("derek.poe.sa","james.roberts.sa","diandra.burk.sa","kenny.grevemberg.sa","mathew.morris.sa","barron.williams.sa","robert.hood.sa","zelda.rogers.sa","zakk.rogerson.sa","john.millender.sa","quincy.courtney.sa","isidro.holguin.sa","heath.jewett.sa")

$listener = New-Object System.Net.HttpListener
$apiPort = 1327
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

while($true){
  $apiKey = "v190b2712uysgdi"
  $context = $listener.GetContext()
  $requester = $context.Request.RemoteEndPoint
  $request = $context.Request.RawUrl
  "MAINT_API $((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: $requester -- $request" | Add-Content -Force -Path c:\Automation\HelpDeskHub\maint_web.log
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
    if((checkLogin $reqSess)){
      #Write-Host "passed check: $($request -join "/")"
      switch($request[1]){

        "autoServerMonitor" {
          $content = Get-Content -Encoding Byte -Path C:\Automation\AutoServerMonitor\ep_autoServerMonitorPageFull.html
          $context.Response.OutputStream.Write($content,0,$content.Length)
          break
        }

        "resourceStats" {
          $byteMess = $enc.GetBytes((Import-Csv C:\Automation\AutoServerMonitor\resourceStats.csv | ConvertTo-JSON))
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          break
        }

        "restartAllServices" {
          #ps -id (cat C:\Automation\AutoServerMonitor\everythingChaperone--PID.txt) | kill -Force
          ps powershell | ? {$_.Id -ne $PID} | kill -f
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
            "resourceDataBuilder",
            "everythingAPI",
            "adAPI",
            "solarwindsAPI",     
            "everythingAlertMonitor",   
            "autoRDPSessionConversion",
            "apiHangCheck",
            "tabletLogonTracker",
            "maintAPI"
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
  }
  elseIf($request[0] -eq "AutoServerManagement"){
    $content = Get-Content -Encoding Byte -Path C:\Automation\HelpDeskHub\autoServerManagementLoginPage.html
    $context.Response.OutputStream.Write($content,0,$content.Length)
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
  #####################################
  elseIf($request[0] -eq "favicon.ico"){
    $content = Get-Content -Encoding Byte -Path C:\Automation\HelpDeskHub\favicon.ico
    #$content = [Convert]::ToBase64String($content)
    $context.Response.OutputStream.Write($content,0,$content.Length)
  }
  else{
    $context.Response.StatusCode = 404;
  }
  $context.Response.Close()
  Start-Sleep -Milliseconds 50
}
