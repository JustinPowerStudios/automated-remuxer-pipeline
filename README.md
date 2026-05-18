# Video Pipeline

A portable Windows video processing pipeline with interactive setup, configuration storage, and automatic FFmpeg installation support.

## Overview

This project provides a folder-based video pipeline launcher built around PowerShell and batch scripts.

- `PIPELINE/launch.bat` starts the PowerShell setup script.
- Configuration is stored in `%ProgramData%\Pipeline\config.json`.
- The pipeline can install FFmpeg automatically if it is not already available.

## Features

- First-run interactive setup wizard
- Folder configuration for input, output, temporary and archive locations
- Optional uploader integration
- Optional media scanner and automatic repair support
- Optional idle shutdown
- Verbose logging and pause-on-exit options
- Portable FFmpeg download fallback when `winget` is unavailable

## Getting Started

Just go to the PIPELINE\PIPELINE and run launch.bat

## Configuration

The script saves settings to:

- `C:\ProgramData\Pipeline\config.json`

The configuration includes:

- `Paths`: input, output, temporary, and archive folders
- `MediaScanner`: scanning, broken file deletion, and auto repair
- `IdleShutdown`: idle shutdown enablement and timeout
- `General`: verbose logging and pause-on-exit

## Requirements

- Windows PowerShell
- Internet access for FFmpeg download if not already installed
- Optional: `winget` for one-step FFmpeg installation

## Project Structure

- `PIPELINE/` - main PowerShell and batch files
- `PIPELINE/BATCH FILES/` - batch scripts used by the pipeline
- `PIPELINE/POWERSHELL FILES/` - supporting PowerShell modules and utilities
- `RepairArchive/` - repair archives generated or used by the pipeline
- `Temp/` - temporary workspace data
- `logs/` - log files

## Notes

- The pipeline is designed for portable, folder-based deployments.
- No external PowerShell modules are required to run the setup script.
- The launcher will prompt to run the pipeline, update settings, view settings, or exit.

## License

No license file is included. Add a `LICENSE` if you want to define usage terms.
