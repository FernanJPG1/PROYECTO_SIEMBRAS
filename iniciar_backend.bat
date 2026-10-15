@echo off
title Servidor Backend Siembras (FastAPI + Microsoft Access)
color 0A
echo ======================================================================
echo          INICIANDO SERVIDOR BACKEND SIEMBRAS (FASTAPI)
echo ======================================================================
echo.
echo   IP Local de este Servidor : 192.168.1.39:8000
echo   Base de Datos Empresarial : D:\PROYECTO SIEMBRAS\bmempresarial2021.accdb
echo.
echo   La tablet se conecta automaticamente a este servidor para:
echo     - Descargar catalogos actualizados (variedades, camas, operarios)
echo     - Sincronizar las siembras directamente a Microsoft Access
echo.
echo   [!] NO CIERRES ESTA VENTANA mientras se use la app en las tablets.
echo ======================================================================
echo.

cd /d "%~dp0backend"
python run.py

pause
