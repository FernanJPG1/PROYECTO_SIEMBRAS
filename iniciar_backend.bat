@echo off
title Servidor Backend - Siembras Buenavista Flowers
color 2F
echo =====================================================================
echo    SERVIDOR EMPRESARIAL DE SIEMBRAS - BUENAVISTA FLOWERS
echo =====================================================================
echo.
echo  Detectando direccion IP local para tablets y celulares...
for /f "tokens=4" %%a in ('route print ^| findstr 0.0.0.0 ^| findstr /v "0.0.0.0.*0.0.0.0"') do (
    set LOCAL_IP=%%a
)
echo.
echo  [OK] El servidor estara disponible en la red Wi-Fi en:
echo       http://192.168.1.39:8000/api
echo.
echo  (Asegurate de que las tablets/celulares esten conectados a la misma red Wi-Fi)
echo.
echo =====================================================================
echo.
cd /d "%~dp0backend"
python run.py
pause

