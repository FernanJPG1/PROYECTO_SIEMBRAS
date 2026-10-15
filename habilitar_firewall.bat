@echo off
title Habilitar Firewall para Siembras
color 0B
echo ======================================================================
echo    HABILITANDO PUERTOS EN EL FIREWALL DE WINDOWS PARA SIEMBRAS
echo ======================================================================
echo.
echo Abriendo puerto TCP 8000 (Backend API)...
netsh advfirewall firewall add rule name="Siembras_Backend_8000" dir=in action=allow protocol=TCP localport=8000 profile=any
echo Abriendo puerto UDP 8001 (Faro Autodescubrimiento)...
netsh advfirewall firewall add rule name="Siembras_Beacon_8001" dir=in action=allow protocol=UDP localport=8001 profile=any
echo Habilitando Python para cualquier perfil de red...
netsh advfirewall firewall set rule name="Python" new profile=any
echo.
echo ======================================================================
echo   LISTO: Puertos habilitados en todas las redes (Publica y Privada)
echo ======================================================================
pause
