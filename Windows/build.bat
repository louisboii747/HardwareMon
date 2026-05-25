@echo off
:: ─────────────────────────────────────────────────────────────────
::  HardwareMon Windows .exe Build Script
::  Run this on your Windows machine.
:: ─────────────────────────────────────────────────────────────────

echo [1/4] Installing dependencies...
pip install customtkinter psutil gputil pyinstaller

echo.
echo [2/4] Locating CustomTkinter assets...
FOR /F "tokens=*" %%i IN ('python -c "import customtkinter; import os; print(os.path.dirname(customtkinter.__file__))"') DO SET CTK_PATH=%%i

echo CustomTkinter found at: %CTK_PATH%

echo.
echo [3/4] Building .exe with PyInstaller...
pyinstaller ^
  --onefile ^
  --windowed ^
  --name "HardwareMon" ^
  --add-data "%CTK_PATH%;customtkinter/" ^
  --hidden-import "customtkinter" ^
  --hidden-import "psutil" ^
  --hidden-import "GPUtil" ^
  --hidden-import "PIL" ^
  --collect-all customtkinter ^
  hardwaremon_win.py

echo.
echo [4/4] Done!
echo Your .exe is in the  dist\  folder: dist\HardwareMon.exe
echo.
pause
