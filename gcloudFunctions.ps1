# DV Context variables
$dvDevProject = "" ## update <dvDevProject>
$dvDevContainer = "" ## update <dvDevContainer>

$dvStagingProject = "" ## update <dvStagingProject>
$dvStagingContainer = "" ## update <dvStagingContainer>

$dvProdProject = "" ## update <dvProdProject>
$dvProdContainer = "" ## update <dvProdContainer>

$dvDefaultZone = "us-east1-b"
$dvEnvironment = ""

# GCloud Environment connection commands
function devConnect() {
    gcloud container clusters get-credentials $dvDevContainer --zone $dvDefaultZone --project $dvDevProject
    gcloud config set project $dvDevProject
    gcloud config list
    Set-Variable -Name dvEnvironment -Value "d" -Scope Global
}
function stgConnect() {
    gcloud container clusters get-credentials $dvStagingContainer --zone $dvDefaultZone --project $dvStagingProject
    gcloud config set project $dvStagingProject
    gcloud config list
    Set-Variable -Name dvEnvironment -Value "s" -Scope Global
}
function prodConnect() {
    gcloud container clusters get-credentials $dvProdContainer --zone $dvDefaultZone --project $dvProdProject
    gcloud config set project $dvProdProject
    gcloud config list
    Set-Variable -Name dvEnvironment -Value "p" -Scope Global
}

function dvDevConnect() {
	kubectl config use-context nycd_cluster
	Set-Variable -Name dvEnvironment -Value "" -Scope Global
}

function dvProdConnect() {
	kubectl config use-context nycp_cluster
	Set-Variable -Name dvEnvironment -Value "" -Scope Global
}

# DV Gcloud connect
function gcConn {
    param([string]$Environment,
    [string]$SwitchToContext
    )

    switch ($Environment) {
        "dev" {devConnect; gcSwitchContext($SwitchToContext)}
        "staging" {stgConnect; gcSwitchContext($SwitchToContext)}
        "prod" {prodConnect; gcSwitchContext($SwitchToContext)}
        "dvDev" {dvDevConnect}
        "dvProd" {dvProdConnect}
        default {Write-Output "Please select 'dev', 'staging', 'prod' or 'dvProd' environments"}
    }
}

function gcGetPods {
    param([string]$NameSpace,
    [switch]$Search
    )

    if ([string]::IsNullOrEmpty($NameSpace)) {
        kubectl get pods
        return
    }

    if ($Search) {
        kubectl get pods | Where-Object {$_ -match $NameSpace}
        return
    }

    kubectl get pods -n "$dvEnvironment-in-$NameSpace"
}

function gcSwitchContext {
    param([string]$NameSpace,
		[switch]$FullName
    )

	$nameSpace = $NameSpace
	if (-not $FullName) {
		$nameSpace = "$dvEnvironment-in-$nameSpace"
	}

    kubectl config current-context | ForEach-Object { kubectl config set-context $_ --namespace=$nameSpace }
}

function gcClearJobs {
	param([string]$JobRegex)

    if ([string]::IsNullOrEmpty($JobRegex)) {
        return
    }
	
	kubectl get jobs | Where-Object {$_ -match $JobRegex } | % {Write-Output "kubectl delete job $($_.split(' ')[0])"} | % { (Parallel -Command $_ -Limit 30) }
}

function gcToObject {
	param([string]$gcCommand)

    if ([string]::IsNullOrEmpty($gcCommand)) {
        return
    }
	
	$sb = [scriptblock]::create("$gcCommand")
	$csvOutput = Invoke-Command $sb | ForEach-Object -Begin {$tempOutput=""} {$line = $_ -replace '\s+',','; $tempOutput += "$line`n"} -end {Write-Output $tempOutput} | ConvertFrom-Csv
	Write-Output $csvOutput
}

function gcPodBash {
	param([Parameter(Mandatory)][string]$PodName)

    if ([string]::IsNullOrEmpty($PodName)) {
        return
    }
	
	kubectl exec -it $PodName bash
}

function gcPodCommand {
	param([Parameter(Mandatory)][string]$PodName,
	[string]$PodCommand)

    if ([string]::IsNullOrEmpty($PodCommand)) {
		gcPodBash -PodName $PodName
        return
    }
	
	Write-Host "Running $PodCommand on $PodName"
	
	kubectl exec -t $PodName -- $($PodCommand -split "\s+")
}

function gcGetRandomPod {
	param([Parameter(Mandatory)][string]$PodRegex)

    if ([string]::IsNullOrEmpty($PodRegex)) {
        return
    }
	
	$pods = gcToObject "kubectl.exe get pods" | Where-Object {$_.NAME -match $PodRegex}
	if ($pods.Count -eq 0) {
		return
	}
	$randomPod = $pods | Get-Random
	return $randomPod.NAME
}

function gcGetActivePods {
	printFromTo -Command "kubectl describe nodes" -PrintFrom "Non-terminated Pods:" -PrintTo "Allocated resources:" -Exception "Name:"
}

function gcFindResource {
	param([Parameter(Mandatory)][string]$ResourceRegex)

    if ([string]::IsNullOrEmpty($ResourceRegex)) {
        return
    }
	
	kubectl.exe get all --all-namespaces | Where-Object {$_ -match $ResourceRegex}
	if ($pods.Count -eq 0) {
		return
	}
	$randomPod = $pods | Get-Random
	return $randomPod.NAME
}

function gcRescale {
	param([Parameter(Mandatory)][string]$DeploymentRegex,
		[int]$ReplicasCount
	)

    if ([string]::IsNullOrEmpty($DeploymentRegex)) {
        return
    }
	
    if ([string]::IsNullOrEmpty($ReplicasCount)) {
        return
    }
	
	$deploymentToRescale = gcToObject "kubectl.exe get deployments" | Where-Object { $_.NAME -match $DeploymentRegex} | Select-Object -First 1
	kubectl.exe scale deployment $deploymentToRescale.NAME --replicas=$ReplicasCount
	Write-Host "Scaled to to $ReplicasCount replicas"
}

function gcDataprocConnect {
    param([Parameter(Mandatory)][string]$Environment,
    [string]$ClusterName
    )
	
	$dvEnv = ""

    switch ($Environment) {
        "prime" {$dvEnv = $dvPrimeProject}
        "dev" {$dvEnv = $dvDevProject}
        "staging" {$dvEnv = $dvStagingProject}
        "prod" {$dvEnv = $dvProdProject}
        default {Write-Output "Please select 'dev', 'staging' or 'prod' environments"}
    }
	
	gcConn $Environment
	$dpSelectedCluster = gcToObject "gcloud dataproc clusters list" | Where-Object { $_.NAME -match $ClusterName -and $_.STATUS -match 'RUNNING'} | Select-Object -First 1
	$dvMaster = $dpSelectedCluster.NAME
	$dvZone = $dpSelectedCluster.ZONE
	
	gcToObject "gcloud compute --project $dvEnv ssh --zone $dvZone $($dpSelectedCluster.NAME)-m"
}

function gcGetActiveSparkApplications {
    param([Parameter(Mandatory)][string]$Environment,
    [string]$ClusterName,
	[switch]$SpecificClusterName
    )
	
	$dvEnv = ""

    switch ($Environment) {
        "prime" {$dvEnv = $dvPrimeProject}
        "dev" {$dvEnv = $dvDevProject}
        "staging" {$dvEnv = $dvStagingProject}
        "prod" {$dvEnv = $dvProdProject}
        default {Write-Output "Please select 'dev', 'staging' or 'prod' environments"}
    }
	if ($SpecificClusterName) {
		$dvMaster = $ClusterName
		$dvZone = $dvDefaultZone
	} else {
		gcConn $Environment
		$dpSelectedCluster = gcToObject "gcloud dataproc clusters list" | Where-Object { $_.NAME -match $ClusterName} | Select-Object -First 1
		$dvMaster = $dpSelectedCluster.NAME
		$dvZone = $dpSelectedCluster.ZONE
	}

	$a = gcToObject "gcloud compute --project $dvEnv ssh --zone $dvZone $dvMaster-m --command 'yarn application --list' | Select -Skip 1" | ft
	Write-Output $a
}

function gcInstanceBash {
	param([Parameter(Mandatory)][string]$PodName)

    if ([string]::IsNullOrEmpty($PodName)) {
        return
    }
	
	if ([string]::IsNullOrEmpty($dvEnvironment)) {
        return
    }

    switch ($dvEnvironment) {
        "dev" {$dvEnv = $dvDevProject}
        "staging" {$dvEnv = $dvStagingProject}
        "prod" {$dvEnv = $dvProdProject}
        default {return}
    }
	
	gcloud compute --project $dvEnv ssh --zone $dvDefaultZone "$PodName"
}
