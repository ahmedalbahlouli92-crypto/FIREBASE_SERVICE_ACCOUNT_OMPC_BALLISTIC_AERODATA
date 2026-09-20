@echo off
title Stop OMPC Ballistic AeroData
echo ===================================================
echo   Stopping OMPC Ballistic AeroData Processes
echo ===================================================
echo.
taskkill /F /IM OMPC_Ballistic_AeroData.exe /T 2>nul
taskkill /F /IM OMPC_Ballistic_AeroData_Setup.exe /T 2>nul
echo.
echo All OMPC Ballistic AeroData processes have been terminated.
echo All locked files are now released.
echo You can now safely delete, overwrite, or restart the application.
echo.
pause
