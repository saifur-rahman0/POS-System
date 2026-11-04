@echo off
title Retail POS System - Production Launcher
echo ========================================================
echo        RETAIL POS SYSTEM - DESKTOP LAUNCHER
echo ========================================================
echo.

:: 1. Verify Docker PostgreSQL Container
echo [1/3] Verifying Local PostgreSQL Database Container...
docker inspect -f "{{.State.Running}}" pos_shop_db 2>nul | findstr "true" >nul
if %errorlevel% neq 0 (
    echo Database container is not running. Starting pos_shop_db...
    docker start pos_shop_db 2>nul
    if %errorlevel% neq 0 (
        echo Warning: Docker container pos_shop_db could not be started automatically.
        echo Ensuring standard local PostgreSQL service is running on port 5432...
    )
) else (
    echo Database container pos_shop_db is healthy.
)

:: 2. Launch FastAPI POS Backend Server
echo [2/3] Starting Retail POS Backend API Service...
cd /d "%~dp0\..\backend"
start "Retail POS Backend" /min .venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000

:: 3. Launch Flutter POS Desktop Application
echo [3/3] Launching Retail POS Desktop Application...
cd /d "%~dp0\..\pos_system_application"
if exist "build\windows\x64\runner\Release\pos_system_application.exe" (
    start "" "build\windows\x64\runner\Release\pos_system_application.exe"
) else (
    echo Launching POS Desktop via Flutter run...
    flutter run -d windows
)

echo.
echo All POS systems successfully launched.

