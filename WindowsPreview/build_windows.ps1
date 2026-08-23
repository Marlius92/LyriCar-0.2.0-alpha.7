$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
python -m pip install --upgrade pip
python -m pip install -r requirements-build.txt
python -m pip install -r requirements-windows-local.txt
python -m unittest discover -s tests -v
pyinstaller --noconfirm --clean --onefile --windowed `
  --name LyriCar-Preview `
  --add-data "assets;assets" `
  --hidden-import "winrt.windows.media.control" `
  --collect-submodules "winrt" `
  lyricar_preview.py
Write-Host "Build completata: $PSScriptRoot\dist\LyriCar-Preview.exe"
