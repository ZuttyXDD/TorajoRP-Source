@echo off
setlocal
cd /d "%~dp0"
echo Compilando TorajoRP para Android...
echo Certifique-se de que Haxe, Lime, HaxeFlixel, Android SDK e Java estao configurados.
haxelib run lime build android
if errorlevel 1 (
  echo.
  echo A compilacao falhou. Confira os requisitos do Android SDK/NDK e as mensagens acima.
  pause
  exit /b 1
)
echo.
echo Build Android concluida. Confira a pasta export\android\bin.
pause
