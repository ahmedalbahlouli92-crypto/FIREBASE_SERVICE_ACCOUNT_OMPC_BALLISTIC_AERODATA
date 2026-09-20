@echo off
title OMPC Ballistic AeroData - Emergency Process Stopper and Unlocker
color 0b
echo ======================================================================
echo   OMPC Ballistic AeroData - Emergency Unlock ^& Cleanup Tool
echo ======================================================================
echo.
echo Terminating any active OMPC background processes on this computer...
taskkill /F /IM OMPC_Ballistic_AeroData.exe /T 2>nul
taskkill /F /IM OMPC_App_Host.exe /T 2>nul
taskkill /F /IM OMPC_Ballistic_AeroData_Setup.exe /T 2>nul
echo.
echo [SUCCESS] All OMPC background processes have been terminated!
echo All locked files are now completely released.
echo You can now delete, replace, or copy new updates freely without any errors.
echo.
pause
