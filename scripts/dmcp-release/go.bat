@echo off
REM go.bat - Run a Crispy game with DMCP and a default IWAD

setlocal
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

if /I "%~1"=="-h" goto help
if /I "%~1"=="--help" goto help

set "GAME=doom"
for %%G in (doom heretic hexen strife) do if /I "%~1"=="%%G" set "GAME=%%G"
if /I "%~1"=="%GAME%" shift

REM %* ignores shift, so collect the remaining arguments by hand.
set "ARGS="
:collect
if "%~1"=="" goto collected
set "ARGS=%ARGS% %1"
shift
goto collect
:collected

set "EXE=crispy-%GAME%.exe"
if not exist "%EXE%" (
    echo error: %EXE% not found in %SCRIPT_DIR%
    exit /b 1
)

set "HAS_IWAD="
for %%A in (%ARGS%) do (
    if /I "%%~A"=="-iwad" set "HAS_IWAD=1"
)

if defined HAS_IWAD goto run

if /I not "%GAME%"=="doom" if "%DOOM_WAD%"=="" goto run

if "%DOOM_WAD%"=="" set "DOOM_WAD=.\doom1.wad"

if not exist "%DOOM_WAD%" (
    if /I "%DOOM_WAD%"==".\doom1.wad" if exist "download_wad.bat" call download_wad.bat -o "%DOOM_WAD%"
)

if not exist "%DOOM_WAD%" (
    echo error: WAD not found: %DOOM_WAD%
    exit /b 1
)

"%EXE%" -iwad "%DOOM_WAD%" -dmcp_allow_cheats%ARGS%
exit /b %ERRORLEVEL%

:run
"%EXE%" -dmcp_allow_cheats%ARGS%
exit /b %ERRORLEVEL%

:help
echo Run a Crispy game from the extracted Crispy Doom release folder.
echo.
echo Usage:
echo   go.bat [doom^|heretic^|hexen^|strife] [extra args...]
echo.
echo Notes:
echo   - The game defaults to doom.
echo   - Passes -dmcp_allow_cheats so the mutating DMCP tools are available. Run
echo     crispy-GAME.exe directly to start without them.
echo   - If you pass -iwad yourself, go.bat forwards args untouched.
echo   - Otherwise it uses DOOM_WAD or, for doom, .\doom1.wad (downloaded as the
echo     shareware IWAD when missing). For the other games, DOOM_WAD or the IWAD
echo     search of the engine applies.
exit /b 0
