Write-Host -f Cyan "AD API"

$PID | Set-Content C:\Automation\AutoServerMonitor\adAPI_runspaceEnabled--PID.txt -Force

$listener = New-Object System.Net.HttpListener
#$apiPort = Get-Content \\fileshare01\home\dpoe\CRM\adApiPort.txt
#$apiPort = Get-Content C:\Automation\CRM\adApiPort.txt
$apiPort = 1322
$enc = [System.Text.Encoding]::ASCII
#$hostName = "ctcsr-jrtc70673.ctcis.local"
$hostName = "$env:COMPUTERNAME.ctcis.local"
$listener.Prefixes.Add("http://127.0.0.1:$apiPort/")
$listener.Start()

$main = {
  Param($con,$enc)

  $dcSession = New-PSSession -ComputerName I-DC-02
  #Invoke-Command -Session $dcSession -ScriptBlock {Import-Module ActiveDirectory}
  Import-PSSession $dcSession -DisableNameChecking -CommandName Get-ADUser,Set-ADUser,New-ADUser,Set-ADAccountPassword,Move-ADObject,Add-ADGroupMember,Enable-ADAccount,Disable-ADAccount,Unlock-ADAccount | Out-Null

  #$apiKey = Get-Content \\fileshare01\home\dpoe\CRM\adApiKey.txt
  #$apiKey = Get-Content C:\Automation\CRM\adApiKey.txt
  $apiKey = "q8nwv7r90qw87er"
  $context = $con
  $requester = $context.Request.RemoteEndPoint
  $request = $context.Request.RawUrl
  #Write-Host -f Yellow "$requester -- $request -- $((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt"))"
  "AD__API  $((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: $requester -- $request" | Add-Content -Force -Path c:\Automation\CRM\crm_web_log.txt
  $request = $request.Substring(1,$request.Length-1)
  $request = $request.split("/")
  #if($request[1] -eq "32"){
  #  $request[1] = $request[2]
  #}
  if($request[0] -eq $apiKey){
    switch($request[1]){

      "statusCheck" {
        $context.Response.Close()
        break
      }

      "pwdRSub" {
        ##
        #Check for User/Pwd
        #Check for Enabled
        #Check for Locked
        #Change Pwd
        #
        #Will cred check work when pwd has expired?
        #
        #$Error[0] = $null
        #$adCheck = New-Object System.DirectoryServices.DirectoryEntry -ArgumentList "LDAP://ctcis.local",$logonData[0],$logonData[1]
        #if $Error[0] -ne $null -and $Error[0] -like "*The user name or password is incorrect*.
        ##


        $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
        $str = $bodyRead.ReadToEnd()
        $str = $str.Split(",")
        $user = $str[0]
        $pwd = $str[1]
        $newPwd = $str[2]
        $userCheck = $null
        $userCheck = Get-ADUser -filter {SamAccountName -eq $user} -Properties PasswordExpired,LockedOut -ErrorAction:SilentlyContinue
        $expCheck = ($userCheck).PasswordExpired
        $lockCheck = ($userCheck).LockedOut
        if($userCheck -eq $null){
          $byteMess = $enc.GetBytes("badOldPwd")
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        }
        elseIf($expCheck -eq $true){
          $byteMess = $enc.GetBytes("pwdExpired")
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        }
        elseIf($lockCheck -eq $true){
          $byteMess = $enc.GetBytes("locked")
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        }
        elseIf($pwd -eq $newPwd){
          $byteMess = $enc.GetBytes("samePwd")
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        }
        else{
          $setPwd = $null
          #$c = New-Object System.Management.Automation.PSCredential -ArgumentList $user,(ConvertTo-SecureString -String $pwd -AsPlainText -Force)
          #$sess = New-PSSession -ComputerName TC16 -Credential $c -ErrorAction:SilentlyContinue -ErrorVariable sessRes
          #Get-PSSession | ? {$_.ComputerName -eq "TC16"} | Remove-PSSession
          
          $Error[0] = $null
          $adCheck = New-Object System.DirectoryServices.DirectoryEntry -ArgumentList "LDAP://ctcis.local",$user,$pwd
          $pCheck = $false
          if($Error[0] -eq $null){
            $pCheck = $true
          }
          if($pCheck){
            $pwd = (ConvertTo-SecureString -String $pwd -AsPlainText -Force)
            $newPwd = (ConvertTo-SecureString -String $newPwd -AsPlainText -Force)
            $set = Set-ADAccountPassword -Identity $user -NewPassword $newPwd -ErrorAction:SilentlyContinue -ErrorVariable setPwd
            $pCheck = $false
            $Error[0] = $null
            $adCheck = New-Object System.DirectoryServices.DirectoryEntry -ArgumentList "LDAP://ctcis.local",$user,$newPwd
            $pCheck = $false
            if($Error[0] -eq $null){
              $pCheck = $true
            }
            if($setPwd -like "*The password does not meet the length, complexity, or history requirement of the domain.*"){
              $byteMess = $enc.GetBytes("pwdReqFail")
              $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
            }
            elseIf($pCheck){
              "$((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: Password Reset - $user" | Add-Content -Force -Path c:\Automation\CRM\ad_actions_log.txt
              $byteMess = $enc.GetBytes("success")
              $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
            }
            else{
              $byteMess = $enc.GetBytes("resetError")
              $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
            }
          }
          elseIf(!($pCheck)){
            $byteMess = $enc.GetBytes("badOldPwd")
            $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          }
          else{
            $byteMess = $enc.GetBytes("Error...")
            $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          }
          <#
          if(!($sessRes -notlike "*Access is denied*") -or $sess -ne $null){
            $pwd = (ConvertTo-SecureString -String $pwd -AsPlainText -Force)
            $newPwd = (ConvertTo-SecureString -String $newPwd -AsPlainText -Force)
            $set = Set-ADAccountPassword -Identity $user -NewPassword $newPwd -ErrorAction:SilentlyContinue -ErrorVariable setPwd
            $c = New-Object System.Management.Automation.PSCredential -ArgumentList $user,$newPwd
            $sess = New-PSSession -ComputerName TC16 -Credential $c -ErrorAction:SilentlyContinue -ErrorVariable sessRes
            Get-PSSession | ? {$_.ComputerName -eq "TC16"} | Remove-PSSession
            if($setPwd -like "*The password does not meet the length, complexity, or history requirement of the domain.*"){
              $byteMess = $enc.GetBytes("pwdReqFail")
              $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
            }
            elseIf(!($sessRes -notlike "*Access is denied*") -or $sess -ne $null){
              $byteMess = $enc.GetBytes("success")
              $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
            }
            else{
              $byteMess = $enc.GetBytes("resetError")
              $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
            }
          }
          elseIf(!($sessRes -notlike "*The user name or password is incorrect*")){
            $byteMess = $enc.GetBytes("badOldPwd")
            $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          }
          else{
            $byteMess = $enc.GetBytes("Error...")
            $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          }
          #>
        }
        $context.Response.Close()
        break
      }

      "smartcardReqPull" {
        $users = Get-ADUser -Filter * -Properties SmartcardLogonRequired | Select Surname,GivenName,SamAccountName,SmartcardLogonRequired
        $xml = $users | Sort SamAccountName | ConvertTo-Xml -NoTypeInformation
        $byteMess = $enc.GetBytes($xml.OuterXml)
        $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        $context.Response.Close()
        break
      }

      "smartcardReqSubmit" {
        $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
        $jso = $bodyRead.ReadToEnd()
        $users = $jso | ConvertFrom-Json
        $outputData = @()
        forEach($user in $users){
          $userAD = Get-ADUser -Identity $user.logon -Properties SmartcardLogonRequired | Select Surname,GivenName,SamAccountName,SmartcardLogonRequired
          $lname = $userAD.Surname
          $fname = $userAD.GivenName
          $logon = $userAD.SamAccountName
          $origin = $userAD.SmartcardLogonRequired
          if($user.change -eq $true){
            Set-ADUser -Identity $user.logon -SmartcardLogonRequired $user.sc
          }
          $current = (Get-ADUser -Identity $user.logon -Properties SmartcardLogonRequired).SmartcardLogonRequired
          if($origin -ne $current){
            $success = $true
          }
          elseIf($origin -eq $current){
            $success = $false
          }
          else{
            $success = "Error"
          }
          $props = [ordered]@{
            LName = $lname
            FName = $fname
            Logon = $logon
            Origin = $origin
            Current = $current
            Success = $success
          }
          $dataObj = New-Object -TypeName PSCustomObject -Property $props
          $outputData += $dataObj
        }
        $xml = $outputData | Sort LName | ConvertTo-Xml -NoTypeInformation
        $byteMess = $enc.GetBytes($xml.OuterXml)
        $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        $context.Response.Close()
        break
      }

      "abUserCheck" {
        $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
        $user = $bodyRead.ReadToEnd()
        $userCheck = Get-ADUser -filter {SamAccountName -eq $user} -Properties PasswordExpired,LockedOut -ErrorAction:SilentlyContinue
        if($userCheck -eq $null){
          $byteMess = $enc.GetBytes("notFound")
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        }
        else{
          $byteMess = $enc.GetBytes("found")
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        }
        $context.Response.Close()
        break
      }

      "abBuild" {
        
        #Import-PSSession $dcSession
        $exSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://i-exch-01.ctcis.local/PowerShell/
        Import-PSSession $exSession -DisableNameChecking -CommandName Enable-Mailbox,Disable-Mailbox | Out-Null
        $lySession = New-PSSession -ConnectionUri https://i-lync-01.ctcis.local/OcsPowershell -Authentication NegotiateWithImplicitCredential
        Import-PSSession $lySession -DisableNameChecking -CommandName Get-CsUser,Enable-CsUser,Disable-CsUser | Out-Null

        $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
        $jso = $bodyRead.ReadToEnd()
        $buildData = $jso | ConvertFrom-Json

        $buildData.pwd = Get-Content \\fileshare01\home\dpoe\Reports\reportData\pdb208ffn38gfb38fba9ff.txt | ConvertTo-SecureString -Key (Get-Content \\fileshare01\home\dpoe\Reports\reportData\b1n9rk322ndh29dn39d.key)
        $pwdDec = "Default"

        switch($buildData.group){
          "Task Force 1" {
            $ouSel = "OU=TF_1,OU=TASKFORCES,DC=ctcis,DC=local"
            $grSel = @("Domain Users", "OCT BLUFOR", "TASKFORCE1", "TF_1")
            break
          }
          "Task Force 2" {
            $ouSel = "OU=TF_2,OU=TASKFORCES,DC=ctcis,DC=local"
            $grSel = @("Domain Users", "OCT BLUFOR", "TASK FORCE 2", "TF_2")
            break
          }
          "Task Force 3" {
            $ouSel = "OU=TF_3,OU=TASKFORCES,DC=ctcis,DC=local"
            $grSel = @("Domain Users", "OCT BLUFOR", "TASKFORCE 3", "TF_3")
            break
          }
          "Task Force 4" {
            $ouSel = "OU=TF_4,OU=TASKFORCES,DC=ctcis,DC=local"
            $grSel = @("Domain Users", "OCT BLUFOR", "TASKFORCE 4", "TF_4")
            break
          }
          "Task Force 5" {
            $ouSel = "OU=TF_5,OU=TASKFORCES,DC=ctcis,DC=local"
            $grSel = @("Domain Users", "OCT BLUFOR", "TASKFORCE 5", "TF_5")
            break
          }
          "Task Force Sustainment" {
            $ouSel = "OU=TF_SUST,OU=TASKFORCES,DC=ctcis,DC=local"
            $grSel = @("Domain Users", "OCT BLUFOR", "TASKFORCE SUSTAINMENT", "TF_SUST")
            break
          }
          "Task Force Aviation" {
            $ouSel = "OU=TF_AVN,OU=TASKFORCES,DC=ctcis,DC=local"
            $grSel = @("Domain Users", "OCT BLUFOR", "TASKFORCE AVIATION", "TF_AVN")
            break
          }
          "Task Force BMC" {
            $ouSel = "OU=TF_BMC,OU=TASKFORCES,DC=ctcis,DC=local"
            $grSel = @("Domain Users", "OCT BLUFOR", "TASKFORCE BMC", "TF_BMC", "CTCS-D", "TAF")
            break
          }
          "Task Force FireSupport" {
            $ouSel = "OU=TF_FS,OU=TASKFORCES,DC=ctcis,DC=local"
            $grSel = @("Domain Users", "OCT BLUFOR", "TASKFORCE FIRESUPPORT", "TF_FS", "MRC User", "SG_LIVEFIRE")
            break
          }
          "Task Force SOTD" {
            $ouSel = "OU=TF_SOTD,OU=TASKFORCES,DC=ctcis,DC=local"
            $grSel = @("Domain Users", "OCT BLUFOR", "TF_SOTD")
            break
          }
          "OpFor" {
            $ouSel = "OU=OPFOR,OU=TASKFORCES,DC=ctcis,DC=local"
            $grSel = @("Domain Users", "OCT OPFOR", "TF_OPFOR")
            break
          }
          "Valiant" {
            $ouSel = "OU=Valiant,OU=TASKFORCES,DC=ctcis,DC=local"
            $grSel = @("Domain Users", "Contact Team", "VALIANT", "SG_VALIANT")
            break
          }
          "LiveFire" {
            $ouSel = "OU=LiveFire,OU=TASKFORCES,DC=ctcis,DC=local"
            $grSel = @("Domain Users", "LiveFire Administrators", "SG_LIVEFIRE")
            break
          }
        }

        New-ADUser -AccountExpirationDate $buildData.expDate -AccountPassword $buildData.pwd -DisplayName $buildData.dname -GivenName $buildData.fname -Initials $buildData.mi -Surname $buildData.lname -SamAccountName $buildData.logon -Name $buildData.dname -Enabled $buildData.enabled -UserPrincipalName "$($buildData.logon)@ctcis.local" -PasswordNeverExpires $false -SmartcardLogonRequired $buildData.smartcard
        
        $dn = (Get-ADUser -Identity $buildData.logon).DistinguishedName
        Move-ADObject -Identity $dn -TargetPath $ouSel

        forEach($group in $grSel){
          if($group -ne "Domain Users"){
            Add-ADGroupMember -Identity $group -Members $buildData.logon
          }
        }

        #if($global:mblySessionsStarted -ne $true){
        #  $exSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://i-exch-01.ctcis.local/PowerShell/
        #  Import-PSSession $exSession -DisableNameChecking -CommandName Enable-Mailbox | Out-Null
        #  $lySession = New-PSSession -ConnectionUri https://i-lync-01.ctcis.local/OcsPowershell -Authentication NegotiateWithImplicitCredential
        #  Import-PSSession $lySession -DisableNameChecking -CommandName Get-CsUser,Enable-CsUser | Out-Null
        #  $global:mblySessionsStarted = $true
        #}

        Function waitMB(){
          $mb = (Get-ADUser -Identity $buildData.logon -Properties mail).mail
          if($mb -eq $null){
            if($global:mbCheck -ge 6){
              return
            }
            $global:mbCheck += 1
            Start-Sleep -Seconds 5
            waitMB
          }
          else{
            Start-Sleep -Seconds 10
          }
        }
        
        Function waitLY(){
          $ly = (Get-CsUser -Identity $buildData.logon -ErrorAction:SilentlyContinue).Enabled
          if($ly -ne $true){
            if($global:lyCheck -ge 6){
              return
            }
            $global:lyCheck += 1
            Start-Sleep -Seconds 5
            waitLY
          }
        }

        Function verifyMBLY(){
          $success = $true
          $user = Get-ADUser -Identity $buildData.logon -Properties *
          $mb = $user.mail
          if($mb -eq $null){
            $global:mbVer = "Not Created"
          }
          else{
            $global:mbVer = "Enabled"
          }
          $ly = (Get-CsUser -Identity $buildData.logon).Enabled
          if($ly -eq $true){
            $global:lyVer = "Enabled"
          }
          else{
            $global:lyVer = "Not Created"
          }
        }

        $enMB = Enable-Mailbox $buildData.logon -ErrorAction:SilentlyContinue
        waitMB
        $enLY = enable-csuser -registrarpool "i-lync-01.ctcis.local" -sipaddresstype emailaddress -sipdomain "ctcis.local" -identity $buildData.logon -ErrorAction:SilentlyContinue | Out-Null
        waitLY
        verifyMBLY

        $verUser = Get-ADUser -Identity $buildData.logon -Properties *
        $props = [ordered]@{
          fname = $verUser.GivenName
          mi = $verUser.Initials
          lname = $verUser.Surname
          dname = $verUser.DisplayName
          logon = $verUser.SamAccountName
          expDate = $verUser.AccountExpirationDate.ToString("MM/dd/yyyy")
          enabled = $verUser.Enabled
          smartcard = $verUser.SmartcardLogonRequired
          group = $buildData.group
          pwd = $pwdDec
          mb = $global:mbVer
          ly = $global:lyVer
        }
        $responseData = New-Object -TypeName PSCustomObject -Property $props
        $responseData = $responseData | ConvertTo-JSON
        $byteMess = $enc.GetBytes($responseData)
        $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
        $context.Response.Close()

        "$((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: Account Created - $($buildData.logon)" | Add-Content -Force -Path c:\Automation\CRM\ad_actions_log.txt
        break
      }

      "abPwdSet" {
        $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
        $body = $bodyRead.ReadToEnd()
        $setData = $body.split(",")
        $set = Set-ADAccountPassword -Identity $setData[0] -NewPassword (ConvertTo-SecureString -String $setData[1] -AsPlainText -Force) -ErrorAction:SilentlyContinue
        $context.Response.Close()

        "$((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: Password Set - $($setData[0])" | Add-Content -Force -Path c:\Automation\CRM\ad_actions_log.txt
        break
      }

      "asGet" {
        $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
        $body = $bodyRead.ReadToEnd()
        $user = $body
        $props = "SamAccountName,GivenName,Initials,Surname,Description,DisplayName,DistinguishedName"
        $props = $props.Split(",")
        $users = $null
        $users = Get-ADUser -Filter * -Properties $props | ? {$_.SamAccountName -like "*$user*" -or $_.GivenName -like "*$user*" -or $_.Initials -like "*$user*" -or $_.Surname -like "*$user*" -or $_.Description -like "*$user*" -or $_.DisplayName -like "*$user*"}
        if($users -ne $null){
          $sendData = @()
          forEach($user in $users){
            $packingData = New-Object -TypeName PSCustomObject
            forEach($prop in $props){
              $packingData | Add-Member -Name $prop -Value $user.($prop) -MemberType NoteProperty
            }
            $packingData | Add-Member -Name logon -Value $packingData.SamAccountName -MemberType NoteProperty
            $packingData | Add-Member -Name fname -Value $packingData.GivenName -MemberType NoteProperty
            $packingData | Add-Member -Name mi -Value $packingData.Initials -MemberType NoteProperty
            $packingData | Add-Member -Name lname -Value $packingData.Surname -MemberType NoteProperty
            $packingData | Add-Member -Name dname -Value $packingData.DisplayName -MemberType NoteProperty
            $packingData | Add-Member -Name Taskforce -Value $null -MemberType NoteProperty
            switch -Wildcard ($packingData.DistinguishedName){
              "*TF_1*" {
                $packingData.Taskforce = "Task Force 1"
                break
              }
              "*TF_2*" {
                $packingData.Taskforce = "Task Force 2"
                break
              }
              "*TF_3*" {
                $packingData.Taskforce = "Task Force 3"
                break
              }
              "*TF_4*" {
                $packingData.Taskforce = "Task Force 4"
                break
              }
              "*TF_5*" {
                $packingData.Taskforce = "Task Force 5"
                break
              }
              "*TF_SUST*" {
                $packingData.Taskforce = "Task Force Sustainment"
                break
              }
              "*TF_AVN*" {
                $packingData.Taskforce = "Task Force Aviation"
                break
              }
              "*TF_BMC*" {
                $packingData.Taskforce = "Task Force BMC"
                break
              }
              "*TF_FS*" {
                $packingData.Taskforce = "Task Force FireSupport"
                break
              }
              "*TF_SOTD*" {
                $packingData.Taskforce = "Task Force SOTD"
                break
              }
              "*OPFOR*" {
                $packingData.Taskforce = "OpFor"
                break
              }
              "*Valiant*" {
                $packingData.Taskforce = "Valiant"
                break
              }
              "*LiveFire*" {
                $packingData.Taskforce = "LiveFire"
                break
              }
            }
            $packingData.PSObject.Properties.Remove("GivenName")
            $packingData.PSObject.Properties.Remove("Initials")
            $packingData.PSObject.Properties.Remove("Surname")
            $packingData.PSObject.Properties.Remove("DisplayName")
            $packingData.PSObject.Properties.Remove("SamAccountName")
            $packingData.PSObject.Properties.Remove("DistinguishedName")
            $packedData = New-Object -TypeName PSCustomObject
            forEach($prop in $packingData.PSObject.Properties){
              $packedData | Add-Member -Name (($prop.Name).Substring(0,1).ToLower()+($prop.Name).Substring(1,($prop.Name).Length-1)) -Value $packingData.($prop.Name) -MemberType NoteProperty
            }
            $packedData = $packedData | Select fname,mi,lname,dname,logon,taskforce,description
            $sendData += $packedData
          }
          $byteMess = $enc.GetBytes(($sendData | ConvertTo-JSON))
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          $context.Response.Close()
        }
        else{
          $byteMess = $enc.GetBytes("NH")
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          $context.Response.Close()
        }
        $context.Response.Close()
        break
      }

      "amInfoGet" {
        $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
        $body = $bodyRead.ReadToEnd()
        $props = "SamAccountName,GivenName,Initials,Surname,Enabled,LockedOut,AccountExpirationDate,badPasswordTime,CannotChangePassword,createTimeStamp,Description,DisplayName,DistinguishedName,lastLogonTimestamp,LockoutTime,Modified,PasswordExpired,pwdLastSet,PasswordNeverExpires,SmartcardLogonRequired,mail,msRTCSIP-UserEnabled"
        $props = $props.Split(",")
        $user = $null
        #$user = Get-ADUser -filter {SamAccountName -eq $body} -Properties $props.Split(",") -ErrorAction:SilentlyContinue
        $user = Get-ADUser -Identity $body -Properties $props.Split(",") -ErrorAction:SilentlyContinue
        if($user -ne $null){
          $packingData = New-Object -TypeName PSCustomObject
          forEach($prop in $props){
            $packingData | Add-Member -Name $prop -Value $user.($prop) -MemberType NoteProperty
          }
          $packingData | Add-Member -Name fname -Value $packingData.GivenName -MemberType NoteProperty
          $packingData | Add-Member -Name mi -Value $packingData.Initials -MemberType NoteProperty
          $packingData | Add-Member -Name lname -Value $packingData.Surname -MemberType NoteProperty
          $packingData | Add-Member -Name dname -Value $packingData.DisplayName -MemberType NoteProperty
          $packingData | Add-Member -Name expDate -Value $packingData.AccountExpirationDate -MemberType NoteProperty
          $packingData | Add-Member -Name Exchange -Value $false -MemberType NoteProperty
          $packingData | Add-Member -Name Lync -Value $false -MemberType NoteProperty
          $packingData | Add-Member -Name Taskforce -Value $null -MemberType NoteProperty
          $packingData | Add-Member -Name Logon -Value $packingData.SamAccountName -MemberType NoteProperty
          $packingData | Add-Member -Name smartcard -Value $packingData.SmartcardLogonRequired -MemberType NoteProperty
          $packingData.badPasswordTime = ([DateTime]::FromFileTime($packingData.badPasswordTime))
          $packingData.lastLogonTimestamp = ([DateTime]::FromFileTime($packingData.lastLogonTimestamp))
          $packingData.LockoutTime = ([DateTime]::FromFileTime($packingData.LockoutTime))
          $packingData.pwdLastSet = ([DateTime]::FromFileTime($packingData.pwdLastSet))
          $mb = $user.mail
          if($mb -ne $null){
            $packingData.Exchange = $true
          }
          if($packingData."msRTCSIP-UserEnabled"){
            $packingData.Lync = $true
          }
          switch -Wildcard ($packingData.DistinguishedName){
            "*TF_1*" {
              $packingData.Taskforce = "Task Force 1"
              break
            }
            "*TF_2*" {
              $packingData.Taskforce = "Task Force 2"
              break
            }
            "*TF_3*" {
              $packingData.Taskforce = "Task Force 3"
              break
            }
            "*TF_4*" {
              $packingData.Taskforce = "Task Force 4"
              break
            }
            "*TF_5*" {
              $packingData.Taskforce = "Task Force 5"
              break
            }
            "*TF_SUST*" {
              $packingData.Taskforce = "Task Force Sustainment"
              break
            }
            "*TF_AVN*" {
              $packingData.Taskforce = "Task Force Aviation"
              break
            }
            "*TF_BMC*" {
              $packingData.Taskforce = "Task Force BMC"
              break
            }
            "*TF_FS*" {
              $packingData.Taskforce = "Task Force FireSupport"
              break
            }
            "*TF_SOTD*" {
              $packingData.Taskforce = "Task Force SOTD"
              break
            }
            "*OPFOR*" {
              $packingData.Taskforce = "OpFor"
              break
            }
            "*Valiant*" {
              $packingData.Taskforce = "Valiant"
              break
            }
            "*LiveFire*" {
              $packingData.Taskforce = "LiveFire"
              break
            }
          }
          $packingData.PSObject.Properties.Remove("GivenName")
          $packingData.PSObject.Properties.Remove("Initials")
          $packingData.PSObject.Properties.Remove("Surname")
          $packingData.PSObject.Properties.Remove("DisplayName")
          $packingData.PSObject.Properties.Remove("AccountExpirationDate")
          $packingData.PSObject.Properties.Remove("mail")
          $packingData.PSObject.Properties.Remove("msRTCSIP-UserEnabled")
          $packingData.PSObject.Properties.Remove("SamAccountName")
          $packingData.PSObject.Properties.Remove("DistinguishedName")
          $packingData.PSObject.Properties.Remove("SmartcardLogonRequired")
          $packedData = New-Object -TypeName PSCustomObject
          forEach($prop in $packingData.PSObject.Properties){
            $packedData | Add-Member -Name (($prop.Name).Substring(0,1).ToLower()+($prop.Name).Substring(1,($prop.Name).Length-1)) -Value $packingData.($prop.Name) -MemberType NoteProperty
          }
          $packedData = $packedData | Select logon,enabled,lastLogonTimestamp,lockedOut,lockoutTime,badPasswordTime,pwdLastSet,passwordExpired,passwordNeverExpires,cannotChangePassword,expDate,smartcard,fname,mi,lname,dname,description,taskforce,exchange,lync,createTimeStamp,modified
          $byteMess = $enc.GetBytes(($packedData | ConvertTo-JSON))
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          $context.Response.Close()
        }
        else{
          $byteMess = $enc.GetBytes("BU")
          $context.Response.OutputStream.Write($byteMess,0,$byteMess.Length)
          $context.Response.Close()
        }
        break
      }

      "amManage" {
        $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
        $body = $bodyRead.ReadToEnd()
        $manInfo = $body | ConvertFrom-JSON
        forEach($prop in $manInfo.PSObject.Properties.Name){
          if($manInfo.($prop) -eq $null){
            $manInfo.($prop) = " "
          }
        }
        forEach($prop in $manInfo.PSObject.Properties.Name){
          switch($prop){
            "NewLogon"{
              $set = Set-ADUser -Identity $manInfo.Logon -UserPrincipalName "$($manInfo.NewLogon)@ctcis.local" -SamAccountName $manInfo.NewLogon
              break
            }
            "Enabled"{
              if($manInfo.Enabled){
                $en = Enable-ADAccount -Identity $manInfo.Logon
              }
              else{
                $en = Disable-ADAccount -Identity $manInfo.Logon
              }
              break
            }
            "Locked"{
              if(!($manInfo.Locked)){
                $lock = Unlock-ADAccount -Identity $manInfo.Logon
              }
              break
            }
            "Password Never Expires"{
              $set = Set-ADUser -Identity $manInfo.Logon -PasswordNeverExpires $manInfo.'Password Never Expires'
              break
            }
            "Cannot Change Password"{
              $set = Set-ADUser -Identity $manInfo.Logon -CannotChangePassword $manInfo.'Cannot Change Password'
              break
            }
            "Account Expiration"{
              $set = Set-ADUser -Identity $manInfo.Logon -AccountExpirationDate ([DateTime]::Parse($manInfo.'Account Expiration'))
              break
            }
            "Smartcard Required"{
              $set = Set-ADUser -Identity $manInfo.Logon -SmartcardLogonRequired $manInfo.'Smartcard Required'
              break
            }
            "First Name"{
              $set = Set-ADUser -Identity $manInfo.Logon -GivenName $manInfo.'First Name'
              break
            }
            "MI"{
              $set = Set-ADUser -Identity $manInfo.Logon -Initials $manInfo.MI
              break
            }
            "Last Name"{
              $set = Set-ADUser -Identity $manInfo.Logon -Surname $manInfo.'Last Name'
              break
            }
            "Display Name"{
              $set = Set-ADUser -Identity $manInfo.Logon -DisplayName $manInfo.'Display Name'
              break
            }
            "Description"{
              $set = Set-ADUser -Identity $manInfo.Logon -Description $manInfo.Description
              break
            }
            "Taskforce"{
              switch($manInfo.Taskforce){
                "Task Force 1" {
                  $ouSel = "OU=TF_1,OU=TASKFORCES,DC=ctcis,DC=local"
                  $grSel = @("Domain Users", "OCT BLUFOR", "TASKFORCE1", "TF_1")
                  break
                }
                "Task Force 2" {
                  $ouSel = "OU=TF_2,OU=TASKFORCES,DC=ctcis,DC=local"
                  $grSel = @("Domain Users", "OCT BLUFOR", "TASK FORCE 2", "TF_2")
                  break
                }
                "Task Force 3" {
                  $ouSel = "OU=TF_3,OU=TASKFORCES,DC=ctcis,DC=local"
                  $grSel = @("Domain Users", "OCT BLUFOR", "TASKFORCE 3", "TF_3")
                  break
                }
                "Task Force 4" {
                  $ouSel = "OU=TF_4,OU=TASKFORCES,DC=ctcis,DC=local"
                  $grSel = @("Domain Users", "OCT BLUFOR", "TASKFORCE 4", "TF_4")
                  break
                }
                "Task Force 5" {
                  $ouSel = "OU=TF_5,OU=TASKFORCES,DC=ctcis,DC=local"
                  $grSel = @("Domain Users", "OCT BLUFOR", "TASKFORCE 5", "TF_5")
                  break
                }
                "Task Force Sustainment" {
                  $ouSel = "OU=TF_SUST,OU=TASKFORCES,DC=ctcis,DC=local"
                  $grSel = @("Domain Users", "OCT BLUFOR", "TASKFORCE SUSTAINMENT", "TF_SUST")
                  break
                }
                "Task Force Aviation" {
                  $ouSel = "OU=TF_AVN,OU=TASKFORCES,DC=ctcis,DC=local"
                  $grSel = @("Domain Users", "OCT BLUFOR", "TASKFORCE AVIATION", "TF_AVN")
                  break
                }
                "Task Force BMC" {
                  $ouSel = "OU=TF_BMC,OU=TASKFORCES,DC=ctcis,DC=local"
                  $grSel = @("Domain Users", "OCT BLUFOR", "TASKFORCE BMC", "TF_BMC", "CTCS-D", "TAF")
                  break
                }
                "Task Force FireSupport" {
                  $ouSel = "OU=TF_FS,OU=TASKFORCES,DC=ctcis,DC=local"
                  $grSel = @("Domain Users", "OCT BLUFOR", "TASKFORCE FIRESUPPORT", "TF_FS", "MRC User", "SG_LIVEFIRE")
                  break
                }
                "Task Force SOTD" {
                  $ouSel = "OU=TF_SOTD,OU=TASKFORCES,DC=ctcis,DC=local"
                  $grSel = @("Domain Users", "OCT BLUFOR", "TF_SOTD")
                  break
                }
                "OpFor" {
                  $ouSel = "OU=OPFOR,OU=TASKFORCES,DC=ctcis,DC=local"
                  $grSel = @("Domain Users", "OCT OPFOR", "TF_OPFOR")
                  break
                }
                "Valiant" {
                  $ouSel = "OU=Valiant,OU=TASKFORCES,DC=ctcis,DC=local"
                  $grSel = @("Domain Users", "Contact Team", "VALIANT", "SG_VALIANT")
                  break
                }
                "LiveFire" {
                  $ouSel = "OU=LiveFire,OU=TASKFORCES,DC=ctcis,DC=local"
                  $grSel = @("Domain Users", "LiveFire Administrators", "SG_LIVEFIRE")
                  break
                }
              }
              $dn = (Get-ADUser -Identity $manInfo.Logon).DistinguishedName
              $move = Move-ADObject -Identity $dn -TargetPath $ouSel

              forEach($group in $grSel){
                if($group -ne "Domain Users"){
                  Add-ADGroupMember -Identity $group -Members $manInfo.Logon
                }
              }

              break
            }
            "Exchange"{
              $exSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://i-exch-01.ctcis.local/PowerShell/
              Import-PSSession $exSession -DisableNameChecking -CommandName Enable-Mailbox,Disable-Mailbox | Out-Null

              if($manInfo.Exchange){
                Function waitMB(){
                  $mb = (Get-ADUser -Identity $manInfo.Logon -Properties mail).mail
                  if($mb -eq $null){
                    if($global:mbCheck -ge 6){
                      return
                    }
                    $global:mbCheck += 1
                    Start-Sleep -Seconds 5
                    waitMB
                  }
                  else{
                    Start-Sleep -Seconds 10
                  }
                }
                $enMB = Enable-Mailbox $manInfo.Logon -ErrorAction:SilentlyContinue
                waitMB
              }
              else{
                $enMB = Disable-Mailbox -Identity $manInfo.Logon -Confirm:$false
              }
              break
            }
            "Lync"{
              $lySession = New-PSSession -ConnectionUri https://i-lync-01.ctcis.local/OcsPowershell -Authentication NegotiateWithImplicitCredential
              Import-PSSession $lySession -DisableNameChecking -CommandName Get-CsUser,Enable-CsUser,Disable-CsUser | Out-Null
       
              if($manInfo.Lync){
                Function waitLY(){
                  $ly = (Get-CsUser -Identity $manInfo.Logon -ErrorAction:SilentlyContinue).Enabled
                  if($ly -ne $true){
                    if($global:lyCheck -ge 6){
                      return
                    }
                    $global:lyCheck += 1
                    Start-Sleep -Seconds 5
                    waitLY
                  }
                }
                $enLY = enable-csuser -registrarpool "i-lync-01.ctcis.local" -sipaddresstype emailaddress -sipdomain "ctcis.local" -identity $manInfo.Logon -ErrorAction:SilentlyContinue | Out-Null
                waitLY
              }
              else{
                $enLY = Disable-CsUser -Identity $manInfo.Logon -Confirm:$false
              }
              break
            }
          }
        }        
        $context.Response.Close()

        "$((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: Account Modified - $($manInfo.Logon) - $(($manInfo.PSObject.Properties.Name  | ? {$_ -ne "Logon"}) -join ",")" | Add-Content -Force -Path c:\Automation\CRM\ad_actions_log.txt
        break
      }

      "amDelete" {
        $bodyRead = New-Object System.IO.StreamReader($context.Request.InputStream, $context.Request.ContentEncoding)
        $user = $null
        $user = $bodyRead.ReadToEnd()
        Remove-ADUser -Identity $user -Confirm:$false
        $context.Response.Close()

        "$((Get-Date).ToString("MM/dd/yyyy hh:mm:ss tt")):: Account Deleted - $user" | Add-Content -Force -Path c:\Automation\CRM\ad_actions_log.txt
        break
      }

      default {
        $context.Response.Close()
      }
    }
  }
  else{
    switch($request[0]){

      "favicon.ico" {
        $context.Response.Close()
        break
      }

      default {
        $context.Response.StatusCode = 404;
        $context.Response.Close()
      }
    }
  }
  Get-PSSession | Remove-PSSession
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
          AddArgument($context.Con.([String]$context.CurrentCon)).AddArgument($enc)
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
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUp4dwfgjzeMfXXw+B9Ng5QnVb
# 4d+gggUrMIIFJzCCBM2gAwIBAgIKZ5YFbgAAAABWmjAKBggqhkjOPQQDAjBLMRUw
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
# DQEJBDEWBBThS/O2aNCbEChMavFiZxkFZbVixzANBgkqhkiG9w0BAQEFAASCAQBA
# DIZLCrqeLLueB+C64uGM7p6y8YmDpzVFSrXcor7xBa3kvYNZjA1a1z7X66fYh7vv
# 32kemoxGxThGPiZLoDELlrYVu1tU0Yx7FzjveCNWgz4kYptwtdWy6sUg7rtUV7is
# SO9dxguq0RuezQpDUSQQvU6ku8P0sjzk0sgX1S1NwV0YsfDDwKvrzuAUm8Z/BL4S
# 5cVvxjLH/BnGZUxCzt+qONA2P2wU4HPTKnvCatmm2vVIzvrtHz0oiUN2XLhENwc0
# u9Mh92EI7F0U9DSCCqSk4qXUmG/UHqN/AqLbMynm6VsKH7vHT4cCjFK9Gz02Jw8Q
# htxyK+tiTiAZI7Jj7jDx
# SIG # End signature block
