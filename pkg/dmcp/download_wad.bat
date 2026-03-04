@echo off
REM download_wad.bat - Download Doom shareware WAD
REM
REM Usage: download_wad.bat [OUTPUT_DIR]
REM
REM Downloads doom1.wad (shareware) to OUTPUT_DIR (default: current dir).

setlocal enabledelayedexpansion

set "OUT_DIR=%~1"
if "%OUT_DIR%"=="" set "OUT_DIR=."
set "OUT_FILE=%OUT_DIR%\doom1.wad"
set "MIN_BYTES=4000000"

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

if exist "%OUT_FILE%" (
    for %%F in ("%OUT_FILE%") do set "SIZE=%%~zF"
    if !SIZE! GEQ %MIN_BYTES% (
        echo doom1.wad already exists ^(!SIZE! bytes^): %OUT_FILE%
        exit /b 0
    )
    del "%OUT_FILE%" 2>nul
)

set "URL1=https://distro.ibiblio.org/slitaz/sources/packages/d/doom1.wad"
set "URL2=https://raw.githubusercontent.com/Doom-Utils/shareware-collection/master/Doom%%201.0/doom1.wad"
set "URL3=https://archive.org/download/DoomsharewareEpisode/doom1.wad"

echo Downloading Doom shareware WAD to: %OUT_FILE%

where powershell >nul 2>&1 && goto :use_powershell
where bitsadmin >nul 2>&1 && goto :use_bitsadmin
where certutil >nul 2>&1 && goto :use_certutil

echo error: need powershell, bitsadmin, or certutil to download files.
exit /b 1

:use_powershell
for %%U in ("%URL1%" "%URL2%" "%URL3%") do (
    echo Trying: %%~U
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "try { Invoke-WebRequest -UseBasicParsing -Uri '%%~U' -OutFile '%OUT_FILE%' -TimeoutSec 30; exit 0 } catch { exit 1 }" >nul 2>&1
    if not errorlevel 1 if exist "%OUT_FILE%" (
        for %%F in ("%OUT_FILE%") do if %%~zF GEQ %MIN_BYTES% (
            echo Downloaded: %OUT_FILE% ^(%%~zF bytes^)
            exit /b 0
        )
    )
    del "%OUT_FILE%" 2>nul
)
goto :failed

:use_bitsadmin
for %%U in ("%URL1%" "%URL2%" "%URL3%") do (
    echo Trying: %%~U
    bitsadmin /transfer wad /download /priority normal "%%~U" "%OUT_FILE%" >nul 2>&1
    if exist "%OUT_FILE%" (
        for %%F in ("%OUT_FILE%") do if %%~zF GEQ %MIN_BYTES% (
            echo Downloaded: %OUT_FILE% ^(%%~zF bytes^)
            exit /b 0
        )
    )
    del "%OUT_FILE%" 2>nul
)
goto :failed

:use_certutil
for %%U in ("%URL1%" "%URL2%" "%URL3%") do (
    echo Trying: %%~U
    certutil -urlcache -split -f "%%~U" "%OUT_FILE%" >nul 2>&1
    if exist "%OUT_FILE%" (
        for %%F in ("%OUT_FILE%") do if %%~zF GEQ %MIN_BYTES% (
            echo Downloaded: %OUT_FILE% ^(%%~zF bytes^)
            exit /b 0
        )
    )
    del "%OUT_FILE%" 2>nul
)
goto :failed

:failed
echo error: failed to download doom1.wad from all mirrors.
echo You can download it manually from:
echo   https://archive.org/details/DoomsharewareEpisode
exit /b 1
