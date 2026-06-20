@echo off
REM dmcp-agent.bat - Run the bundled DMCP Python helper from the package root.

setlocal
set "SCRIPT_DIR=%~dp0"
set "AGENT_DIR=%SCRIPT_DIR%agents\python"

where uv >nul 2>nul
if errorlevel 1 (
    echo error: uv is required to run dmcp-agent: https://docs.astral.sh/uv/
    exit /b 1
)

if not exist "%AGENT_DIR%" (
    echo error: bundled Python agent not found: %AGENT_DIR%
    exit /b 1
)

if "%UV_LINK_MODE%"=="" set "UV_LINK_MODE=copy"

pushd "%AGENT_DIR%"
uv run --quiet dmcp-agent %*
set "STATUS=%ERRORLEVEL%"
popd
exit /b %STATUS%
