# siahosting-windows
# use at own risk

Fix for sia hosting on windows

replace xxx with your own values and save as powershell file, and run the script scheduled for repeat every 10 min.

$url = 'https://api.siacentral.com/v2/troubleshoot/xxx';

$siaPath = 'C:\Users\xxx\AppData\Local\Programs\Sia-UI\Sia-UI.exe'

function StopSia{
    Write-Host 'Stopping sia'

    $user = ''
    $pass = 'xxx'
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
    Write-Host 'Host not running normal'

    StopSia;

    Write-Host 'Sleep 60sec'
    Start-Sleep -s 60

    Write-Host 'Stopping sia process'
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

    Write-Host 'Starting sia'
    Start-Process -FilePath $siaPath
}

$response0 = Invoke-RestMethod -Method 'Post' -URI 'https://api.uptimerobot.com/v2/getMonitors?api_key=xxx&monitors=xxx' -UseBasicParsing
$response0 | ConvertTo-Json

$resp0obj = $response0.monitors | where { $_.id -eq "xxx" }

if($resp0obj -ne $null -and $resp0obj.status -ne 2){
    Write-Host 'Trigger ResetHost'
    ResetHost;
}
else{

    $response = Invoke-RestMethod -URI $url -UseBasicParsing
    $response | ConvertTo-Json

    Write-Host ' '
    Write-Host ' '

    if($response -ne $null -and ($response.report.connected -eq $false -Or  $response.type -ne 'success' -Or $response.report.errors -ne $null)){
        Write-Host 'Sleep 120sec'
        Start-Sleep -s 120

        $response2 = Invoke-RestMethod -URI $url -UseBasicParsing
        $response2 | ConvertTo-Json

        if($response2 -ne $null -and ($response2.report.connected -eq $false -Or  $response2.type -ne 'success' -Or $response2.report.errors -ne $null)){
            Write-Host 'Trigger ResetHost'
            ResetHost;
        }
	    else{
        	Write-Host 'Host running normal'
    	}
    }
    else{
        Write-Host 'Host running normal'
    }
}
