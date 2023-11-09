Write-Host -f Cyan "Tablet Logon Tracker"

Stop-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\tabletLogonTracker--PID.txt") -ErrorAction SilentlyContinue
$PID | Set-Content C:\Automation\AutoServerMonitor\tabletLogonTracker--PID.txt -Force
$host.UI.RawUI.WindowTitle = "tabletLogonTracker"

$dcSess = New-PSSession -ComputerName I-DC-02
$null = Import-PSSession -Session $dcSess -CommandName "Get-ADComputer" -DisableNameChecking -AllowClobber

while(1){
  $rotData = Import-Csv C:\Automation\HelpDeskHub\rotationData.csv
  if((Get-Date) -le ([DateTime]::Parse($rotData.RotationEnd))){
    $allComps = @()
    Get-ADComputer -Filter * -Properties lastLogon | ? {$_.Name -like "CTCS*"} | % {$allComps += (New-Object PSCustomObject -Property ([ordered]@{Name=$_.Name;LastLogon=([DateTime]::FromFileTime($_.lastLogon))}))}
    $rotLogons = $allComps | ? {$_.LastLogon -ge ([DateTime]::Parse($rotData.RotationStart)) -and $_.LastLogon -le ([DateTime]::Parse($rotData.RotationEnd))}
    "`"Rotation`",`"CTCSD`",`"CTCSM`",`"CTCSR`",`"LastUpdate`"`n`"$($rotData.RotationName)`",`"$(($rotLogons | ? {$_.Name -like "CTCSD*"}).Length)`",`"$(($rotLogons | ? {$_.Name -like "CTCSM*"}).Length)`",`"$(($rotLogons | ? {$_.Name -like "CTCSR*"}).Length)`",`"$((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt"))`"" | Set-Content C:\Automation\HelpDeskHub\rotationTabletLogonSummary.csv -Force
  }
  sleep (60 * 60)
}