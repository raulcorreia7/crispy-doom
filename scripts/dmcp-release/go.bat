@echo off
REM go.bat - Run the DMCP release with a default IWAD

setlocal
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

if /I "%~1"=="-h" goto help
if /I "%~1"=="--help" goto help

if not exist "crispy-doom.exe" (
    echo error: crispy-doom.exe not found in %SCRIPT_DIR%
    exit /b 1
)

set "HAS_IWAD="
for %%A in (%*) do (
    if /I "%%~A"=="-iwad" set "HAS_IWAD=1"
)

if defined HAS_IWAD goto run

if "%DOOM_WAD%"=="" set "DOOM_WAD=.\doom1.wad"

if not exist "%DOOM_WAD%" (
    if /I "%DOOM_WAD%"==".\doom1.wad" if exist "download_wad.bat" call download_wad.bat -o "%DOOM_WAD%"
)

if not exist "%DOOM_WAD%" (
    echo error: WAD not found: %DOOM_WAD%
    exit /b 1
)

crispy-doom.exe -iwad "%DOOM_WAD%" %*
exit /b %ERRORLEVEL%

:run
crispy-doom.exe %*
exit /b %ERRORLEVEL%

:help
echo Run crispy-doom from the extracted DMCP release folder.
echo.
echo Usage:
echo   go.bat [extra args...]
echo.
echo Notes:
echo   - If you pass -iwad yourself, go.bat forwards args untouched.
echo   - Otherwise it uses DOOM_WAD or .\doom1.wad.
echo   - If .\doom1.wad is missing, it downloads the shareware IWAD first.
exit /b 0
