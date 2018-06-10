$ScottyBotCommandsList = "https://scottybot.net/api/showcoms?chanid=19088261&output=json"
$ScottyBotCommandsTrackingList = @("!lastdrop")
$LatestDropCommand = ""
$infinity = $false

Function GetLastDrop {
    $scottyBotCommands = $(Invoke-WebRequest -Uri $ScottyBotCommandsList).Content
    $commdsObject = ConvertFrom-Json $scottyBotCommands
    $latestDrop = $($commdsObject | Where-Object{$_.cmd -match $ScottyBotCommandsTrackingList})
    return $latestDrop.output
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

do{
    try {
        $NewestDrop = GetLastDrop
    } catch {
        continue;
        start-sleep -Seconds 120
    }
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
    start-sleep -Seconds 120
}until($infinity)
