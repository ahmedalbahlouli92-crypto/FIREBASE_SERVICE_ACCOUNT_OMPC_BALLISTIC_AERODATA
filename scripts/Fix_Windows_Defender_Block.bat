@echo off
title OMPC Ballistic AeroData - Unblock & Restore Helper
color 0a
echo ======================================================================
echo    OMPC Ballistic AeroData - Windows Defender Unblock Helper
echo ======================================================================
echo.
echo 1. Unblocking downloaded files (Removing Zone.Identifier)...
powershell -Command "Unblock-File -Path '%~dp0OMPC_Ballistic_AeroData*' -ErrorAction SilentlyContinue"
powershell -Command "Unblock-File -Path '%LOCALAPPDATA%\Programs\OMPC_Ballistic_AeroData\*' -ErrorAction SilentlyContinue"

echo 2. Ensuring executable is present in Programs folder...
if exist "%~dp0OMPC_Ballistic_AeroData.exe" (
    copy /y "%~dp0OMPC_Ballistic_AeroData.exe" "%LOCALAPPDATA%\Programs\OMPC_Ballistic_AeroData\OMPC_Ballistic_AeroData.exe" >nul 2>&1
    echo    [OK] Executable copied to Local Programs directory.
)

echo.
echo ======================================================================
echo  IMPORTANT: If Windows Defender still blocks the file:
echo ======================================================================
echo  1. Open Windows Security (Start menu -> "Windows Security")
echo  2. Click "Virus & threat protection"
echo  3. Click "Protection history"
echo  4. Find the blocked item (Wacatac.H!ml or OMPC_Ballistic_AeroData)
echo  5. Click "Actions" -> "Allow on device" (or "Restore")
echo.
echo  Alternatively, you can open the Cloud Web version anytime:
echo  https://ompc-ballistic-aerodata.web.app
echo ======================================================================
echo.
pause
