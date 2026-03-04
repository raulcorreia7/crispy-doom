@echo off
REM go.bat - Run Crispy Doom with MCP
REM
REM Usage: go.bat [extra args...]
REM   Copies your own WAD to this folder, or uses bundled doom1.wad.
REM
REM Environment:
REM   DOOM_WAD   Path to WAD file (default: .\doom1.wad)

setlocal

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

if "%DOOM_WAD%"=="" set "DOOM_WAD=.\doom1.wad"

if not exist "%DOOM_WAD%" (
    echo error: WAD not found: %DOOM_WAD%
    echo For shareware testing, run: download_wad.bat
    echo Or copy your own doom.wad here, or set DOOM_WAD=\path\to\your.wad
    exit /b 1
)

if not exist "crispy-doom.exe" (
    echo error: crispy-doom.exe not found in %SCRIPT_DIR%
    exit /b 1
)

crispy-doom.exe -iwad "%DOOM_WAD%" %*
