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

$query = "SELECT [name] FROM sqlite_master WHERE type = `"table`";"
$cmd.CommandText = $query
$rdr = $cmd.ExecuteReader()
$dt.Clear() 
$dt.Load($rdr)
$tables = getPackedDT($dt)

forEach($name in $tables.name){
  $query = "DROP TABLE $name;"
  $cmd.CommandText = $query
  $cmd.ExecuteNonQuery()
}

$query = "CREATE TABLE Sessions (User TEXT PRIMARY KEY, Session TEXT NOT NULL, Time TEXT NOT NULL);"
$cmd.CommandText = $query
$cmd.ExecuteNonQuery()

$query = "INSERT INTO Sessions ([User], [Session], [Time]) VALUES ('TestUser', 'N132kn4#', '01/01/2021 11:22:30 PM');"
$cmd.CommandText = $query
$cmd.ExecuteNonQuery()

$query = "vacuum;"
$cmd.CommandText = $query
$cmd.ExecuteNonQuery()

$query = "SELECT * FROM Sessions;"
$cmd.CommandText = $query
$rdr = $cmd.ExecuteReader()
$dt.Clear() 
$dt.Load($rdr)
$data = getPackedDT($dt)

$query = "DELETE FROM Sessions WHERE User LIKE 'TestUser';"
$cmd.CommandText = $query
$execute = $cmd.ExecuteNonQuery()

$conn.Close()
