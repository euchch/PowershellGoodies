# $Channels = @("19088261", "28891610", "28937804")
$Channels = @("19088261")
$global:ScottyBotBaseUrl = "https://scottybot.net/api/showcoms"
$ScottyBotCommandsList = "https://scottybot.net/api/showcoms?chanid=19088261&output=json"
$ScottyBotCommandsTrackingList = @("!lastdrop")
$LatestDropCommand = ""
$DropsDict = @{}
$infinity = $false
$GlobalCode = ""

Function GetLastDrop {
    $scottyBotCommands = $(Invoke-WebRequest -Uri $ScottyBotCommandsList).Content
    $commdsObject = ConvertFrom-Json $scottyBotCommands
    $latestDrop = $($commdsObject | Where-Object{$_.cmd -match $ScottyBotCommandsTrackingList})
    return $latestDrop.output
}

Function GetLastMultiDrop {
    param([string]$channelId)
    $returnDict = @{}
   $pollingUrl = "$($ScottyBotBaseUrl)?chanid=$channelId&output=json"
    $scottyBotCommands = $(Invoke-WebRequest -Uri $pollingUrl).Content
    ForEach ($cmd in $ScottyBotCommandsTrackingList) {
        $commdsObject = ConvertFrom-Json $scottyBotCommands
        $latestDrop = $($commdsObject | Where-Object{$_.cmd -match $cmd})
        $returnDict.Add("$channelId$cmd",$($latestDrop.output))
    }
    return $returnDict
}

function Show-BalloonTip {            
    [cmdletbinding()]            
    param(            
     [parameter(Mandatory=$true)]            
     [string]$Title,            
     [ValidateSet("Info","Warning","Error")]             
     [string]$MessageType = "Info",            
     [parameter(Mandatory=$true)]            
     [string]$Message,            
     [string]$Duration=10000            
    )            
    
    [system.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null            
    $balloon = New-Object System.Windows.Forms.NotifyIcon            
    $path = Get-Process -id $pid | Select-Object -ExpandProperty Path            
    $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path)            
    $balloon.Icon = $icon            
    $balloon.BalloonTipIcon = $MessageType            
    $balloon.BalloonTipText = $Message            
    $balloon.BalloonTipTitle = $Title            
    $balloon.Visible = $true            
    $balloon.ShowBalloonTip($Duration)            
    
}

function ResetDrops {
    $DropsDict = @{}
    ForEach ($channel in $Channels) {
        ForEach ($cmd in $ScottyBotCommandsTrackingList) {
            $DropsDict.Add("$channel$cmd","")
        }
    }
}

function BasePoling {
    do {
        try {
            $NewestDrop = GetLastDrop
            if ($NewestDrop -ne $LatestDropCommand) {
                Show-BalloonTip -Title "Smite have just posted a new code" -MessageType Warning -Message $NewestDrop -Duration 1000
                if ($NewestDrop -match "^Most Recent Code:" ) {
                    $code = $NewestDrop.Split(':')[1]
                    Write-Output "/claimpromotion$code"
                } else {
                    Write-Output $NewestDrop
                }
    
            $LatestDropCommand = $NewestDrop
        }
    } catch {
        Write-Host "Timeout polling the code, will retry later"
    }
    start-sleep -Seconds 120
    } until($infinity)
}

function MultiPoling {
    do {
        try {
            ForEach ($channel in $Channels) {
                $NewestDrop = GetLastMultiDrop($channel)
                ForEach ($drop in $NewestDrop.Keys) {
                    if (($DropsDict[$drop] -ne $NewestDrop[$drop]) -and ($NewestDrop[$drop] -ne $GlobalCode)) {
                        $GlobalCode = $NewestDrop[$drop]
                        $now = "{0:HH}:{0:mm}" -f $(Get-Date)
                        if ($NewestDrop[$drop] -match "^Most Recent Code:" ) {
                            $code = $NewestDrop[$drop].Split(':')[1]
                            $cpCode = "/claimpromotion$code"
                            Set-Clipboard -Value $cpCode
                            Write-Output "$now => $cpCode"
                        } else {
                            Write-Output "$now => $($NewestDrop[$drop])"
                        }
                    }
                    $DropsDict[$drop] = $NewestDrop[$drop]
                }
            }
        } catch {
            Write-Host "Timeout polling the code, will retry later"
        }
    Start-Sleep -Seconds 20
    } until($infinity)
}

MultiPoling

