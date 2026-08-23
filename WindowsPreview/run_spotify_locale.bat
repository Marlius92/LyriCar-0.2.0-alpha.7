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

%PYTHON_CMD% -c "import winrt.windows.media.control; from PIL import Image, ImageTk" >nul 2>&1
if errorlevel 1 (
    echo.
    echo Prima configurazione: installo Windows Media Control e il renderer fluido...
    echo Non serve alcun Client ID Spotify.
    echo.
    %PYTHON_CMD% -m pip install --user -r requirements-windows-local.txt
    if errorlevel 1 (
        echo.
        echo Installazione non riuscita. Controlla la connessione Internet e riprova.
        pause
        exit /b 1
    )
)

%PYTHON_CMD% lyricar_preview.py --profile renault_clio_9_3 --mode windows_media
if errorlevel 1 pause
endlocal
