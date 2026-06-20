@echo off
REM download_wad.bat - Download Doom shareware IWAD

setlocal enabledelayedexpansion

set "OUT_FILE=.\doom1.wad"
set "FORCE=0"
set "POSITIONAL_OUTPUT="
set "DOOM1_WAD_SHA256=1d7d43be501e67d927e415e0b8f3e29c3bf33075e859721816f652a526cac771"
set "DOOM1_WAD_SIZE=4196020"

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

if exist "%OUT_FILE%" (
    call :valid_wad "%OUT_FILE%"
    if not errorlevel 1 (
        echo doom1.wad already exists: %OUT_FILE%
        exit /b 0
    )
    if not "%FORCE%"=="1" (
        echo error: existing file does not match the expected Doom shareware IWAD: %OUT_FILE%
        echo Use -f to replace it, or set DOOM_WAD/pass -iwad to use a different IWAD.
        exit /b 1
    )
    del "%OUT_FILE%" 2>nul
)

set "URL1=https://distro.ibiblio.org/slitaz/sources/packages/d/doom1.wad"
set "ARCHIVE_URL=https://deb.debian.org/debian/pool/non-free/d/doom-wad-shareware/doom-wad-shareware_1.9.fixed.orig.tar.gz"

echo Downloading doom1.wad...
for %%U in ("%URL1%") do (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -UseBasicParsing -Uri '%%~U' -OutFile '%OUT_FILE%' } catch { exit 1 }" >nul 2>&1
    if exist "%OUT_FILE%" (
        call :valid_wad "%OUT_FILE%"
        if not errorlevel 1 (
            echo Downloaded: %OUT_FILE%
            exit /b 0
        )
    )
    del "%OUT_FILE%" 2>nul
)

call :download_archive
if not errorlevel 1 exit /b 0

echo error: failed to download a checksum-verified doom1.wad
exit /b 1

:valid_wad
if not exist "%~1" exit /b 1
for %%F in ("%~1") do if not "%%~zF"=="%DOOM1_WAD_SIZE%" exit /b 1
set "HASH="
for /f "usebackq tokens=* delims=" %%H in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-FileHash -Algorithm SHA256 -Path '%~1').Hash.ToLowerInvariant()"`) do set "HASH=%%H"
if /I not "%HASH%"=="%DOOM1_WAD_SHA256%" exit /b 1
exit /b 0

:download_archive
set "TMP_DIR=%OUT_DIR%doom-shareware-%RANDOM%%RANDOM%"
set "TMP_ARCHIVE=%TMP_DIR%\doom-shareware.tar.gz"
mkdir "%TMP_DIR%" >nul 2>&1
if errorlevel 1 exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -UseBasicParsing -Uri '%ARCHIVE_URL%' -OutFile '%TMP_ARCHIVE%' } catch { exit 1 }" >nul 2>&1
if errorlevel 1 (
    rmdir /s /q "%TMP_DIR%" 2>nul
    exit /b 1
)
tar -xzf "%TMP_ARCHIVE%" -C "%TMP_DIR%" >nul 2>&1
if errorlevel 1 (
    rmdir /s /q "%TMP_DIR%" 2>nul
    exit /b 1
)
for /r "%TMP_DIR%" %%F in (doom1.wad) do (
    copy /y "%%F" "%OUT_FILE%" >nul
    goto archive_copied
)
:archive_copied
rmdir /s /q "%TMP_DIR%" 2>nul
call :valid_wad "%OUT_FILE%"
if errorlevel 1 (
    del "%OUT_FILE%" 2>nul
    exit /b 1
)
echo Downloaded: %OUT_FILE%
exit /b 0

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
