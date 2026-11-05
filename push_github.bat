@echo off
title Vendix - Subir a GitHub
cd /d "%~dp0"
echo ========================================================
echo   Sincronizando y Subiendo cambios de VENDIX a GitHub...
echo ========================================================
echo.
git push origin main
echo.
if %errorlevel% equ 0 (
    echo [EXITO] Cambios subidos correctamente a GitHub.
) else (
    echo [AVISO] Hubo un problema al subir a GitHub. Verifica tus credenciales.
)
echo.
pause
