param (
    [Parameter(Mandatory=$true)]
    #[ValidateScript({$_.Trim() -match [IPAddress]$_.Trim()})]
    [ValidateScript({[Bool]($_.Trim() -as [IPAddress])})]
    [string]$IPAddress

)

[string]$IP = $IPAddress.Trim()
[IPAddress]$IPAddress = $IP
[string]$Global:DNSName = ""
$ErrorActionPreference = "Continue"
$Error.Clear()
$WShell = New-Object -ComObject Wscript.Shell

if ($PSCommandPath -eq $null) { function Get-PSCommandPath() { return $MyInvocation.PSCommandPath; } $PSCommandPath = Get-PSCommandPath; }

function Check-DNSChanged {
    [string]$DNSName = "No DNS Record"

    try {
        ipconfig /flushdns | Out-Null
        [string]$DNSName = ([System.Net.Dns]::GetHostEntry($IP))[0].HostName
        $DNSName = $DNSName.Trim()
        if ($Global:DNSName -eq $DNSName -or (-not $Global:DNSName) -or $Global:DNSName.Length -le 0) { $Global:DNSName = $DNSName; return $false }
        $Global:DNSName = $DNSName
        return $true
    }
    catch [System.Net.Sockets.SocketException] {
        $DNSName = "No DNS Record"
        if (-not $Global:DNSName -or $Global:DNSName.Length -le 0) { $Global:DNSName = $DNSName }
        Write-Output ""
        Write-Warning "No PTR record exists in DNS"
        #Write-Warning $_.Exception.ToString()
        #Write-Output ""
        #Write-Warning $Error[0].Exception.InnerException # Gives same output as below command
    }
    catch {
        $DNSName = "No DNS Record"
        if (-not $Global:DNSName -or $Global:DNSName.Length -le 0) { $Global:DNSName = $DNSName }
        Write-Warning $_.Exception.ToString()
    }
    return $false
}

# loop while device unreachable (stop after 10 minutes if still offline)
function Check-Offline {
    $to = New-TimeSpan -Minutes 8
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while($sw.Elapsed -lt $to) {
        while((Test-Connection $IPAddress -Count 3 -Quiet) -eq $false) {
            Write-Output "$IPAddress ($Global:DNSName) is REBOOTING...`n"
            Start-Sleep -Seconds 45
        }
        break
    }
}

# Device back online
function Check-Online {
    # Device Starting back up
    if (Test-Connection $IPAddress -Count 3 -Quiet) {
        Write-Output "`n$IPAddress ($Global:DNSName) is starting up..."
        if (Check-DNSChanged) { Write-Output "New DNS Name assigned." }
    }

    if (Test-Connection $IPAddress -Count 8 -Quiet) { # -count 10 is just a little longer than actual
        Write-Output "`n$IPAddress ($Global:DNSName) is ONLINE now."
    }
}



<#
# Main
#>
##Write-Output "Input:`t $IP ($Global:DNSName)`n`n"

while(Test-Connection $IPAddress -Count 3 -Quiet) {
    Check-DNSChanged | Out-Null
    Write-Output "`n$IPAddress ($Global:DNSName) has NOT started rebooting yet!"
    Start-Sleep -Seconds 15
}

# Loop while device unreachable
Check-Offline

# Cloning Completed: Device now Online
Check-Online

# Device Rebooting again as part of cloning process
Check-Offline

$WShell.Popup("$IPAddress ($Global:DNSName) is Online Again",0,$PSCommandPath,0x41)
return $true