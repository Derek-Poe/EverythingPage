#$conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=C:\Automation\SitebossHub\sitebossData_basics.accdb;Persist Security Info=False;Mode=ReadWrite")
$conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=\\10.2.6.1\c$\Automation\SitebossHub\sitebossData_basics.accdb;Persist Security Info=False;Mode=ReadWrite")
$conn.Open()
$cmd = $conn.CreateCommand()
$dt = New-Object System.Data.DataTable
$dbnull = [System.DBNull]::Value
$snmp = New-Object -ComObject olePrn.oleSNMP

function getPackedDT($datTab){
  if($datTab -ne $null){
    $allCol = $datTab[0].Columns.ColumnName
    $selCol = @()
    forEach($col in $allCol){
      try{
        if(($datTab[0].$col)[0] -ne $dbnull){
          $selCol += $col
        }
      }
      catch{}
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

$query = "SELECT * FROM SitebossData;"
$cmd.CommandText = $query
$rdr = $cmd.ExecuteReader()
$dt.Clear() 
$dt.Load($rdr)
$snmpData = getPackedDT($dt)

forEach($sb in $snmpData){

  $query = "DROP TABLE Sensors_$($sb.CellSite);"
  $cmd.CommandText = $query
  $execute = $cmd.ExecuteNonQuery()

  if($sb.CellSite -notlike "*MAN*"){
    $snmp.Open($sb.IP, "sitebossRead",2,1000)
  }
  else{
    $snmp.Open($sb.IP, "CTCIS",2,1000)
  }
  $sensorScan = $snmp.GetTree(".1.3.6.1.4.1.3052.10.1.1.1.1.4.1.2")
  $sensors = @()
  for($i = 0; $i -lt $sensorScan.Length / 2; $i++){
    $sensors += New-Object PSCustomObject -Property ([ordered]@{Name=$sensorScan[1,$i];OID=$sensorScan[0,$i]})
  }
  $sensors = $sensors | ? {$_.Name -ne "unnamed"}
  
  #Write-Host -f Yellow $sb.CellSite
  #Write-Host $sensors

  $query = "CREATE TABLE Sensors_$($sb.CellSite) (SensorName varchar(50), OID varchar(75), PollValue varchar(100), LastPoll varchar(25));"
  $cmd.CommandText = $query
  $execute = $cmd.ExecuteNonQuery()

  forEach($sensor in $sensors){
    $poll = $snmp.Get(".1.3.6.1.4.1.3052.10.1.1.1.1.10.1.2.$($sensor.OID.Split(".")[16])")
    if($poll -eq ""){
      $poll = $snmp.Get(".1.3.6.1.4.1.3052.10.1.1.1.1.7.1.2.$($sensor.OID.Split(".")[16])")
    }
    $query = "INSERT INTO Sensors_$($sb.CellSite) (SensorName, OID, PollValue, LastPoll) VALUES ('$($sensor.Name)', '.1.3.6.1.4.1.3052.10.1.1.1.1.10.1.2.$($sensor.OID.Split(".")[16])', '$poll', '$((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt"))');"
    $cmd.CommandText = $query
    $execute = $cmd.ExecuteNonQuery()
  }

  $snmp.Close()
}

$conn.Close()
