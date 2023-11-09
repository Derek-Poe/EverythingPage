Write-Host -f Cyan "Siteboss Syslog Builder"

$PID | Set-Content C:\Automation\AutoServerMonitor\sitebossSyslogBuilder--PID.txt -Force
$host.UI.RawUI.WindowTitle = "sitebossSyslogBuilder"

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
$enc = [System.Text.Encoding]::ASCII

while($true){
  $entsCol = (Get-Content -Tail 10000 (Get-ChildItem \\I-MGMT\f$\SYSLOGS-LIVE\ | ? {$_.Name -like "*Siteboss*"} | Sort LastWriteTime -Descending | Select -First 1).FullName).Split("`n")
  $ents = @()
  forEach($ent in $entsCol){
    if($ent -like "*This is a test message from Kiwi Syslog Server*"){
      $ents += New-Object PSCustomObject -Property ([ordered]@{Date=[DateTime]::Parse(($ent -replace "`t","~" -replace " :: ","~").Split("~")[0]);Site="Kiwi";Alarm="Test";Severity="-";Status="Message"})
    }
    else{
      $ent = ($ent -replace "`t","~" -replace " :: ","~").Split("~")
      if(!($ent[2] -like "*MAN*")){
        $ents += New-Object PSCustomObject -Property ([ordered]@{Date=[DateTime]::Parse($ent[0]);Site="$($ent[2].Split("-")[0] -replace "[a-zA-Z]" -as [int])";<#Severity=$ent[1];Hostname=$ent[2];SBDate=$ent[3];SBName=$ent[4];Carrrd=$ent[5];#>Alarm=$ent[6];Severity=$ent[7];Status=$ent[8]})
      }
      else{
        $ents += New-Object PSCustomObject -Property ([ordered]@{Date=[DateTime]::Parse($ent[0]);Site="$(($ent[2] -Split "_Siteboss")[0])";Alarm=$ent[6];Severity=$ent[1].Split(".")[1];Status=$ent[7]})
      }
    }
  }
  $ents = $ents | Sort Date -Descending
  $genMess = $ents | ? {$_.Alarm -like "*generator*" -and $_.Site -notlike "*MAN*"} | Sort Status,Site
  $genRunsFC = Import-Csv C:\Automation\SitebossHub\LatestGeneratorRuns.csv
  $genRuns = @()
  $genRunsFC | % {$genRuns += $_}
  $altered = @()
  forEach($mess in $genMess){
    if($mess.Status -like "*ON*"){
      if((($genRuns | ? {$_.Site -eq $mess.Site}).GenON_Time -like "_NP") -or ([DateTime]::Parse($mess.Date) -gt [DateTime]::Parse(($genRuns | ? {$_.Site -eq $mess.Site}).GenON_Time))){
        ($genRuns | ? {$_.Site -eq $mess.Site}).GenON_Time = $mess.Date
        ($genRuns | ? {$_.Site -eq $mess.Site}).GenON_Propane = ($enc.GetString((Invoke-WebRequest "https://net-admin-tc215.is-u.jrtc.army.mil:9747/B3kd9a3radf3/proGet/$($mess.Site.Trim())").Content) | ConvertFrom-JSON).Propane
        $altered += $mess.Site
      }
    }
    elseIf($mess.Status -like "*OFF*"){
      if((($genRuns | ? {$_.Site -eq $mess.Site}).GenON_Time -like "_NP") -or ([DateTime]::Parse($mess.Date) -gt [DateTime]::Parse(($genRuns | ? {$_.Site -eq $mess.Site}).GenOFF_Time))){
        ($genRuns | ? {$_.Site -eq $mess.Site}).GenOFF_Time = $mess.Date
        ($genRuns | ? {$_.Site -eq $mess.Site}).GenOFF_Propane = ($enc.GetString((Invoke-WebRequest "https://net-admin-tc215.is-u.jrtc.army.mil:9747/B3kd9a3radf3/proGet/$($mess.Site.Trim())").Content) | ConvertFrom-JSON).Propane
        $altered += $mess.Site
      }
    }
  }
  $altered = $altered | Select -Unique
  forEach($site in $altered){
    if(($genRuns | ? {$_.Site -eq $site}).GenON_Propane -notlike "*_NP*"){
      if((($genRuns | ? {$_.Site -eq $mess.Site}).GenOFF_Time -like "*_NP*") -or ([DateTime]::Parse(($genRuns | ? {$_.Site -eq $site}).GenOFF_Time) -lt [DateTime]::Parse(($genRuns | ? {$_.Site -eq $site}).GenON_Time))){
        $lost = "Generator ON"
      }
      else{
        $lost = [float](($genRuns | ? {$_.Site -eq $site}).GenON_Propane -split " ")[0] - [float](($genRuns | ? {$_.Site -eq $site}).GenOFF_Propane -split " ")[0]
        if($lost -eq 0){
          $lost = "<0.1 Gallons"
        }
        else{
          $lost = "$lost Gallons"
        }
      }
      ($genRuns | ? {$_.Site -eq $site}).PropaneLost = $lost
    }
  }
  #forEach($site in $genRuns){
  #  $site.GenON_Propane = "_NP"
  #  $site.GenOFF_Propane = "_NP"
  #  $site.PropaneLost = "_NP"
  #}
  (Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt") | Set-Content C:\Automation\SitebossHub\GenRunDataDate.txt -Force
  $genRuns | Export-Csv C:\Automation\SitebossHub\LatestGeneratorRuns.csv -Force -NoTypeInformation
  $ents | Export-Csv C:\Automation\SitebossHub\activeSyslog.csv -Force -NoTypeInformation
  Start-Sleep -Seconds 10
}
#  $entsCol = (Get-Content C:\Automation\SitebossHub\temp\infrastructure\syslog-archive\SiteBoss-2021-11-05.txt).Split("`n")