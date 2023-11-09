Write-Host -f Cyan "Solarwinds API"

Stop-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\solarwindsAPI--PID.txt") -ErrorAction SilentlyContinue
$PID | Set-Content C:\Automation\AutoServerMonitor\solarwindsAPI--PID.txt -Force
$host.UI.RawUI.WindowTitle = "solarwindsAPI"

$conn = New-Object System.Data.SqlClient.SqlConnection
$conn.ConnectionString = "Server = 10.224.220.10; Database = SolarWindsOrion ; Workstation ID = I-SOLARWINDS ; User ID = "+ $([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((Get-Content \\i-file\software$\RCS\Derek.Poe\Reports\reportData\sqsluk1j2br9qdhf12nbrlkhbwer.txt | ConvertTo-SecureString -Key (Get-Content \\i-file\software$\RCS\Derek.Poe\Reports\reportData\b1n9rk322ndh29dn39d.key))))) + "; Password = " + $([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((Get-Content \\i-file\software$\RCS\Derek.Poe\Reports\reportData\sqslpbr1298rh129uh3r129uh3rg.txt | ConvertTo-SecureString -Key (Get-Content \\i-file\software$\RCS\Derek.Poe\Reports\reportData\b1n9rk322ndh29dn39d.key)))))
$conn.Open()
$cmd = New-Object System.Data.SqlClient.SqlCommand
$cmd.Connection = $conn
$sqladpt = New-Object System.Data.SqlClient.SqlDataAdapter
$ds = New-Object System.Data.DataSet

$listener = New-Object System.Net.HttpListener
$apiPort = 1321
#$hostName = "$env:COMPUTERNAME.ctcis.local"
$hostName = "127.0.0.1"
$listener.Prefixes.Add("http://$hostName`:$apiPort/")
$listener.Start()
$enc = [System.Text.Encoding]::ASCII


while(1){
  $apiKey = "29nb83werhtweh"
  $context = $listener.GetContext()
  $requester = $context.Request.RemoteEndPoint
  $request = $context.Request.RawUrl
  "SW_API $((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: $requester -- $request" | Add-Content -Force -Path C:\Automation\HelpDeskHub\solarwindsAPI_web_log.log
  $request = $request.Substring(1,$request.Length-1)
  $request = $request.split("/")
  $reqSess = $null
  if($request[0] -eq $apiKey){
    switch($request[1]){

      "generateAlertsData" {
        $query = "SELECT [AlertActiveID],[AcknowledgedBy],[AcknowledgedDateTime],[AlertObjectID],[TriggeredDateTime],[TriggeredMessage] FROM [SolarWindsOrion].[dbo].[AlertActive];"
        $ds.Clear()
        $cmd.CommandText = $query
        $sqladpt.SelectCommand = $cmd
        $null = $sqladpt.Fill($ds)

        ($ds.Tables[0].Rows | Select AlertActiveID,AcknowledgedBy,AcknowledgedDateTime,AlertObjectID,TriggeredDateTime,TriggeredMessage) | Export-Csv C:\Automation\HelpDeskHub\temp\currentSWActiveAlerts.csv -NoTypeInformation -Force
        
        $query = "
        SELECT [AlertObjectID]
          ,[AlertID]
          ,[EntityCaption]
          ,[EntityDetailsUrl]
          ,[RelatedNodeCaption]
          ,[RelatedNodeDetailsUrl]
          ,[TriggeredCount]
          ,[LastTriggeredDateTime]
          ,[AlertNote]
        FROM [SolarWindsOrion].[dbo].[AlertObjects] 
        WHERE "
        forEach($record in $ds.Tables[0].Rows){
          $query += "AlertObjectID=$($record.AlertObjectID) OR "
        }
        $query = $query.Substring(0, $query.Length - 4)
        $query += ";";
        $ds.Clear()
        $cmd.CommandText = $query
        $sqladpt.SelectCommand = $cmd
        $null = $sqladpt.Fill($ds)

        ($ds.Tables[0].Rows | Select AlertObjectID,AlertID,EntityCaption,EntityDetailsUrl,RelatedNodeCaption,RelatedNodeDetailsUrl,TriggeredCount,LastTriggeredDateTime,AlertNote) | Export-Csv C:\Automation\HelpDeskHub\temp\currentSWActiveAlertsObjects.csv -NoTypeInformation -Force

        break 
      }

      "updateAlerts" {
        $activeSWAlerts = Import-Csv C:\Automation\HelpDeskHub\temp\currentSWActiveAlerts.csv
        $alertsStatus = @() ; Import-Csv C:\Automation\HelpDeskHub\temp\currentAlertsStatus.csv | % {$alertsStatus += $_}
        $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
        $alertIDs = ($bodyRead.ReadToEnd()).Split(",")
        if($alertIDs -isnot [array]){
          $alertIDs = @($alertIDs)
        }
        switch($request[2]){
          "add" {
            forEach($ID in $alertIDs){
              $alertsStatus += New-Object PSCustomObject -Property ([ordered]@{AlertID=$ID;AlertObjectId=($activeSWAlerts | ? {$_.AlertActiveID -eq $ID}).AlertObjectID;Silenced=$false})
            }
            break
          }
          "remove" {           
            $alertsStatus = $alertsStatus | ? {$_.AlertID -notin $alertIDs}
            break
          }
          "silence" {
            forEach($alert in $alertsStatus){
              if($alert.AlertID -in $alertIDs){
                $alert.Silenced = $true
              }
            }
            break
          }
          "unsilence" {
            forEach($alert in $alertsStatus){
              if($alert.AlertID -in $alertIDs){
                $alert.Silenced = $false
              }
            }
            break
          }
        }
        $alertsStatus | Export-Csv C:\Automation\HelpDeskHub\temp\currentAlertsStatus.csv -NoTypeInformation -Force
        break
      }

      "syslogSearch" {
        $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
        $bodyContent = ($bodyRead.ReadToEnd())
        $searchType = ($bodyContent -split "<~~~>")[0]
        $searchParams = ($bodyContent -split "<~~~>")[1] -split ","
        if($searchType -eq "IP"){
          $ip = $searchParams[0]
          $sDate = [DateTime]::Parse($searchParams[1]).ToString("yyyy-MM-dd HH:mm:ss")
          $eDate = [DateTime]::Parse($searchParams[2]).ToString("yyyy-MM-dd HH:mm:ss")
          $query = "
            DECLARE @param0 datetime, @param1 datetime, @param2 varchar($([String]$ip.Length)), @olm7 nvarchar($(16 + (($ip.Split(".")) -join ",").Length))
            SELECT @param0='$sDate', @param1='$eDate', @param2='$ip', @olm7='NEAR((​$((($ip.Split(".")) -join ","))),4,TRUE)'
            SELECT TOP 100 [T1].[LogEntryID] AS LogID, [T2].[Message] AS LogMessage, [T1].[DateTime] AS LogDate, [T3].[DisplayName] AS DisplayName, [T4].IPAddress AS IPAddress, [T3].[Name] AS LogEntryName, [T1].[NodeID] AS NodeID, [T4].[Caption] AS Caption, [T5].[Name] AS SourceName, [T5].[Type] AS SourceType 
            FROM SolarWindsOrionLog.dbo.OrionLog_LogEntryView AS T1
            LEFT JOIN SolarWindsOrionLog.dbo.OrionLog_LogEntryMessageView AS T2 ON [T2].[LogEntryID] = [T1].[LogEntryID]
            LEFT JOIN SolarWindsOrionLog.dbo.OrionLog_LogEntryLevel AS T3 ON [T3].[LogEntryLevelID] = [T1].[LogEntryLevelID]
            INNER JOIN SolarWindsOrionLog.dbo.OrionLog_LogEntrySource AS T5 ON [T5].[LogEntrySourceID] = [T1].[LogEntrySourceID] AND 0 = 0
            LEFT JOIN SolarWindsOrionLog.dbo.OrionLog_LogEntryMessageSource AS T4 ON [T1].[LogEntryMessageSourceID] = [T4].[LogEntryMessageSourceID] AND 0 = 0
            LEFT JOIN SolarWindsOrionLog.dbo.LogEntryMessageContains(@olm7) AS OLMP0 ON [T1].[LogEntryID] = [OLMP0].[LogEntryID]
            WHERE [T1].DateTime >= @param0 AND [T1].DateTime <= @param1 AND [T4].IPAddress LIKE '%' + @param2 + '%'
            ORDER BY [T1].[LogEntryID] DESC;
          "
          $ds.Clear()
          $cmd.CommandText = $query
          $sqladpt.SelectCommand = $cmd
          $null = $sqladpt.Fill($ds)
          if($ds.Tables[0].Rows.Count -gt 0){
            $byteMess = $enc.GetBytes(($ds.Tables[0].Rows | Select LogID, LogMessage, LogDate, DisplayName, IPAddress, LogEntryName, NodeID, Caption, SourceName, SourceType | ConvertTo-JSON))
          }
          else{
            $byteMess = "ND"
          }
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        }
        break
      }

      "alertNotesEdit" {
        $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
        $bodyContent = ($bodyRead.ReadToEnd())
        $objectID = ($bodyContent -split "<~~>")[0]
        $objectNotes = (($bodyContent -split "<~~>")[1] -split "<~>") -join "`n"
        $query = "UPDATE [SolarWindsOrion].[dbo].[AlertObjects] SET [AlertNote]='$objectNotes' WHERE [AlertObjectID]='$objectID'"
        $ds.Clear()
        $cmd.CommandText = $query
        $sqladpt.SelectCommand = $cmd
        $null = $sqladpt.Fill($ds)
        break
      }

      "acknowledgeAlert" {
        $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
        $bodyContent = ($bodyRead.ReadToEnd())
        $initiator = ($bodyContent -split "<~>")[0]
        $alertID = ($bodyContent -split "<~>")[1]
        $query = "UPDATE [SolarWindsOrion].[dbo].[AlertActive] SET [Acknowledged]='1',[AcknowledgedBy]='JRTC\$initiator',[AcknowledgedDateTime]='$((Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss.fff"))' WHERE [AlertActiveID]='$alertID'"
        $ds.Clear()
        $cmd.CommandText = $query
        $sqladpt.SelectCommand = $cmd
        $null = $sqladpt.Fill($ds)
        break
      }

      "removeDownNeighborAlerts" {
        $query = "USE SolarWindsOrion; DELETE FROM NPM_RoutingNeighbor WHERE IsDeleted = '1';"
        $ds.Clear()
        $cmd.CommandText = $query
        $sqladpt.SelectCommand = $cmd
        $null = $sqladpt.Fill($ds)
        break
      }

      "storeAlertsData" {
        $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding) 
        $alertsData = ($bodyRead.ReadToEnd())
        #$alertsData | Export-Clixml c:\testXML.xml
        $alertsData = $alertsData | ConvertFrom-JSON 
        $alertsData | Export-Csv C:\Automation\HelpDeskHub\alertsData.csv -NoTypeInformation -Force
        break
      }

      "updateAlertsData" {
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
        
        $alerts | Export-Csv C:\Automation\HelpDeskHub\alertsData.csv -NoTypeInformation -Force
          #$null = Invoke-WebRequest http://127.0.0.1:1321/29nb83werhtweh/storeAlertsData -Method PUT -Body ($alerts | ConvertTo-JSON)
        break
      }

      default{
        $context.Response.StatusCode = 404;
      }  
    }
    $context.Response.Close()
  }
  else{
    $context.Response.StatusCode = 404;
  }
  $context.Response.Close()
  Start-Sleep -Milliseconds 100
}



$ds.Clear()
$cmd.CommandText = "SELECT * FROM sys.Tables;"
$sqladpt.SelectCommand = $cmd
$null = $sqladpt.Fill($ds)
$ds.Tables[0].Rows.Name

$query = "UPDATE [SolarWindsOrion].[dbo].[AlertActive] SET [Acknowledged]='1',[AcknowledgedBy]='jrtc\derek.poe.sa',[AcknowledgedDateTime]='$((Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss.fff"))' WHERE [AlertActiveID]='95936'"
$ds.Clear()
$cmd.CommandText = $query
$sqladpt.SelectCommand = $cmd
$null = $sqladpt.Fill($ds)

$conn.Close()