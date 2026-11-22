@echo off
setlocal
 title Gerar AAB - TorajoRP 0.8.0

REM Execute este BAT dentro da pasta mobile do TorajoRP.
cd /d "%~dp0"

echo ============================================
echo       TORAJORP - GERADOR DE AAB
 echo ============================================
echo.

if not exist "project.xml" (
    echo ERRO: Este arquivo BAT precisa ficar dentro da pasta mobile,
    echo junto do project.xml.
    echo.
    pause
    exit /b 1
)

echo [1/2] Preparando/atualizando o projeto Android com Lime...
echo.
call haxelib run lime build android -final -release
if errorlevel 1 (
    echo.
    echo ERRO: O Lime falhou ao preparar/compilar o projeto Android.
    echo Confira as mensagens acima antes de tentar novamente.
    pause
    exit /b 1
)

if not exist "export\android\bin\gradlew.bat" (
    echo.
    echo ERRO: Nao encontrei export\android\bin\gradlew.bat.
    echo Verifique se o Lime gerou o projeto Android corretamente.
    pause
    exit /b 1
)

echo.
echo [2/2] Gerando o Android App Bundle (AAB)...
echo.
pushd "export\android\bin"
call gradlew.bat :app:bundleRelease
set "BUILD_RESULT=%ERRORLEVEL%"
popd

if not "%BUILD_RESULT%"=="0" (
    echo.
    echo ERRO: O Gradle nao conseguiu gerar o AAB.
    echo Confira as mensagens acima.
    pause
    exit /b %BUILD_RESULT%
)

echo.
echo ============================================
echo AAB GERADO COM SUCESSO!
echo ============================================
echo.
echo Procure o arquivo em:
echo export\android\bin\app\build\outputs\bundle\release\
echo.
echo O arquivo pode se chamar app-release.aab ou ter outro nome
 echo definido pelo projeto.
echo.
pause
endlocal
