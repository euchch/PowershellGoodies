# Updating active network interface with needed suffixes as W10 keeps on removing them ALL THE TIME when switching wifi/use VPN (windows only)
If ((Test-Path env:OS) -and ($env:OS -match 'Windows')) {
    $aryDNSSuffixes = "doubleverify.prod", "doubleverify.corp", "c.staging-1470085110340.internal", "c.prod-1306.internal", "c.dvdev-141815.internal"
    $obj = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object {-not ($_.IPAddress -match '^172' -or $_.IPAddress -eq $null) -and $_.DHCPEnabled -eq $true}
    $obj | ForEach-Object {Invoke-CIMMethod -Class win32_networkadapterconfiguration -Name SetDNSSuffixSearchOrder 
                                            -Arguments @{"DNSDomainSuffixSearchOrder"=$aryDNSSuffixes}}
}

# Meant to allow us running lots of commands in parallel, using jobs 
function Parallel {
	param([int]$Limit,
		[String]$Command
	)
	
	$runningJobs = @(Get-Job -State Running)
	if ($runningJobs.Count -ge $Limit) {
		$finishedJob = $runningJobs | Wait-Job -Any
		$copmletedJobs = @(Get-Job -State Running)
		if ($copmletedJobs.Count -gt 1024) {
			$copmletedJobs | Remove-Job
		}
	}
	$sb = [scriptblock]::create("$Command")
	$job = Start-Job -Name $Command -ScriptBlock $sb
	Write-Host "Running command: $($job.Command)"
}

function printFromTo {
	param([string]$Command,
		[String]$PrintFrom,
		[string]$PrintTo,
		[string]$Exception
	)

    if ([string]::IsNullOrEmpty($Command)) {
        return
    }
	
	$sb = [scriptblock]::create("$Command")
	Invoke-Command $sb | ForEach-Object -Begin {$printOutput=$False} {
													if ($_ -match $PrintFrom) {$printOutput=$True}; 
													if ($_ -match $PrintTo) {$printOutput=$False}; 
													if ($printOutput) {Write-Output $_}; 
													if (-not ($printOutput) -and ($_ -match $Exception)) {Write-Output $_}; 
												}
}

function getPSCredentials {
    param ([string]$User)

    if ([string]::IsNullOrEmpty($User)) {
        return
    }

    Write-Host "Please enter password for user $User"
    $secpasswd = Read-Host -AsSecureString
    $psCred = New-Object System.Management.Automation.PSCredential ($User, $secpasswd)
    return $psCred
}

function installVertica {
    # Find vertica installation
    $currentVerticaClient = Get-CimInstance -ClassName Win32_Product | Where-Object { $_.Name -match 'Vertica' }
    if ($currentVerticaClient.Count) {
        if ($currentVerticaClient[0].Version -ge '8.1.1') {
            return
        }
    } else {
        if ($currentVerticaClient.Version -ge '8.1.1') {
            return
        }
    }
    $currentVerticaClient.Uninstall()
    Set-Location $env:temp
    Invoke-WebRequest -Uri 'https://my.vertica.com/client_drivers/8.1.x/8.1.1-8/VerticaSetup-8.1.1-8.exe' -OutFile 'VerticaSetup-8.1.1-8.exe'
    VerticaSetup-8.1.1-8.exe -q -install
}
