<#
    Setup-Pipeline.ps1

    First launch:
    - Creates a config file
    - Prompts the user for all required settings
    - Saves settings permanently

    Every launch after:
    - Prompts the user to:
        1. Run the pipeline
        2. Change settings
        3. Exit

    Designed for:
    - Video processing / uploader pipelines
    - Portable folder-based deployments

    Config format:
    - JSON

    Notes:
    - Fully standalone
    - No external modules required
    - Safe folder creation
    - Colored terminal UI
#>
# Creates a folder if it does not already exist.
function Ensure-Folder {
    param(
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

# =========================
# PATH SETUP
# =========================

# Gets the current script directory.
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

$ConfigFolder = "C:\ProgramData\Pipeline"

Ensure-Folder $ConfigFolder

# Config file location.
$ConfigFile = Join-Path $ConfigFolder "config.json"

# Main pipeline batch file.
$PipelineLauncher = Join-Path $Root "\BATCH FILES\Video_Pipeline.bat"

# FFmpeg install location for portable fallback.
$FfmpegFolder = Join-Path $ConfigFolder "ffmpeg"

# =========================
# UI HELPERS
# =========================

# Displays a styled title banner.
function Show-Banner {
    Clear-Host

    Write-Host "============================================================" -ForegroundColor DarkCyan
    Write-Host "                    VIDEO PIPELINE SETUP                    " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor DarkCyan
    Write-Host ""
}

# Displays section headers.
function Show-Section {
    param(
        [string]$Title
    )

    Write-Host ""
    Write-Host "[$Title]" -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
}

# Prompts for a non-empty value.
function Read-RequiredInput {
    param(
        [string]$Prompt
    )

    do {
        $Value = Read-Host $Prompt

        if ([string]::IsNullOrWhiteSpace($Value)) {
            Write-Host "Value cannot be empty." -ForegroundColor Red
        }

    } until (-not [string]::IsNullOrWhiteSpace($Value))

    return $Value.Trim()
}

# Prompts for a yes/no value.
function Read-YesNo {
    param(
        [string]$Prompt,
        [bool]$Default = $true
    )

    $Suffix = if ($Default) { "[Y/n]" } else { "[y/N]" }

    do {
        $InputValue = Read-Host "$Prompt $Suffix"

        if ([string]::IsNullOrWhiteSpace($InputValue)) {
            return $Default
        }

        switch ($InputValue.ToLower()) {
            "y" { return $true }
            "yes" { return $true }
            "n" { return $false }
            "no" { return $false }
            default {
                Write-Host "Please enter Y or N." -ForegroundColor Red
            }
        }

    } while ($true)
}

# =========================
# CONFIG MANAGEMENT
# =========================

# Loads the JSON configuration file.
function Load-Config {

    if (-not (Test-Path $ConfigFile)) {
        return $null
    }

    try {
        return Get-Content $ConfigFile -Raw | ConvertFrom-Json
    }
    catch {
        Write-Host "Failed to load config file." -ForegroundColor Red
        return $null
    }
}

# Saves configuration data to JSON.
function Save-Config {
    param(
        [hashtable]$Config
    )

    $Config | ConvertTo-Json -Depth 10 |
        Set-Content $ConfigFile -Encoding UTF8

    Write-Host ""
    Write-Host "Configuration saved." -ForegroundColor Green
}

# =========================
# FFmpeg INSTALLATION
# =========================

function Get-FfmpegExecutable {
    $ffmpegCommand = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($null -ne $ffmpegCommand) {
        return $ffmpegCommand.Path
    }

    $localPath = Join-Path $FfmpegFolder "bin\ffmpeg.exe"
    if (Test-Path $localPath) {
        return $localPath
    }

    return $null
}

function Test-FFmpegInstalled {
    return (Get-FfmpegExecutable) -ne $null
}

function Add-FfmpegToPath {
    $ffmpegExecutable = Get-FfmpegExecutable
    if ($null -eq $ffmpegExecutable) {
        return $false
    }

    $ffmpegDir = Split-Path -Parent $ffmpegExecutable
    if ($env:PATH -notlike "*$ffmpegDir*") {
        $env:PATH = "$ffmpegDir;$env:PATH"
    }

    return $true
}

function Install-FFmpegUsingWinget {
    Write-Host "Using winget to install FFmpeg..." -ForegroundColor Cyan

    $args = @(
        'install',
        '--silent',
        '--accept-source-agreements',
        '--accept-package-agreements',
        '--id',
        'ffmpeg.ffmpeg'
    )

    $process = Start-Process -FilePath 'winget' -ArgumentList $args -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
    if ($null -ne $process -and $process.ExitCode -eq 0) {
        return $true
    }

    return $false
}

function Install-FFmpegFromZip {
    Write-Host "Downloading portable FFmpeg..." -ForegroundColor Cyan
    Ensure-Folder $FfmpegFolder

    $zipUrl = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'
    $zipPath = Join-Path $env:TEMP 'ffmpeg-release-essentials.zip'

    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -ErrorAction Stop
    }
    catch {
        Write-Host "Failed to download FFmpeg: $_" -ForegroundColor Red
        return $false
    }

    try {
        Expand-Archive -Path $zipPath -DestinationPath $FfmpegFolder -Force
    }
    catch {
        Write-Host "Failed to extract FFmpeg: $_" -ForegroundColor Red
        return $false
    }

    $childDirs = Get-ChildItem -Path $FfmpegFolder -Directory -ErrorAction SilentlyContinue
    if ($childDirs.Count -eq 1) {
        $source = $childDirs[0].FullName
        Get-ChildItem -Path $source -Force | ForEach-Object {
            Move-Item -Path $_.FullName -Destination $FfmpegFolder -Force
        }
        Remove-Item -Path $source -Recurse -Force
    }

    return $true
}

function Install-FFmpeg {
    Write-Host "FFmpeg is not installed. Installing automatically..." -ForegroundColor Yellow
    Ensure-Folder $FfmpegFolder

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        if (Install-FFmpegUsingWinget) {
            return (Add-FfmpegToPath)
        }
    }

    if (Install-FFmpegFromZip) {
        return (Add-FfmpegToPath)
    }

    Write-Host "FFmpeg installation failed." -ForegroundColor Red
    return $false
}

function Ensure-FFmpegInstalled {
    if (Test-FFmpegInstalled) {
        return $true
    }

    return Install-FFmpeg
}

# =========================
# SETTINGS WIZARD
# =========================

# Interactive first-time setup wizard.
function Start-SetupWizard {

    Show-Banner

    Write-Host "First startup detected." -ForegroundColor Cyan
    Write-Host "Please configure the pipeline settings." -ForegroundColor Gray

    # -------------------------
    # BASIC PATHS
    # -------------------------

    Show-Section "Folder Configuration"

    $InputFolder = Read-RequiredInput "Input recordings folder"
    $OutputFolder = Read-RequiredInput "Finished output folder"
    $TempFolder = Read-RequiredInput "Temporary working folder"
    $ArchiveFolder = Read-RequiredInput "Archive folder"

    Ensure-Folder $InputFolder
    Ensure-Folder $OutputFolder
    Ensure-Folder $TempFolder
    Ensure-Folder $ArchiveFolder

    # -------------------------
    # UPLOADER SETTINGS
    # -------------------------

    # Show-Section "Uploader Settings"

    # $EnableUpload = Read-YesNo "Enable uploader?"

    # $UploadDestination = ""
    # $UploaderExecutable = ""

    # if ($EnableUpload) {
    #     $UploadDestination = Read-RequiredInput "Upload destination name"
    #     $UploaderExecutable = Read-RequiredInput "Uploader executable path"
    # }

    # -------------------------
    # MEDIA SCANNER SETTINGS
    # -------------------------

    Show-Section "Media Scanner Settings"

    $EnableMediaScanner = Read-YesNo "Enable media scanner?"
    $DeleteBrokenFiles = Read-YesNo "Delete broken files automatically?"
    $EnableAutoRepair = Read-YesNo "Enable automatic repair attempts?"

    # -------------------------
    # IDLE SHUTDOWN
    # -------------------------

    Show-Section "Idle Shutdown"

    $EnableIdleShutdown = Read-YesNo "Enable idle shutdown?"

    $IdleMinutes = 0

    if ($EnableIdleShutdown) {
        $IdleMinutes = Read-RequiredInput "Shutdown after how many idle minutes"
    }

    # -------------------------
    # ADVANCED SETTINGS
    # -------------------------

    Show-Section "Advanced Settings"

    $EnableLogging = Read-YesNo "Enable verbose logging?" $true
    $EnablePauseOnExit = Read-YesNo "Pause before exiting?" $true
    # $EnableDiscordWebhook = Read-YesNo "Enable Discord webhook notifications?" $false

    # $DiscordWebhook = ""

    # if ($EnableDiscordWebhook) {
    #     $DiscordWebhook = Read-RequiredInput "Discord webhook URL"
    # }

    # -------------------------
    # BUILD CONFIG OBJECT
    # -------------------------

    $Config = @{

        Paths = @{
            InputFolder   = $InputFolder
            OutputFolder  = $OutputFolder
            TempFolder    = $TempFolder
            ArchiveFolder = $ArchiveFolder
        }

        # Upload = @{
        #     Enabled            = $EnableUpload
        #     Destination        = $UploadDestination
        #     UploaderExecutable = $UploaderExecutable
        # }

        MediaScanner = @{
            Enabled           = $EnableMediaScanner
            DeleteBrokenFiles = $DeleteBrokenFiles
            AutoRepair        = $EnableAutoRepair
        }

        IdleShutdown = @{
            Enabled    = $EnableIdleShutdown
            IdleMinute = $IdleMinutes
        }

        Notifications = @{
            DiscordWebhookEnabled = $EnableDiscordWebhook
            DiscordWebhook        = $DiscordWebhook
        }

        General = @{
            VerboseLogging = $EnableLogging
            PauseOnExit    = $EnablePauseOnExit
        }

        Metadata = @{
            Created = (Get-Date)
            Version = "1.0"
        }
    }

    Save-Config $Config

    Write-Host ""
    Write-Host "Setup complete." -ForegroundColor Green
    Write-Host ""

    Pause
}

# =========================
# SETTINGS DISPLAY
# =========================

# Shows current configuration values.
function Show-CurrentSettings {
    param(
        $Config
    )

    Show-Section "Current Configuration"

    Write-Host "INPUT FOLDER:" -ForegroundColor Cyan
    Write-Host "  $($Config.Paths.InputFolder)"

    Write-Host ""

    Write-Host "OUTPUT FOLDER:" -ForegroundColor Cyan
    Write-Host "  $($Config.Paths.OutputFolder)"

    Write-Host ""

    Write-Host "TEMP FOLDER:" -ForegroundColor Cyan
    Write-Host "  $($Config.Paths.TempFolder)"

    Write-Host ""

    Write-Host "ARCHIVE FOLDER:" -ForegroundColor Cyan
    Write-Host "  $($Config.Paths.ArchiveFolder)"

    Write-Host ""

    # Write-Host "UPLOADER ENABLED:" -ForegroundColor Cyan
    # Write-Host "  $($Config.Upload.Enabled)"

    Write-Host ""

    Write-Host "MEDIA SCANNER ENABLED:" -ForegroundColor Cyan
    Write-Host "  $($Config.MediaScanner.Enabled)"

    Write-Host ""

    Write-Host "IDLE SHUTDOWN ENABLED:" -ForegroundColor Cyan
    Write-Host "  $($Config.IdleShutdown.Enabled)"

    Write-Host ""

    Write-Host "VERBOSE LOGGING:" -ForegroundColor Cyan
    Write-Host "  $($Config.General.VerboseLogging)"
}

# =========================
# PIPELINE STARTER
# =========================

# Launches the main batch file.
function Start-Pipeline {

    Show-Banner

    Write-Host "Starting video pipeline..." -ForegroundColor Green
    Write-Host ""

    if (-not (Ensure-FFmpegInstalled)) {
        Write-Host "Unable to install or locate FFmpeg. Pipeline launch cancelled." -ForegroundColor Red
        Pause
        return
    }

    if (-not (Test-Path $PipelineLauncher)) {
        Write-Host "Pipeline launcher not found:" -ForegroundColor Red
        Write-Host "$PipelineLauncher" -ForegroundColor DarkGray
        Pause
        return
    }

    Start-Process -FilePath $PipelineLauncher -WorkingDirectory $Root
}

# =========================
# MAIN MENU
# =========================

# Displays the startup menu.
function Show-MainMenu {

    do {

        Show-Banner

        $Config = Load-Config

        if ($null -eq $Config) {
            Write-Host "No configuration found." -ForegroundColor Yellow
            Write-Host "Launching setup wizard..." -ForegroundColor Gray
            Start-Sleep -Seconds 2
            Start-SetupWizard
            continue
        }

        Write-Host "Configuration loaded successfully." -ForegroundColor Green

        Write-Host ""

        Write-Host "1. Run Pipeline" -ForegroundColor White
        Write-Host "2. Change Settings" -ForegroundColor White
        Write-Host "3. View Current Settings" -ForegroundColor White
        Write-Host "4. Exit" -ForegroundColor White

        Write-Host ""

        $Choice = Read-Host "Select an option"

        switch ($Choice) {

            "1" {
                Start-Pipeline
                break
            }

            "2" {
                Start-SetupWizard
            }

            "3" {
                Show-Banner
                Show-CurrentSettings $Config
                Write-Host ""
                Pause
            }

            "4" {
                return
            }

            default {
                Write-Host ""
                Write-Host "Invalid option." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }

    } while ($true)
}

# =========================
# SCRIPT ENTRY
# =========================

Show-MainMenu