@echo off
REM download_wad.bat - Download Doom shareware IWAD

setlocal enabledelayedexpansion

set "OUT_FILE=.\doom1.wad"
set "FORCE=0"
set "POSITIONAL_OUTPUT="

:parse
if "%~1"=="" goto parsed
if /I "%~1"=="-o" (
    if "%~2"=="" (
        echo error: missing value for -o
        exit /b 2
    )
    set "OUT_FILE=%~2"
    shift
    shift
    goto parse
)
if /I "%~1"=="--output" (
    if "%~2"=="" (
        echo error: missing value for --output
        exit /b 2
    )
    set "OUT_FILE=%~2"
    shift
    shift
    goto parse
)
if /I "%~1"=="-f" (
    set "FORCE=1"
    shift
    goto parse
)
if /I "%~1"=="--force" (
    set "FORCE=1"
    shift
    goto parse
)
if /I "%~1"=="-h" goto help
if /I "%~1"=="--help" goto help
if "%~1"=="--" (
    shift
    goto parsed
)
if not defined POSITIONAL_OUTPUT (
    set "POSITIONAL_OUTPUT=%~1"
    shift
    goto parse
)

echo error: only one positional output path is supported
exit /b 2

:parsed
if defined POSITIONAL_OUTPUT (
    if not "%OUT_FILE%"==".\doom1.wad" (
        echo error: use either OUTPUT_DIR or -o/--output, not both
        exit /b 2
    )
    for %%F in ("%POSITIONAL_OUTPUT%") do (
        if /I "%%~xF"==".wad" (
            set "OUT_FILE=%POSITIONAL_OUTPUT%"
        ) else (
            set "OUT_FILE=%POSITIONAL_OUTPUT%\doom1.wad"
        )
    )
)

for %%F in ("%OUT_FILE%") do set "OUT_DIR=%%~dpF"
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

if "%FORCE%"=="1" del "%OUT_FILE%" 2>nul

if exist "%OUT_FILE%" (
    for %%F in ("%OUT_FILE%") do set "SIZE=%%~zF"
    if !SIZE! GEQ 4000000 (
        echo doom1.wad already exists: %OUT_FILE%
        exit /b 0
    )
    del "%OUT_FILE%" 2>nul
)

set "URL1=https://distro.ibiblio.org/slitaz/sources/packages/d/doom1.wad"
set "URL2=https://raw.githubusercontent.com/Doom-Utils/shareware-collection/master/Doom%%201.0/doom1.wad"
set "URL3=https://archive.org/download/DoomsharewareEpisode/doom1.wad"

echo Downloading doom1.wad...
for %%U in ("%URL1%" "%URL2%" "%URL3%") do (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -UseBasicParsing -Uri '%%~U' -OutFile '%OUT_FILE%' } catch { exit 1 }" >nul 2>&1
    if exist "%OUT_FILE%" (
        for %%F in ("%OUT_FILE%") do if %%~zF GEQ 4000000 (
            echo Downloaded: %OUT_FILE%
            exit /b 0
        )
    )
    del "%OUT_FILE%" 2>nul
)

echo error: failed to download doom1.wad
exit /b 1

:help
echo Download doom1.wad into the current folder or a custom path.
echo.
echo Usage:
echo   download_wad.bat [OUTPUT_DIR]
echo   download_wad.bat -o FILE
echo.
echo Options:
echo   -o, --output FILE  Output WAD path
echo   -f, --force        Re-download even if the file already exists
echo   -h, --help         Show this help
exit /b 0
