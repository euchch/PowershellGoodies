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
	kubectl.exe config use-context nycd_cluster
	Set-Variable -Name dvEnvironment -Value "" -Scope Global
}

function dvProdConnect() {
	kubectl.exe config use-context nycp_cluster
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
        kubectl.exe get pods
        return
    }

    if ($Search) {
        kubectl.exe get pods | Where-Object {$_ -match $NameSpace}
        return
    }

    kubectl.exe get pods -n "$dvEnvironment-in-$NameSpace"
}

function gcSwitchContext {
    param([string]$NameSpace,
		[switch]$FullName
    )

	$nameSpace = $NameSpace
	if (-not $FullName) {
		$nameSpace = "$dvEnvironment-in-$nameSpace"
	}

    kubectl.exe config current-context | ForEach-Object { kubectl.exe config set-context $_ --namespace=$nameSpace }
}
