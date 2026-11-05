@echo off
cd /d "%~dp0"
echo Iniciando EcoHome en Chrome...
echo Mantén esta ventana abierta mientras pruebas la app.
call flutter run -d chrome --web-port 7357
pause
