@echo off
setlocal EnableExtensions
chcp 65001 >nul
title HP Victus 15 Power Unlocker Suite (Ryzen 7 7445HS + RTX 4050)

set "SUITE_DIR=%~dp0."
set "CHOICE=%~1"
set "FROM_ARG=1"

if not "%CHOICE%"=="" goto VALIDATE_CHOICE
set "FROM_ARG=0"

:MENU
cls
echo ============================================================================
echo   HP VICTUS 15 POWER UNLOCKER SUITE  ^(8DD0 / Ryzen 7 7445HS + RTX 4050^)
echo ============================================================================
echo.
echo   [1] Modo Gaming GPU-Max
echo       Windows PowerCfg + Driver NVIDIA + Ryzen 38W/48W para liberar los
echo       50W completos a la RTX 4050
echo.
echo   [2] Modo Cómputo Bruto CPU
echo       Windows PowerCfg + Driver NVIDIA + Ryzen 54W sostenidos / 65W turbo
echo       para compilar, IA, Docker, juegos CPU
echo.
echo   [3] Solo Windows + Driver NVIDIA
echo       Sin modificar límites TDP de RyzenAdj
echo.
echo   [4] Suite Completa + OmenCore ^(Ventiladores^) + MSI Afterburner
echo       Lanza OmenCore minimizado + instala/abre MSI Afterburner para
echo       curva Undervolt GPU
echo.
echo   [5] Restaurar Valores Originales ^(Rollback^)
echo.
echo   [0] Salir
echo.
echo ============================================================================
set "CHOICE="
set /p "CHOICE=Selecciona una opción [1-5, 0 para salir]: "

:VALIDATE_CHOICE

if "%CHOICE%"=="0" exit /b 0

if not "%CHOICE%"=="1" if not "%CHOICE%"=="2" if not "%CHOICE%"=="3" if not "%CHOICE%"=="4" if not "%CHOICE%"=="5" (
    echo.
    echo [ERROR] Opción inválida: "%CHOICE%". Elige 1, 2, 3, 4, 5 o 0.
    if "%FROM_ARG%"=="1" exit /b 1
    pause
    goto MENU
)

net session >nul 2>&1
if errorlevel 1 (
    echo.
    echo Solicitando privilegios de Administrador ^(UAC^) para ejecutar la opción [%CHOICE%]...
    set "VICTUS_BAT=%~f0"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:VICTUS_BAT -ArgumentList '%CHOICE%' -Verb RunAs"
    if errorlevel 1 (
        echo.
        echo [ERROR] Elevación UAC cancelada o fallida.
        pause
        exit /b 1
    )
    exit /b 0
)

if not exist "%SUITE_DIR%\" (
    echo [ERROR] No se encontró la carpeta de la suite: "%SUITE_DIR%"
    pause
    exit /b 1
)

echo.
echo Ejecutando opción [%CHOICE%] con privilegios de Administrador...
echo.

if "%CHOICE%"=="5" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SUITE_DIR%\restaurar_potencia_stock.ps1"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SUITE_DIR%\unlock_victus_power.ps1" -Mode %CHOICE%
)

set "PS_RC=%ERRORLEVEL%"
echo.
if "%PS_RC%"=="0" (
    echo [OK] Operación finalizada correctamente.
) else (
    echo [ERROR] El script finalizó con código %PS_RC%. Revisa los mensajes anteriores o backup\victus_unlock.log.
)

if /I not "%~2"=="NOPAUSE" (
    echo.
    pause
)
exit /b %PS_RC%
