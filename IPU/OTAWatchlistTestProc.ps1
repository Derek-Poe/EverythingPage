@"
"ID","IPU","Type","Goal","Complete","Initiator","Date"
"1","IPU-Test001","SWUP","1.7.1.2","False","Derek Test","07/01/2022 04:00:37 PM"
"2","IPU-Test002","SWUP","1.7.1.2","False","Derek Test","07/01/2022 04:00:37 PM"
"3","IPU-Test003","SWUP","1.7.1.2","False","Derek Test","07/01/2022 04:00:37 PM"
"4","IPU-Test004","SWUP","1.7.1.2","False","Derek Test","07/01/2022 04:00:37 PM"
"5","IPU-Test005","SWUP","1.7.1.2","False","Derek Test","07/01/2022 04:00:37 PM"
"6","IPU-Test006","SWUP","1.7.1.2","False","Derek Test","07/01/2022 04:00:37 PM"
"7","IPU-Test007","SWUP","1.7.1.2","False","Derek Test","07/01/2022 04:00:37 PM"
"8","IPU-Test008","SWUP","1.7.1.2","False","Derek Test","07/01/2022 04:00:37 PM"
"9","IPU-Test009","SWUP","1.7.1.2","False","Derek Test","07/01/2022 04:00:37 PM"
"@ | Set-Content '\\10.2.6.1\c$\Automation\IPU\OTAWatchlist.csv'
Start-Sleep -Milliseconds 8000
$testIPUs = @(); Import-Csv '\\10.2.6.1\c$\Automation\IPU\OTAWatchlist.csv' | % {$testIPUs += $_}
$testIPUs | % {$_.Complete = $true}
$testIPUs | Export-Csv '\\10.2.6.1\c$\Automation\IPU\OTAWatchlist.csv' -NoTypeInformation -Force
Start-Sleep -Milliseconds 5000
$testIPUs = $testIPUs | ? {([int]$_.ID % 2) -eq 1}
$testIPUs | Export-Csv '\\10.2.6.1\c$\Automation\IPU\OTAWatchlist.csv' -NoTypeInformation -Force
Start-Sleep -Milliseconds 5000
@"
"ID","IPU","Type","Goal","Complete","Initiator","Date"
"10","IPU-Test010","SWUP","1.7.1.2","False","Derek Test","07/01/2022 04:00:37 PM"
"11","IPU-Test011","SWUP","1.7.1.2","False","Derek Test","07/01/2022 04:00:37 PM"
"12","IPU-Test012","SWUP","1.7.1.2","False","Derek Test","07/01/2022 04:00:37 PM"
"@ | ConvertFrom-Csv | % {$testIPUs += $_}
$testIPUs | Export-Csv '\\10.2.6.1\c$\Automation\IPU\OTAWatchlist.csv' -NoTypeInformation -Force
$testIPUs | % {$_.Complete = $true}
Start-Sleep -Milliseconds 5000
$testIPUs | Export-Csv '\\10.2.6.1\c$\Automation\IPU\OTAWatchlist.csv' -NoTypeInformation -Force