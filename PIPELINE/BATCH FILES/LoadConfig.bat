@echo off

REM Get the directory of this script (BATCH FILES folder)
set "SCRIPT_DIR=%~dp0"

REM Go up one level to the root pipeline folder
for %%A in ("%SCRIPT_DIR%..") do set "BASE=%%~fA"

set "PS=%BASE%\POWERSHELL FILES"
set "BAT=%BASE%\BATCH FILES"
set "TXT=%BASE%\TEMP AND TEXT FILES"
set "LOGS=%BASE%\logs"