# =========================================================
# Load Central Config
# =========================================================

$script:ModuleRoot = Split-Path -Parent $PSScriptRoot
$script:ConfigPath = Join-Path $script:ModuleRoot "config.json"

if (!(Test-Path $script:ConfigPath)) {
    $fallbackConfigPath = "C:\ProgramData\Pipeline\config.json"
    if (Test-Path $fallbackConfigPath) {
        $script:ConfigPath = $fallbackConfigPath
    }
    else {
        throw "Missing config file: $script:ConfigPath"
    }
}

$script:Config = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json

# =========================================================
# Config compatibility and defaults
# =========================================================

$script:DefaultBase = Split-Path -Parent $script:ModuleRoot

function Get-ConfigProperty {
    param(
        $Object,
        [string]$Name,
        $Default
    )

    if ($null -ne $Object -and $null -ne $Object.$Name -and $Object.$Name.Trim() -ne '') {
        return $Object.$Name
    }

    return $Default
}

$ConfigBase = Get-ConfigProperty $script:Config Base $script:DefaultBase

$ConfigPaths = @{}
$ConfigPaths.PowerShell   = Get-ConfigProperty $script:Config.Paths PowerShell 'POWERSHELL FILES'
$ConfigPaths.Batch        = Get-ConfigProperty $script:Config.Paths Batch 'BATCH FILES'
$ConfigPaths.Temp         = Get-ConfigProperty $script:Config.Paths Temp 'Temp'
$ConfigPaths.Logs         = Get-ConfigProperty $script:Config.Paths Logs 'logs'
$ConfigPaths.TempOriginal = Get-ConfigProperty $script:Config.Paths TempOriginal 'TempOriginal'
$ConfigPaths.TempProxy    = Get-ConfigProperty $script:Config.Paths TempProxy 'TempProxy'
$ConfigPaths.Processed    = Get-ConfigProperty $script:Config.Paths Processed 'Processed'
$ConfigPaths.RepairQueue  = Get-ConfigProperty $script:Config.Paths RepairQueue 'Repair_Queue'
$ConfigPaths.RepairArchive= Get-ConfigProperty $script:Config.Paths RepairArchive 'RepairArchive'

$ConfigFiles = @{}
$ConfigFiles.CacheFile     = Get-ConfigProperty $script:Config.Files CacheFile 'cache.json'
$ConfigFiles.ScanState     = Get-ConfigProperty $script:Config.Files ScanState 'scanstate.json'
$ConfigFiles.RepairMap     = Get-ConfigProperty $script:Config.Files RepairMap 'repairmap.json'
$ConfigFiles.MuxQueue      = Get-ConfigProperty $script:Config.Files MuxQueue 'muxqueue.json'
$ConfigFiles.PipelineLog   = Get-ConfigProperty $script:Config.Files PipelineLog 'pipeline.log'
$ConfigFiles.DebugLog      = Get-ConfigProperty $script:Config.Files DebugLog 'debug.log'
$ConfigFiles.FFmpegLog     = Get-ConfigProperty $script:Config.Files FFmpegLog 'ffmpeg.log'
$ConfigFiles.IdleFlag      = Get-ConfigProperty $script:Config.Files IdleFlag 'idle.flag'
$ConfigFiles.PauseFlag     = Get-ConfigProperty $script:Config.Files PauseFlag 'pause.flag'
$ConfigFiles.ForceScanFlag = Get-ConfigProperty $script:Config.Files ForceScanFlag 'force.scan.flag'

$ConfigTools = @{}
$ConfigTools.ffmpeg  = Get-ConfigProperty $script:Config.Tools ffmpeg 'ffmpeg'
$ConfigTools.ffprobe = Get-ConfigProperty $script:Config.Tools ffprobe 'ffprobe'
$ConfigTools.rclone  = Get-ConfigProperty $script:Config.Tools rclone 'rclone'

# =========================================================
# Shared Base Paths
# =========================================================

$Global:Base = $ConfigBase

$Global:PS   = Join-Path $Global:Base $ConfigPaths.PowerShell
$Global:BAT  = Join-Path $Global:Base $ConfigPaths.Batch
$Global:TXT  = Join-Path $Global:Base $ConfigPaths.Temp
$Global:LOGS = Join-Path $Global:Base $ConfigPaths.Logs

# =========================================================
# Shared Files
# =========================================================

$Global:CacheFile     = Join-Path $Global:TXT $ConfigFiles.CacheFile
$Global:ScanStateFile = Join-Path $Global:TXT $ConfigFiles.ScanState
$Global:RepairMapFile = Join-Path $Global:TXT $ConfigFiles.RepairMap
$Global:MuxQueue      = Join-Path $Global:TXT $ConfigFiles.MuxQueue
$Global:TempOriginal  = Join-Path $Global:Base $ConfigPaths.TempOriginal
$Global:TempProxy     = Join-Path $Global:Base $ConfigPaths.TempProxy
$Global:Processed     = Join-Path $Global:Base $ConfigPaths.Processed
$Global:RepairQueue   = Join-Path $Global:Base $ConfigPaths.RepairQueue

# =========================================================
# Logs
# =========================================================

$Global:LogPath      = Join-Path $Global:LOGS $ConfigFiles.PipelineLog
$Global:DebugLogPath = Join-Path $Global:LOGS $ConfigFiles.DebugLog
$Global:FFmpegLog    = Join-Path $Global:LOGS $ConfigFiles.FFmpegLog

# =========================================================
# Flags
# =========================================================

$Global:VerboseFlag = Join-Path $Global:TXT "verbose.flag"
$Global:IdleFlag    = Join-Path $Global:TXT $ConfigFiles.IdleFlag
$Global:PauseFlag   = Join-Path $Global:TXT $ConfigFiles.PauseFlag
$Global:ForceScanFlag = Join-Path $Global:TXT $ConfigFiles.ForceScanFlag

# =========================================================
# Tools
# =========================================================

$Global:FFMPEG  = $ConfigTools.ffmpeg
$Global:FFPROBE = $ConfigTools.ffprobe
$Global:RCLONE  = $ConfigTools.rclone

# =========================================================
# Path Functions
# =========================================================

$Global:RepairQueue =
    Join-Path $Global:Base $ConfigPaths.RepairQueue

$Global:RepairArchive =
    Join-Path $Global:Base $ConfigPaths.RepairArchive

function Get-PipelineLogPath {
    return $Global:LogPath
}

function Get-DebugLogPath {
    return $Global:DebugLogPath
}

function Get-FFmpegLogPath {
    return $Global:FFmpegLog
}

# =========================================================
# DISCORD WEBHOOK FUNCTIONS
# =========================================================

function Send-DiscordLog {
    param(
        [string]$Tag,
        [string]$Message,
        [string]$Level = "INFO"
    )

    # Check if Discord notifications are enabled
    if ($null -eq $script:Config.Notifications -or 
        -not $script:Config.Notifications.DiscordWebhookEnabled) {
        return
    }

    $WebhookUrl = $script:Config.Notifications.DiscordWebhook
    if ([string]::IsNullOrWhiteSpace($WebhookUrl)) {
        return
    }

    # Map log levels to Discord embed colors
    $ColorMap = @{
        "ERROR"   = 15158332   # Red
        "WARNING" = 16776960   # Yellow
        "DEBUG"   = 9807270    # Gray
        "INFO"    = 3447003    # Blue
        "SUCCESS" = 3066993    # Green
        "TRACE"   = 5793266    # Dark Gray
    }

    $Color = $ColorMap[$Level]
    if ($null -eq $Color) {
        $Color = $ColorMap["INFO"]
    }

    # Add text prefix based on level
    $Emoji = switch($Level) {
        "ERROR"   { "ERROR" }
        "WARNING" { "WARNING" }
        "DEBUG"   { "DEBUG" }
        "SUCCESS" { "SUCCESS" }
        default   { "INFO" }
    }

    # Truncate message if too long (Discord limit)
    $TruncatedMsg = if ($Message.Length -gt 1024) { 
        $Message.Substring(0, 1021) + "..."
    } else { 
        $Message 
    }

    try {
        $embed = @{
            title       = "$Emoji $Tag - $Level"
            description = $TruncatedMsg
            color       = $Color
            footer      = @{
                text = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            }
            timestamp   = (Get-Date -Format o)
        }

        $payload = @{
            embeds = @($embed)
        } | ConvertTo-Json -Depth 10

        Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null
    }
    catch {
        # Silently fail - don't want logging errors to break the pipeline
    }
}

# -------------------------
# INIT
# -------------------------
function Initialize-Logger {

    if($script:Initialized){
        return
    }

    $script:Initialized = $true

    try {

        $logDir = $Global:LOGS

        if(!(Test-Path $logDir)){
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }

        foreach($file in @(
            $Global:LogPath,
            $Global:DebugLogPath
        )){
            if(!(Test-Path $file)){
                New-Item -ItemType File -Path $file -Force | Out-Null
            }
        }
    }
    catch {

        Write-Host "Logger initialization FAILED: $_" -ForegroundColor Red
    }
}

# -------------------------
# VERBOSE STATE
# -------------------------
function Get-VerboseEnabled {

    return (Test-Path $Global:VerboseFlag)
}

# -------------------------
# LOG ROTATION
# -------------------------
function Invoke-LogRotation {

    try {

        if(!(Test-Path $Global:LogPath)){
            return
        }

        $sizeMB = (Get-Item $Global:LogPath).Length / 1MB

        if($sizeMB -lt 5){
            return
        }

        $archive = "$Global:Base\logs\pipeline_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

        Move-Item $Global:LogPath $archive -Force

        New-Item -ItemType File -Path $Global:LogPath | Out-Null

        # keep newest 5 archives
        Get-ChildItem "$Global:Base\logs\pipeline_*.log" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip 5 |
        Remove-Item -Force
    }
    catch {}
}

# -------------------------
# COLOR RESOLUTION
# -------------------------
function Get-LogColor($tag,$level,$msg){

    if($level -eq "ERROR"){
        return "Red"
    }

    if($level -eq "WARNING"){
        return "Yellow"
    }

    if($level -eq "DEBUG"){
        return "Gray"
    }

    if($level -eq "TRACE"){
        return "DarkGray"
    }

    switch($tag){

        "MUX"      { return "Cyan" }
        "SCAN"     { return "Green" }
        "CACHE"    { return "DarkGreen" }
        "VERIFY"   { return "Magenta" }
        "CLEANER"  { return "Yellow" }
        "IDLE"     { return "DarkMagenta" }
        "MAIN"     { return "White" }
        "QUEUE"    { return "Blue" }
        "REPAIR"   { return "DarkYellow" }
        "RESTORE"  { return "DarkCyan" }

        default {

            if($msg -match "(?i)fail|error|missing|corrupt"){
                return "Red"
            }

            return "White"
        }
    }
}

# -------------------------
# MAIN LOGGER
# -------------------------
function Log {

    param(
        [string]$tag,
        [string]$msg,
        [string]$level = "INFO",
        [bool]$SendToDiscord = $false
    )

    Initialize-Logger

    if([string]::IsNullOrWhiteSpace($msg)){
        return
    }

    $msg = $msg.Trim()

    # -------------------------
    # VERBOSE FILTER
    # -------------------------
    if($level -eq "TRACE" -or $level -eq "VERBOSE"){

        if(-not (Get-VerboseEnabled)){
            return
        }
    }

    Invoke-LogRotation

    $time = Get-Date -Format "HH:mm:ss"

    $line = "[$time][$tag][$level] $msg"

    # -------------------------
    # DEDUP
    # -------------------------
    $compare = "[$tag][$level] $msg"

    if($compare -eq $script:LastLogLine){

        $script:RepeatCount++

        return
    }

    if($script:RepeatCount -gt 0){

        $repeat = "[$time][LOGGER][INFO] Previous message repeated $script:RepeatCount times"

        try {
            [System.IO.File]::AppendAllText(
                $Global:LogPath,
                $repeat + [Environment]::NewLine
            )
        }
        catch {}

        Write-Host $repeat -ForegroundColor DarkGray

        $script:RepeatCount = 0
    }

    $script:LastLogLine = $compare

    # -------------------------
    # COLOR
    # -------------------------
    $color = Get-LogColor $tag $level $msg

    Write-Host $line -ForegroundColor $color

    # -------------------------
    # WRITE PIPELINE
    # -------------------------
    try {

        [System.IO.File]::AppendAllText(
            $Global:LogPath,
            $line + [Environment]::NewLine
        )
    }
    catch {}

    # -------------------------
    # DEBUG LOG
    # -------------------------
    if($level -eq "DEBUG"){

        try {

            [System.IO.File]::AppendAllText(
                $Global:DebugLogPath,
                $line + [Environment]::NewLine
            )
        }
        catch {}
    }

    # -------------------------
    # DISCORD NOTIFICATION
    # -------------------------
    # Check if this log level should be sent to Discord
    $sendToDiscord = $false
    
    if ($SendToDiscord) {
        $sendToDiscord = $true
    }
    else {
        # Check config settings for this level
        if ($null -ne $script:Config.Notifications.DiscordLogLevels) {
            $levelSetting = $script:Config.Notifications.DiscordLogLevels.$level
            if ($null -ne $levelSetting) {
                $sendToDiscord = [bool]$levelSetting
            }
        }
    }
    
    if ($sendToDiscord) {
        Send-DiscordLog -Tag $tag -Message $msg -Level $level
    }
}

# -------------------------
# GLOBAL ERROR HANDLER
# -------------------------
$script:ErrorActionPreference = "Stop"

trap {

    Write-Host "[LOGGER][FATAL] $_" -ForegroundColor Red

    throw
}

Export-ModuleMember -Function @(
    "Log",
    "Send-DiscordLog",
    "Get-VerboseEnabled",
    "Get-PipelineLogPath",
    "Get-DebugLogPath",
    "Get-FFmpegLogPath"
)
