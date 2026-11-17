@echo off
setlocal enabledelayedexpansion
title Vendix - Subir Cambios a GitHub
cd /d "%~dp0"

echo ========================================================
echo         VENDIX - Sincronizacion con GitHub
echo ========================================================
echo.

:: Verificar si git esta instalado
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Git no esta instalado o no se encuentra en el PATH.
    pause
    exit /b 1
)

:: Detectar rama activa
for /f "tokens=*" %%i in ('git branch --show-current 2^>nul') do set CURRENT_BRANCH=%%i
if "%CURRENT_BRANCH%"=="" set CURRENT_BRANCH=main

echo Rama activa: %CURRENT_BRANCH%
echo.

:: 1. Agregar todos los cambios respetando .gitignore
echo [1/4] Preparando cambios locales (git add)...
git add -A

:: 2. Verificar si hay cambios pendientes por commitear
git diff --cached --quiet
if %errorlevel% equ 0 (
    echo [INFO] No hay cambios nuevos en codigo para commitear.
) else (
    echo [INFO] Se detectaron archivos modificados o nuevos.
    echo.
    set /p "COMMIT_MSG=Ingresa la descripcion del commit (o presiona ENTER para usar fecha/hora): "
    if "!COMMIT_MSG!"=="" (
        for /f "tokens=1-3 delims=/ " %%a in ('date /t') do set FECHA=%%a-%%b-%%c
        for /f "tokens=1-2 delims=: " %%a in ('time /t') do set HORA=%%a:%%b
        set "COMMIT_MSG=Actualizacion Vendix !FECHA! !HORA!"
    )
    echo.
    echo [2/4] Creando commit: "!COMMIT_MSG!"...
    git commit -m "!COMMIT_MSG!"
)

:: 3. Obtener posibles cambios remotos (pull con rebase)
echo.
echo [3/4] Verificando sincronizacion con remoto (git pull --rebase)...
git pull --rebase origin %CURRENT_BRANCH%

:: 4. Subir a GitHub
echo.
echo [4/4] Subiendo cambios a GitHub (%CURRENT_BRANCH%)...
git push origin %CURRENT_BRANCH%

echo.
if %errorlevel% equ 0 (
    echo ========================================================
    echo   [EXITO] Proyecto sincronizado correctamente con GitHub!
    echo ========================================================
) else (
    echo ========================================================
    echo   [ERROR] No se pudo subir a GitHub.
    echo   Verifica tu conexion a internet o tus credenciales.
    echo ========================================================
)

echo.
pause
