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
