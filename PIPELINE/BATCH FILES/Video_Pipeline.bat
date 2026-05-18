@echo off

REM Get the directory of this script (BATCH FILES folder)
set "SCRIPT_DIR=%~dp0"

REM Go up one level to the root pipeline folder
for %%A in ("%SCRIPT_DIR%..") do set "BASE=%%~fA"

call "%SCRIPT_DIR%LoadConfig.bat"

echo Starting pipeline...

wt ^
new-tab --title "PIPELINE LOG" --tabColor "#00FFFF" ^
cmd /k "powershell -NoExit -ExecutionPolicy Bypass -File \"%PS%\View-Log.ps1\"" ^

; new-tab --title "FFMPEG LOG" --tabColor "#00FF00" ^
cmd /k "powershell -NoExit -ExecutionPolicy Bypass -File \"%PS%\View-fflog.ps1\"" ^

; new-tab --title "MUXER" --tabColor "#00FFFF" ^
cmd /k "\"%BAT%\Auto-Muxer.bat\"" ^

; new-tab --title "SCANNER" --tabColor "#00AA00" ^
powershell -NoExit -NoProfile -ExecutionPolicy Bypass -File "%PS%\MediaScanner.ps1" ^

; new-tab --title "REPAIR RESTORE" --tabColor "#FF8800" ^
powershell -NoExit -NoProfile -ExecutionPolicy Bypass -File "%PS%\RepairRestore.ps1" ^

; new-tab --title "CLEANER" --tabColor "#FFFF00" ^
powershell -NoExit -NoProfile -ExecutionPolicy Bypass -File "%PS%\FileCleaner.ps1" ^

; new-tab --title "IDLE" --tabColor "#FF00FF" ^
powershell -NoExit -NoProfile -ExecutionPolicy Bypass -File "%PS%\IdleShutdown.ps1" ^

; focus-tab -t 0

echo.
echo Pipeline started inside Windows Terminal.