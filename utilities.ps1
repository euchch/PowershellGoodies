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