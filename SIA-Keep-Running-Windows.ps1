#Clear-Host
 # Don't run this script if you plan on doing some heavy work like moving data between disks or something like that which can lock up your host.
 # Schedule this script to run every 10 min or so


#Replace xxx with your values
# find $siaHostPassword here: %LOCALAPPDATA%\Sia\apipassword

$siacentralUrl = 'https://api.siacentral.com/v2/troubleshoot/xxx';
$siaPath = 'C:\Users\xxx\AppData\Local\Programs\Sia-UI\Sia-UI.exe'
$siaHostPassword = 'xxx'
$uptimerobotUrl = $null;
#$uptimerobotUrl = 'https://api.uptimerobot.com/v2/getMonitors?api_key=xxx&monitors=xxx';
#$uptimerobotMonitorId = 'xxx'
$restartIfRamLessThanMB = 500



function StopSia{
    Write-Host 'Stopping sia host'

    $user = ''
    $pass = $siaHostPassword
    $userAgent = 'Sia-Agent'

    $pair = "$($user):$($pass)"

    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))

    $basicAuthValue = "Basic $encodedCreds"

    $Headers = @{
        Authorization = $basicAuthValue
    }

    Invoke-WebRequest -Uri 'http://localhost:9980/daemon/stop' -Headers $Headers -UserAgent $userAgent -UseBasicParsing | Select-Object -Expand Content
}

function ResetHost{
    Write-Host 'Host not running normal, stopping host'

    StopSia;

    Write-Host 'Sleep 60sec to allow host to stop'
    Start-Sleep -s 60

    Write-Host 'Stopping sia proccess with the force'
    Get-Process "siad" | Stop-Process -Force
    Get-Process "siad.exe" | Stop-Process -Force
    Get-Process "Sia-UI" | Stop-Process -Force

    Write-Host 'Clear network cache'
    Clear-DnsClientCache
	arp -d *
	nbtstat -R
	nbtstat -RR

    Write-Host 'Sleep 5sec'
    Start-Sleep -s 5

    Write-Host 'Starting sia host'
    Start-Process -FilePath $siaPath
}


$freeram = Get-CIMInstance Win32_OperatingSystem | Select FreePhysicalMemory
if(($freeram.FreePhysicalMemory/1000) -lt $restartIfRamLessThanMB){
    Write-Host 'Host not running normal, stopping host'
    StopSia;
    Write-Host 'Sleep 120sec to allow host to stop'
    Start-Sleep -s 120
    Restart-Computer -Force
}else{
    Write-Host 'Host has ram to continue'
    Write-Host ' '
}


$resetHost = $false;

if($uptimerobotUrl -ne $null){
    Write-Host "Calling uptimerobot.com"

    $utrResponse = Invoke-RestMethod -Method 'Post' -URI $uptimerobotUrl -UseBasicParsing
    $utrResponse | ConvertTo-Json
    $utrObj = $utrResponse.monitors | where { $_.id -eq $uptimerobotMonitorId }
    
    if($utrObj -ne $null -and $utrObj.status -ne 2 -and $resetHost -eq $false){
        Write-Host 'Trigger ResetHost, uptimerobot shows host is down'
        $resetHost = $true;
        ResetHost;
    }
}

if($resetHost -eq $false){
    Write-Host "Calling siacentral.com 1. time"

    $response = Invoke-RestMethod -URI $siacentralUrl -UseBasicParsing
    $response | ConvertTo-Json

    if($response -ne $null -and $response.report -ne $null -and ($response.report.connected -eq $false -Or  $response.type -ne 'success' -Or $response.report.errors -ne $null)){
        
        if($response.report.errors -ne $null -and ($response.report.errors | Out-String).Contains("is not accepting")){
            Write-Host 'Host running normal and Host is not accepting contracts'
        }
        else{
            Write-Host 'Sleep 300sec and retry as first call to siacentral.com shows there are issues with the host'
            Start-Sleep -s 300

            Write-Host "Calling siacentral.com 2. time"
            $response2 = Invoke-RestMethod -URI $siacentralUrl -UseBasicParsing
            $response2 | ConvertTo-Json

            if($response2 -ne $null -and $response2.report -ne $null -and ($response2.report.connected -eq $false -Or  $response2.type -ne 'success' -Or $response2.report.errors -ne $null)){
                Write-Host 'Trigger ResetHost, siacentral.com shows host is down or has issues'
                ResetHost;
            }
	        else{
        	    Write-Host 'Host running normal again'            
    	    }
        }
    }
    else{
        Write-Host 'Host running normal'
    }
}
