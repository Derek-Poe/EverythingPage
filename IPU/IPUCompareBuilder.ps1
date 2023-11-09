Write-Host -f Cyan "IPU Compare Builder"

Stop-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\IPUCompareBuilder--PID.txt") -ErrorAction SilentlyContinue
$PID | Set-Content C:\Automation\AutoServerMonitor\IPUCompareBuilder--PID.txt -Force

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

function tfToYN($in){
  if($in -eq $true -or $in -like "True"){
    return "Yes"
  }
  elseIf($in -eq $false -or $in -like "False"){
    return "No"
  }
  else{
    return $null
  }
}

$runCounter = 0

while($true){
  $startTime = (Get-Date)
  Write-Host "StartTime: $($startTime.ToString(`"MM/dd/yyyy hh:mm:ss tt"))" -NoNewline

  $sessKey = ""
  for($i = 0; $i -lt 4; $i++){
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
  
  $entities = @()
  $dbPos = 0
  $querySize = 100000
  $posLimit = 1000000
  $time = ((Get-Date).ToUniversalTime()).ToString("yyyy-MM-ddhh:mm:ss")
  $time = $time.Insert(10,"T")
  $time = $time.Insert($time.Length,".000Z")
  $exerData = ((Invoke-WebRequest -UseBasicParsing -WebSession $webSess -Uri "http://10.224.218.12:8080/ctia.exercise/exercises" -Headers @{"Pragma"="no-cache"; "Sec-Fetch-Site"="same-origin"; "Accept-Encoding"="gzip, deflate, br"; "Accept-Language"="en-US,en;q=0.9"; "User-Agent"="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36"; "Sec-Fetch-Mode"="cors"; "Accept"="application/json, text/plain, */*"; "Cache-Control"="no-cache"; "Referer"="http://10.224.218.12:8080/ctia.exercise/exercises";} -ContentType "application/json").Content) | ConvertFrom-Json
  $exer = $exerData.payload.exercises.id.uuid
  $exerName = $exerData.payload.exercises.name -replace "_","-"
  $entData = Invoke-WebRequest -UseBasicParsing -Uri "http://10.224.218.12:8080/ctia.entity_organization/query/entities" -Method "POST" -Headers @{"Pragma"="no-cache"; "Sec-Fetch-Site"="same-origin"; "Origin"="http://10.224.218.12"; "Accept-Encoding"="gzip, deflate, br"; "Accept-Language"="en-US,en;q=0.9"; "User-Agent"="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36"; "Sec-Fetch-Mode"="cors"; "Accept"="application/json, text/plain, */*"; "Cache-Control"="no-cache"; "Referer"="http://10.224.218.12:8080/ctia.entity_organization/query/entities";} -ContentType "application/json" -Body "{`"queryName`":`"QueryEntitiesByExerciseWithLike`",`"header`":{`"id`":{`"uuid`":`"$((New-Guid).Guid)`",`"class`":`"ctia.data_model.HeaderId`"},`"sentTime`":`"$time`",`"actualTime`":`"$time`",`"serviceName`":`"SoaEntityOrganizationService`",`"userName`":`"$("TCE")`",`"host`":`"s-lctia4-102.ctcis.local`",`"class`":`"ctia.data_model.HeaderData`"},`"criteria`":[{`"name`":`"EX_ID`",`"stringValue`":`"$exer`",`"class`":`"ctia.data_model.Criterion`"},{`"name`":`"LIKE_QUERY`",`"stringValue`":`"%%`",`"class`":`"ctia.data_model.Criterion`"}],`"ordering`":[{`"attribute`":`"name`",`"direction`":`"Ascending`",`"class`":`"ctia.data_model.OrderBy`"}],`"maxResults`":$querySize,`"projections`":[],`"startOffset`":$dbPos,`"isRecovered`":false,`"class`":`"ctia.data_model.NamedQueryRequest`"}"
  $lt2Time = (Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")
  $entData = $entData.Content | ConvertFrom-Json
  $entities += $entData.payload.entities
  #$entities = $entities | ? {$_.isReal}
  $totalEnt = $entData.payload.totalCount -as [int]

  Copy-Item -Path "\\s-tce-101\c$\TCE\tce_data.sqlite" -Destination "C:\Automation\IPU\temp" -Force
  $tceTime = (Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")
  #$creationDate = (Get-Date).ToUniversalTime().ToString("MM/dd/yyyy hh:mm tt")
  $databaseRead = Start-Job -ScriptBlock {
    [void][System.Reflection.Assembly]::LoadFrom("C:\Automation\IPU\System.Data.SQLite.dll")
    $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=C:\Automation\IPU\temp\tce_data.sqlite;Persist Security Info=false;Mode=Read;")
    $conn.Open()
    $cmd = $conn.CreateCommand()
    $dt = New-Object System.Data.DataTable
    $query = "SELECT [trid],[version],[id],[type],[classification],[ownerProducer],[releasableTo],[name],[symbolCode],CAST([timestampCreated] as nvarchar(255)),CAST([timestampExpires] as nvarchar(255)),CAST([timestampLastModified] as nvarchar(255)),CAST([timestampReceived] as nvarchar(255)),[latitude],[boundingLatitude],[longitude],[boundingLongitude],[priority],[source],[content] FROM tce_data;"
    $cmd.CommandText = $query
    $rdr = $cmd.ExecuteReader()
    $dt.Clear() 
    $dt.Load($rdr)
    $tceData = $dt.Rows
    return $tceData
  }
  $null = Wait-Job $databaseRead
  $tceData = Receive-Job $databaseRead
  $enc = [System.Text.Encoding]::ASCII
  forEach($row in $tceData){
    $timeProps = @("timestampCreated","timestampExpires","timestampLastModified","timestampReceived")
    forEach($prop in $timeProps){
      try{
        $row.("CAST([$prop] as nvarchar(255))") = [DateTimeOffset]::FromUnixTimeMilliseconds(($row.("CAST([$prop] as nvarchar(255))") -as [double])).ToString("MM/dd/yyyy hh:mm:ss tt")
      }
      catch{}
      if($row.("CAST([$prop] as nvarchar(255))") -lt "1/1/1971"){
        $row.("CAST([$prop] as nvarchar(255))") = "N/A"
      }
    }
    $row | Add-Member -MemberType NoteProperty -Name contentString -Value $enc.GetString($row.content)
    $row | Add-Member -MemberType AliasProperty -Name timeCreated -Value "CAST([timestampCreated] as nvarchar(255))"
    $row | Add-Member -MemberType AliasProperty -Name timeExpires -Value "CAST([timestampExpires] as nvarchar(255))"
    $row | Add-Member -MemberType AliasProperty -Name timeLastModified -Value "CAST([timestampLastModified] as nvarchar(255))"
    $row | Add-Member -MemberType AliasProperty -Name timeReceived -Value "CAST([timestampReceived] as nvarchar(255))"
  }
  $tceData = $tceData | Select * -ExcludeProperty RowError,RowState,Table,ItemArray,HasErrors,CAST*,content
  $tceData = $tceData | ? {$_.type -lt 350}

  #$creationDate = (Get-Date).ToUniversalTime().ToString("MM/dd/yyyy hh:mm tt")

  $comp = $tceData.id | Compare-Object $entities.id.uuid
  $tceDiff = ($comp | ? {$_.SideIndicator -eq "=>"}).InputObject
  $lt2Diff = ($comp | ? {$_.SideIndicator -eq "<="}).InputObject
  $tceEnt = $tceData | ? {$tceDiff -contains $_.id}
  $lt2Ent = $entities | ? {$lt2Diff -contains $_.id.uuid}
  $props = ("name,class,id,disEntityType,entityType,uniqueName,parentOrganization,isFlagBearer,spatialRelationship,damageStateController,exercises,tspiSource,tacticalSymbols,isOutOfComms,tacticalSymbolColor,tacticalSymbolStandardCurrent,gatewayNetworkType,displayOrder,isExcludedFromFireEffects,isExcludedFromDetonationEffects,isRFOutOfComms,isVisible,isHiddenFromExercise,systemsUnderTestData,isReal,percentObscured,isFratricided,xroeViolation,isBDAComplete,instrumentationOverrideMode,urn,isTarget,fuelLevel,damageCode,mobilityKill,catastrophicKill,communicationsKill,sensorKill,firepowerKill,isPowerPlantOn,isMissionCapableSupply,isMissionCapableMaintenance,isCaptured,isLaserDesignatorOn,isTriggerDepressed,battlesightRange,currentRange").Split(",")
  forEach($lt2Entities in @($entities,$lt2Ent)){
    forEach($ent in $lt2Entities){
      forEach($prop in $props){
        if($ent.($prop) -eq $null){
          continue
        }
        if($prop -like "is*" -or $prop -like "*Kill"){
          $ent.($prop) = tfToYN($ent.($prop))
          continue
        }
        switch($prop){
          "class" {
            $ent.($prop) = ($ent.($prop)).Split(".")[4]
            break
          }
          "id" {
            $ent.($prop) = $ent.($prop).uuid
            break
          }
          "parentOrganization" {
            $ent.($prop) = $ent.($prop).uuid
            break
          }
          "exercises" {
            $ent.($prop) = $ent.($prop).uuid
            break
          }
          "tacticalSymbols" {
            $ent.($prop) = $ent.($prop) -as [String[]] | Out-String
            break
          }
          "systemsUnderTestData" {
            $ent.($prop) = tfToYN($ent.($prop).isUnderTest)
            break
          }
        }
      }
    }
  }
  New-Object PSCustomObject -Property ([ordered]@{tceTime=$tceTime;lt2Time=$lt2Time;tceDataCount=$tceData.Length;lt2DataCount=$entities.Length;tceDiffCount=$tceEnt.Length;lt2DiffCount=$lt2Ent.Length}) | Export-Csv "C:\Automation\IPU\temp\IPU_Compare_$sessKey`_summary.csv" -Force -NoTypeInformation
  $tceData | Select name,releasableTo,timeCreated,latitude,longitude,timeLastModified,timeReceived,timeExpires,source,symbolCode,ownerProducer,priority,id,trid,version,type,classification,boundingLatitude,boundingLongitude | Sort name| Export-Csv "C:\Automation\IPU\temp\IPU_Compare_$sessKey`_tceEnt.csv" -Force -NoTypeInformation
  $entities | Select name,class,id,disEntityType,entityType,uniqueName,parentOrganization,isFlagBearer,spatialRelationship,damageStateController,exercises,tspiSource,tacticalSymbols,isOutOfComms,tacticalSymbolColor,tacticalSymbolStandardCurrent,gatewayNetworkType,displayOrder,isExcludedFromFireEffects,isExcludedFromDetonationEffects,isRFOutOfComms,isVisible,isHiddenFromExercise,systemsUnderTestData,isReal,percentObscured,isFratricided,xroeViolation,isBDAComplete,instrumentationOverrideMode,urn,isTarget,fuelLevel,damageCode,mobilityKill,catastrophicKill,communicationsKill,sensorKill,firepowerKill,isPowerPlantOn,isMissionCapableSupply,isMissionCapableMaintenance,isCaptured,isLaserDesignatorOn,isTriggerDepressed,battlesightRange,currentRange | Sort name | Export-Csv "C:\Automation\IPU\temp\IPU_Compare_$sessKey`_lt2Ent.csv" -Force -NoTypeInformation
  $tceEnt | Select name,releasableTo,timeCreated,latitude,longitude,timeLastModified,timeReceived,timeExpires,source,symbolCode,ownerProducer,priority,id,trid,version,type,classification,boundingLatitude,boundingLongitude | Sort name | Export-Csv "C:\Automation\IPU\temp\IPU_Compare_$sessKey`_tceDiff.csv" -Force -NoTypeInformation
  #name releasableTo timeCreated latitude longitude timeLastModified	timeExpires	source	timeReceived	trid	version	id	type	classification	ownerProducer			symbolCode		boundingLatitude		boundingLongitude	priority	
  $lt2Ent | Select name,class,id,disEntityType,entityType,uniqueName,parentOrganization,isFlagBearer,spatialRelationship,damageStateController,exercises,tspiSource,tacticalSymbols,isOutOfComms,tacticalSymbolColor,tacticalSymbolStandardCurrent,gatewayNetworkType,displayOrder,isExcludedFromFireEffects,isExcludedFromDetonationEffects,isRFOutOfComms,isVisible,isHiddenFromExercise,systemsUnderTestData,isReal,percentObscured,isFratricided,xroeViolation,isBDAComplete,instrumentationOverrideMode,urn,isTarget,fuelLevel,damageCode,mobilityKill,catastrophicKill,communicationsKill,sensorKill,firepowerKill,isPowerPlantOn,isMissionCapableSupply,isMissionCapableMaintenance,isCaptured,isLaserDesignatorOn,isTriggerDepressed,battlesightRange,currentRange | Sort name | Export-Csv "C:\Automation\IPU\temp\IPU_Compare_$sessKey`_lt2Diff.csv" -Force -NoTypeInformation

  forEach($file in (Get-ChildItem C:\Automation\IPU\temp | ? {$_.Name -like "IPU_Compare_*"})){
    if($file.Name.split("_")[2] -ne $sessKey){
      $file | Remove-Item -Force
    }
  }

  $execTime = (New-TimeSpan -Start $startTime -End (Get-Date))
  Write-Host " -- ExecTime: $($execTime.ToString())"
  if($execTime.TotalSeconds -lt 900){
    Start-Sleep -Milliseconds (900000 - [Math]::Round($execTime.TotalMilliseconds))
  }

  if($runCounter -gt 2){
    exit
  }
  $runCounter++
}
