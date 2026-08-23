@echo off
setlocal
cd /d "%~dp0"

where py >nul 2>&1
if not errorlevel 1 (
    set "PYTHON_CMD=py"
) else (
    where python >nul 2>&1
    if errorlevel 1 (
        echo Python non trovato. Installa Python 3.12 e abilita "Add Python to PATH".
        pause
        exit /b 1
    )
    set "PYTHON_CMD=python"
)

%PYTHON_CMD% -c "from PIL import Image, ImageTk" >nul 2>&1
if errorlevel 1 (
    echo Prima configurazione: installo il renderer grafico fluido...
    %PYTHON_CMD% -m pip install --user -r requirements-preview.txt
    if errorlevel 1 (
        echo Installazione non riuscita. Controlla la connessione Internet e riprova.
        pause
        exit /b 1
    )
)

%PYTHON_CMD% lyricar_preview.py --profile generic_carplay_landscape
if errorlevel 1 pause
endlocal
