Stop-Process -Id (Get-Content "C:\Automation\AutoServerMonitor\autoRDPSessionConversion--PID.txt") -ErrorAction SilentlyContinue
$PID | Set-Content C:\Automation\AutoServerMonitor\autoRDPSessionConversion--PID.txt -Force
$host.UI.RawUI.WindowTitle = "autoRDPSessionConversion"

while(1){
  try{
    #$quser = ((((quser /SERVER:10.2.6.1).Trim() -replace "\s+","~") -replace ">","") -split "`n") | Select -Skip 1
    $quser = ((((quser).Trim() -replace "\s+","~") -replace ">","") -split "`n") | Select -Skip 1
    $users = @()
    forEach($user in $quser){
      $user = $user -split "~"
      if($user.Length -eq 8){
        $users += New-Object PSCustomObject -Property ([ordered]@{Username=$user[0];SessionName=$user[1];ID=$user[2];State=$user[3];IdleTime=$user[4];LoginTime="$($user[5]) $($user[6]) $($user[7])";})
      }
      else{
        $users += New-Object PSCustomObject -Property ([ordered]@{Username=$user[0];SessionName="";ID=$user[1];State=$user[2];IdleTime=$user[3];LoginTime="$($user[4]) $($user[5]) $($user[6])";})
      }
    }
    $sID = ($users | ? {$_.Username -eq "derek.poe.sa"}).ID
    $idle = ($users | ? {$_.Username -eq "derek.poe.sa"}).IdleTime
    if($idle -ne "." -and $idle -ne "none"){
      if($idle.Contains("+")){
        $time = [TimeSpan]::Parse(($idle).Replace("+","."))
      }
      elseIf($idle.Contains(":")){
        $time = [TimeSpan]::Parse($idle)
      }
      else{
        $time = [TimeSpan]::Parse("0:$($idle)")
      }
      #if($time.TotalHours -ge 12){
      if($time.TotalMinutes -ge 3){
        tscon /DEST:console $sID
      }
    }
  }
  catch{
    Write-Host -f DarkYellow "No Sessions Active"
  }
 sleep 1800
}