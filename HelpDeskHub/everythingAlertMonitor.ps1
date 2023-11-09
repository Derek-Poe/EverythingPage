Write-Host -f Cyan "Everything Alert Monitor"

Stop-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\everythingAlertMonitor--PID.txt") -ErrorAction SilentlyContinue
$PID | Set-Content C:\Automation\AutoServerMonitor\everythingAlertMonitor--PID.txt -Force
$host.UI.RawUI.WindowTitle = "everythingAlertMonitor"

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

While($true){
  $startTime = (Get-Date)
  Write-Host "StartTime: $($startTime.ToString(`"MM/dd/yyyy hh:mm:ss tt"))" -NoNewline
  #$oldSWAlertData = Import-Csv C:\Automation\HelpDeskHub\temp\currentSWActiveAlerts.csv
  #$oldSWAlertData | Export-Csv C:\Automation\HelpDeskHub\temp\oldSWActiveAlerts.csv -NoTypeInformation -Force
  $generateSWAlertData = Invoke-WebRequest http://127.0.0.1:1321/29nb83werhtweh/generateAlertsData
  $SWAlertData = Import-Csv C:\Automation\HelpDeskHub\temp\currentSWActiveAlerts.csv
  $activeSWAlertsObjects = Import-Csv C:\Automation\HelpDeskHub\temp\currentSWActiveAlertsObjects.csv
  $alertsStatus = Import-Csv C:\Automation\HelpDeskHub\temp\currentAlertsStatus.csv
  $exempt = Import-Csv C:\Automation\HelpDeskHub\alertExemptions.csv
  if($alertsStatus.ID.Length -eq 0){
    $alertsStatus = @() ; $alertsStatus += New-Object PSCustomObject -Property ([ordered]@{AlertID="PH";AlertObjectId="PH";Silenced=$true})
  }
  $comp = Compare-Object $SWAlertData.AlertActiveID $alertsStatus.AlertID
  $addIDs = ($comp | ? {$_.SideIndicator -eq "<="}).InputObject -join ","
  $removeIDs = ($comp | ? {$_.SideIndicator -eq "=>"}).InputObject -join ","
  $exempts = @()
  forEach($ID in $addIDs){
    $addAlert = $SWAlertData | ? {$_.AlertActiveID -eq $ID}
    $addObj = $activeSWAlertsObjects | ? {$_.AlertObjectID -eq $addAlert.AlertObjectID}
    Write-Host -f Cyan $addObj.RelatedNodeCaption
    if($SWAlertData -ne $oldSWAlertData){
      forEach($ex in $exempt){
        if($addAlert.TriggeredMessage -like $ex.Alert){
          $color = "Green"
        }
        else{
          $color = "Yellow"
        }
        Write-Host -f $color $ex.Alert -NoNewline; Write-Host " -- " -NoNewline 
        if($addObj.EntityCaption -like $ex.Object){
          $color = "Green"
        }
        else{
          $color = "Yellow"
        }
        Write-Host -f $color $ex.Object -NoNewline; Write-Host " -- " -NoNewline 
        if($addObj.RelatedNodeCaption -like $ex.Node){
          $color = "Green"
        }
        else{
          $color = "Yellow"
        }
        Write-Host -f $color $ex.Node

        if($addAlert.TriggeredMessage -like $ex.Alert -and $addObj.EntityCaption -like $ex.Object -and $addObj.RelatedNodeCaption -like $ex.Node){
          $exempts += $ID
        }
      }
    }
  }
  $oldSWAlertData = $SWAlertData
  if(!([String]::IsNullOrWhiteSpace($addIDs))){
    $null = Invoke-WebRequest http://127.0.0.1:1321/29nb83werhtweh/updateAlerts/add -Method PUT -Body $addIDs
  }
  if($exempts.Length -gt 0){
    $null = Invoke-WebRequest http://127.0.0.1:1321/29nb83werhtweh/updateAlerts/silence -Method PUT -Body ($exempts -join ",")
  }
  if(!([String]::IsNullOrWhiteSpace($addIDs))){
    $null = Invoke-WebRequest http://127.0.0.1:1321/29nb83werhtweh/updateAlerts/remove -Method PUT -Body $removeIDs
  }

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

          #$alerts | Export-Csv C:\Automation\HelpDeskHub\alertsData.csv -NoTypeInformation -Force
          $null = Invoke-WebRequest http://127.0.0.1:1321/29nb83werhtweh/storeAlertsData -Method PUT -Body ($alerts | ConvertTo-JSON)
          #>

          $null = Invoke-WebRequest http://127.0.0.1:1321/29nb83werhtweh/updateAlertsData

  $execTime = (New-TimeSpan -Start $startTime -End (Get-Date))
  Write-Host " -- Alerts [New: $((checkLength $addIDs) - 1); Unsilenced: $((checkLength ($alertsStatus | ? {$_.Silenced -eq $false})) + (checkLength $addIDs) - 1)] -- ExecTime: $($execTime.ToString())"
  if($execTime.TotalSeconds -lt 30){
    Start-Sleep -Milliseconds (30000 - [Math]::Round($execTime.TotalMilliseconds))
  }
}