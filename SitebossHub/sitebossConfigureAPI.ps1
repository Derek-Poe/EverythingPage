Write-Host -f Cyan "CRM API"

$PID | Set-Content C:\Automation\AutoServerMonitor\sitebossConfigureAPI--PID.txt -Force

$listener = New-Object System.Net.HttpListener
$enc = [System.Text.Encoding]::ASCII
$hostName = "$env:COMPUTERNAME.ctcis.local"

$listener.Prefixes.Add("https://$hostName`:9746/")

$listener.Start()

$checkLogin = {
  Param($sessDat,$cmd,$dt)
  $session = $sessDat
  $query = "SELECT [Time] FROM UserEntry WHERE [Session] LIKE '$session';"
  $cmd.CommandText = $query
  $rdr = $cmd.ExecuteReader()
  $dt.Clear() 
  $dt.Load($rdr)

  if($dt.Time.Length -gt 0){
    $ts = New-TimeSpan -Start (Get-Date) -End ([datetime]::Parse($dt[0].Time))
    #Write-Host "$session $($ts.Seconds)"
    if($ts.Seconds -ge 0){
      $etime = (Get-Date).AddMinutes(60).ToString("MM/dd/yyyy hh:mm:ss tt")
      $query = "UPDATE UserEntry SET [Time]='$etime' WHERE [Session] LIKE '$session';"
      $cmd.CommandText = $query
      $execute = $cmd.ExecuteNonQuery()
      #Write-Host "Session Time Set"
      return "Logged In"
    }
    else{
      return "Not Logged In"
    }
  }
  else{
    return "Not Logged In"
  }
}

$getPackedDT = {
  Param($datTab)
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

$getCurrentUser = {
  Param($adSess,$cmd,$dt)
  $session = $null
  $session = $adSess
  $sessNullCheck = $false
  if($session -eq $null){
    $sessNullCheck = $true
  }
  if($sessNullCheck){
    $adDec = "_NP"
  }
  else{
    $query = "SELECT [DisplayName] FROM UserEntry WHERE [Session] LIKE '$session';"
    $cmd.CommandText = $query
    $rdr = $cmd.ExecuteReader()
    $dt.Clear() 
    $dt.Load($rdr)
    if($dt.DisplayName -is [array]){
      $adDec = ($dt.DisplayName)[0]
    }
    else{
      $adDec = $dt.DisplayName
    }
  }
  return $adDec
}

$main = {
  Param($con,$enc,$checkLogin,$getPackedDT,$getCurrentUser)
  
  $apiKey = "9832h4f98d"
  $context = $con
  $requester = $context.Request.RemoteEndPoint
  $request = $context.Request.RawUrl
  $request = $request.Substring(1,$request.Length-1)
  $request = $request.split("/")
  $byteMess = $null

  #$loggedIn = "Not Logged In"
  #if(($context.Request.Cookies | ? {$_.Name -eq "atSess"}) -ne $null){
  #  $reqSess = ($context.Request.Cookies | ? {$_.Name -eq "atSess"}).Value.Trim()
  #}

  If($request[0] -eq "favicon.ico"){
    $context.Response.Close()
  }
  elseIf($request[0] -eq $apiKey){
    switch($request[1]){

      
      default {
      $context.Response.Close()
      }
    }
  }
  elseIf($request[0] -eq "CustomerSignin"){
    ##Write-Host -f Yellow "$requester -- $request -- $((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt"))"
    $content = Get-Content -Encoding Byte -Path c:\Automation\CRM\customerSigninPage.html
    $context.Response.OutputStream.Write($content,0,$content.Length)
    $context.Response.Close()
  }
}

#$maxRun = Read-Host "Runspaces"
$maxRun = 8
$maxRun = [int]$maxRun
$runspace = [RunSpaceFactory]::CreateRunspacePool(1,$maxRun)
$runspace.Open()
$psInst = New-Object -TypeName PSCustomObject
$props = "1=$null"
$availProps = "1=$true"
2..$maxRun | % {
  $props += "`n$_=$null"
  $availProps += "`n$_=$true"
}
forEach($prop in @("Inst","Stat","Res")){
  $psInst | Add-Member -MemberType NoteProperty -Name $prop -Value ($props | ConvertFrom-StringData)
}
$context = New-Object -TypeName PSCustomObject -Property @{CurrentCon=0}
$context | Add-Member -MemberType NoteProperty -Name "ConAvail" -Value ($availProps | ConvertFrom-StringData)
$context | Add-Member -MemberType NoteProperty -Name "Con" -Value ($props | ConvertFrom-StringData)
function assignContext($conTemp){
  $maxCap = $true
  for($i = 1; $i -le $maxRun; $i++){
    if($context.ConAvail.([String]$i)){
      $context.CurrentCon = $i
      $maxCap = $false
      break
    }
  }
  if($maxCap){
    $context.CurrentCon = 0
    $cleanData = cleanup -context $context -psInst $psInst
    $context = $cleanData.context
    $psInst = $cleanData.psInst
    Start-Sleep -Milliseconds 500
    assignContext
  }
  else{
    $context.ConAvail.([String]$context.CurrentCon) = $false
    $context.Con.($context.CurrentCon -as [String]) = $conTemp
  }
}
function startRunspace($sblock,$runspace,$enc){
  $psInst.Inst.([String]$context.CurrentCon) = [PowerShell]::Create()
  $psInst.Inst.([String]$context.CurrentCon).RunspacePool = $runspace
  #Param($con,$enc,$checkLogin,$getPackedDT,$getCurrentUser)
  $null = $psInst.Inst.([String]$context.CurrentCon).AddScript($main).`
          AddArgument($context.Con.([String]$context.CurrentCon)).AddArgument($enc).`
          AddArgument($checkLogin).AddArgument($getPackedDT).AddArgument($getCurrentUser)
  $psInst.Stat.([String]$context.CurrentCon) = $psInst.Inst.([String]$context.CurrentCon).BeginInvoke()
}
function cleanup($context,$psInst){
  1..$maxRun | % {
    $i = $_
    if(!($context.ConAvail.([String]$i))){
      if($psInst.Stat.([String]$i).IsCompleted){
        $psInst.Res.([String]$context.CurrentCon) = $psInst.Inst.([String]$context.CurrentCon).EndInvoke($psInst.Stat.([String]$context.CurrentCon))
        $context.ConAvail.([String]$i) = $true
      }
    }
  }
  return New-Object -TypeName PSCustomObject -Property @{context=$context;psInst=$psInst}
}

$cleanCycle = 0
do{
  $conTemp = $listener.GetContext()
  assignContext -conTemp $conTemp
  startRunspace -sblock $sblock -runspace $runspace -enc $enc
  if($cleanCycle -ge 2){
    $cleanCycle = 0
    $cleanData = cleanup -context $context -psInst $psInst
    $context = $cleanData.context
    $psInst = $cleanData.psInst
  }
  $cleanCycle++
}
while($true)

# SIG # Begin signature block
# MIIHuwYJKoZIhvcNAQcCoIIHrDCCB6gCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUVKATWYCagCozuLT+cjyUlrKb
# S1egggUrMIIFJzCCBM2gAwIBAgIKZ5YFbgAAAABWmjAKBggqhkjOPQQDAjBLMRUw
# EwYKCZImiZPyLGQBGRYFbG9jYWwxFTATBgoJkiaJk/IsZAEZFgVjdGNpczEbMBkG
# A1UEAxMSQ1RDSVMtSS1DRVJULTAxLUNBMB4XDTIxMDIxMDE0MjQzNFoXDTIzMDIx
# MDE0MjQzNFowVTEVMBMGCgmSJomT8ixkARkWBWxvY2FsMRUwEwYKCZImiZPyLGQB
# GRYFY3RjaXMxDjAMBgNVBAsTBUFETUlOMRUwEwYDVQQDEwxEZXJlayBKLiBQb2Uw
# ggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCoAGCJf/9NdLKMRJ5WtRk2
# T6w3B6KBRGIfORUGY/GnUH0pGZ+wmh/billQqqcj9t392eliI/CNCL6zK3To2hSM
# pQC7n45Dgk4tSEcxaC1cEJEFNYDtLn+HpliSj+lNw+f2uUp2uL7w2NczHOUXxcx+
# LswYRzqVJKukV61bIQScuf8zS+Iv1Da4lKGO0VGTtAvIIw1MSwrpvBjHORD25gk7
# 4XzN3yGFCYb29EYR/Fbo7kYlJ0XXSe/6DAlA0MLL1IS6xUBIBvDzZ2hp1KivsSZO
# zXfzAY0fY/48p0D/LTWwxGjkGIZyuI3SLFLF/Ts1raxy+nqWZmZ9KPWSJxfw4D2F
# AgMBAAGjggLCMIICvjA5BgkrBgEEAYI3FQcELDAqBiIrBgEEAYI3FQiEt8JAgcTy
# CIONgxq0t2rkvD9E3sh00d5YAgFkAgEDMBMGA1UdJQQMMAoGCCsGAQUFBwMDMA4G
# A1UdDwEB/wQEAwIHgDAbBgkrBgEEAYI3FQoEDjAMMAoGCCsGAQUFBwMDMB0GA1Ud
# DgQWBBSuW3Q4sfdUH4spt3dl5je2QciHoDAfBgNVHSMEGDAWgBR6KcJTdM9S8jsF
# 1anrC1+iSPU0EzCCAQkGA1UdHwSCAQAwgf0wgfqggfeggfSGgbtsZGFwOi8vL0NO
# PUNUQ0lTLUktQ0VSVC0wMS1DQSxDTj1JLUNFUlQtMDEsQ049Q0RQLENOPVB1Ymxp
# YyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24s
# REM9Y3RjaXMsREM9bG9jYWw/Y2VydGlmaWNhdGVSZXZvY2F0aW9uTGlzdD9iYXNl
# P29iamVjdENsYXNzPWNSTERpc3RyaWJ1dGlvblBvaW50hjRmaWxlOi8vXFxJLUNF
# UlQtMDFcQ1JMRGlzdHJvJFxDVENJUy1JLUNFUlQtMDEtQ0EuY3JsMIHEBggrBgEF
# BQcBAQSBtzCBtDCBsQYIKwYBBQUHMAKGgaRsZGFwOi8vL0NOPUNUQ0lTLUktQ0VS
# VC0wMS1DQSxDTj1BSUEsQ049UHVibGljJTIwS2V5JTIwU2VydmljZXMsQ049U2Vy
# dmljZXMsQ049Q29uZmlndXJhdGlvbixEQz1jdGNpcyxEQz1sb2NhbD9jQUNlcnRp
# ZmljYXRlP2Jhc2U/b2JqZWN0Q2xhc3M9Y2VydGlmaWNhdGlvbkF1dGhvcml0eTAr
# BgNVHREEJDAioCAGCisGAQQBgjcUAgOgEgwQZHBvZUBjdGNpcy5sb2NhbDAKBggq
# hkjOPQQDAgNIADBFAiEAsdrdbkodm7tOfLSUt9hgVT9M/BKXN4GixGNXSvhsFOoC
# ICKX+IdDtd35lhHjWyjrMoL3KyQRpeC4DoD0CMTFr6WXMYIB+jCCAfYCAQEwWTBL
# MRUwEwYKCZImiZPyLGQBGRYFbG9jYWwxFTATBgoJkiaJk/IsZAEZFgVjdGNpczEb
# MBkGA1UEAxMSQ1RDSVMtSS1DRVJULTAxLUNBAgpnlgVuAAAAAFaaMAkGBSsOAwIa
# BQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgor
# BgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3
# DQEJBDEWBBQVTCUsaevtY59Kmhj/qzuVOaQpHzANBgkqhkiG9w0BAQEFAASCAQBF
# VyQU98zXsQUMO1+DDye1vSl4gFr6Mp6+wuG1HxU+/aWtWBW5YTB2TUrlQWbijWp6
# rHsp4xN3ual0EjTolbb9AJFeomYXoNIFhZ5e4ABumWSESCk2j5/szq/hJGS3+Qqm
# B6lxO102CyCDaiK9CHUdhc9MWOxRGpTR2pKiUhlBUxr+NX0fn1CjbvuXpR+hfpCe
# 45udreM1kvD9G38Xgg+XCSa6/LQbk+4GQTDl7mlQuligKJdWLRSSYtSphoO8iIoa
# NCq11/U3bgs42OuBUWCllqSyIBRZlaGFOOrwhs1oTyf9cwjPiQ5/OWRlpSgNzT4I
# shIgLudscxQ6YFMcSv1s
# SIG # End signature block
