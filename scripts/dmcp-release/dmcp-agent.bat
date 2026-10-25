@echo off
REM dmcp-agent.bat - Run the bundled DMCP Python agent (standard library only).

setlocal
set "AGENT_DIR=%~dp0agents\python"

if not exist "%AGENT_DIR%\dmcp_agent" (
    echo error: bundled Python agent not found: %AGENT_DIR%
    exit /b 1
)

set "PYTHON=python"
where python >nul 2>nul
if errorlevel 1 (
    where py >nul 2>nul
    if errorlevel 1 (
        echo error: Python 3.10 or newer is required to run dmcp-agent
        exit /b 1
    )
    set "PYTHON=py -3"
)

set "PYTHONDONTWRITEBYTECODE=1"
set "PYTHONPATH=%AGENT_DIR%;%PYTHONPATH%"
%PYTHON% -m dmcp_agent %*
exit /b %ERRORLEVEL%
