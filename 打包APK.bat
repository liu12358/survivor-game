@echo off
chcp 65001 >nul
echo Building Android APK...
echo.

set GODOT=%~dp0Godot.exe
set PROJECT=D:\agentwork\survivor-game
set OUTPUT=D:\agentwork\survivor-game\export\android\starfall.apk

if not exist "%GODOT%" (
    echo [ERROR] Godot.exe not found
    pause
    exit /b 1
)

"%GODOT%" --headless --path "%PROJECT%" --export-debug "Android" "%OUTPUT%"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [OK] Export success: %OUTPUT%
    echo.
    dir "%OUTPUT%"
) else (
    echo.
    echo [FAIL] Export failed.
)
pause
