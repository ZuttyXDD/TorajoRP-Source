
@echo off
setlocal EnableExtensions
title TorajoRP - Setup
color 0A

cd /d "%~dp0.."

echo.
echo ==================================================
echo             TORAJORP - INSTALADOR
echo ==================================================
echo.

echo [1/5] Verificando Git...
where git >nul 2>&1
if errorlevel 1 goto ERROR_GIT
echo [OK] Git encontrado.

echo.
echo [2/5] Verificando Haxe e Haxelib...
where haxe >nul 2>&1
if errorlevel 1 goto ERROR_HAXE
where haxelib >nul 2>&1
if errorlevel 1 goto ERROR_HAXE
echo [OK] Haxe e Haxelib encontrados.

echo.
echo [3/5] Baixando submodulos...
if not exist ".git" goto ERROR_REPOSITORY

git submodule sync --recursive
if errorlevel 1 goto ERROR_SUBMODULE

git submodule update --init --recursive
if errorlevel 1 goto ERROR_SUBMODULE

echo [OK] Submodulos atualizados.

echo.
echo [4/5] Instalando TorajoWebSocket...
haxelib install TorajoWebSocket
if errorlevel 1 goto ERROR_HAXELIB

echo [OK] TorajoWebSocket instalado.

echo.
echo [5/5] Instalando dependencias do project.xml...

if not exist "project.xml" goto ERROR_PROJECT

rem Dependencias Haxelib do projeto
for %%L in (flixel flixel-addons lime openfl flxanimate hscript-iris hxcpp hxssl hxvlc tjson extension-admob extension-androidtools hxdiscord_rpc linc_luajit) do (
    echo.
    echo Verificando %%L...
    haxelib install %%L
    if errorlevel 1 goto ERROR_DEPENDENCY
)

echo.
echo ==================================================
echo          SETUP CONCLUIDO COM SUCESSO!
echo ==================================================
echo.
echo Todas as etapas foram executadas.
goto END

:ERROR_GIT
echo.
echo [ERRO] Git nao encontrado.
echo Instale: https://git-scm.com/download/win
goto END

:ERROR_HAXE
echo.
echo [ERRO] Haxe ou Haxelib nao encontrado.
echo Instale: https://haxe.org/download/
goto END

:ERROR_REPOSITORY
echo.
echo [ERRO] Repositorio Git nao encontrado.
echo Baixe o projeto usando git clone.
goto END

:ERROR_SUBMODULE
echo.
echo [ERRO] Falha ao baixar os submodulos.
goto END

:ERROR_HAXELIB
echo.
echo [ERRO] Falha ao instalar TorajoWebSocket.
goto END

:ERROR_PROJECT
echo.
echo [ERRO] project.xml nao encontrado.
goto END

:ERROR_DEPENDENCY
echo.
echo [ERRO] Falha ao instalar uma dependencia.
goto END

:END
echo.
echo Pressione qualquer tecla para fechar...
pause >nul
endlocal
exit /b
