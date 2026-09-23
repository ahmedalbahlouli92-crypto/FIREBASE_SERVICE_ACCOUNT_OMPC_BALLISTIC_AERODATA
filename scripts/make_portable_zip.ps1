$stagingDir = Join-Path $env:TEMP "OMPC_Portable_Build_$(Get-Random)"
$destDesktopFolder = 'C:\Users\user\Desktop\OMPC_Ballistic_AeroData_Portable'
$zipPath = 'C:\Users\user\Desktop\OMPC_Ballistic_AeroData_Portable.zip'
$setupExePath = 'C:\Users\user\Desktop\OMPC_Ballistic_AeroData_Setup.exe'
$cscPath = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$webBundleZip = 'scripts\web_bundle.zip'
$setupPayloadZip = 'scripts\setup_payload.zip'
$appIconPath = 'windows\runner\resources\app_icon.ico'

try {
    Write-Host "Stopping any running OMPC instances..."
    Get-Process OMPC_Ballistic_AeroData -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500

    Write-Host "1. Bundling web application assets..."
    if (Test-Path $webBundleZip) {
        Remove-Item -Force $webBundleZip -ErrorAction SilentlyContinue
    }
    $tempWebDir = Join-Path $env:TEMP "ompc_web_bundle_$(Get-Random)"
    Copy-Item -Path "build\web" -Destination $tempWebDir -Recurse -Force
    Compress-Archive -Path "$tempWebDir\*" -DestinationPath $webBundleZip -CompressionLevel Optimal -Force
    Remove-Item -Recurse -Force $tempWebDir -ErrorAction SilentlyContinue

    Write-Host "2. Compiling self-contained executable with embedded web resource and icon..."
    $iconArg = ""
    if (Test-Path $appIconPath) {
        $iconArg = "/win32icon:$appIconPath"
    }

    if ($iconArg -ne "") {
        & $cscPath /target:winexe $iconArg /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll "/resource:$webBundleZip" /out:OMPC_Ballistic_AeroData.exe scripts\standalone_server.cs
    } else {
        & $cscPath /target:winexe /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll "/resource:$webBundleZip" /out:OMPC_Ballistic_AeroData.exe scripts\standalone_server.cs
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to compile OMPC_Ballistic_AeroData.exe"
    }

    Write-Host "3. Creating staging package..."
    if (Test-Path $stagingDir) {
        Remove-Item -Recurse -Force $stagingDir -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path "$stagingDir\build\web" -Force | Out-Null
    Copy-Item "OMPC_Ballistic_AeroData.exe" -Destination "$stagingDir\OMPC_Ballistic_AeroData.exe" -Force
    Copy-Item -Recurse "build\web\*" -Destination "$stagingDir\build\web" -Force
    if (Test-Path $appIconPath) {
        Copy-Item $appIconPath -Destination "$stagingDir\app_icon.ico" -Force
    }
    if (Test-Path "scripts\Stop_OMPC.bat") {
        Copy-Item "scripts\Stop_OMPC.bat" -Destination "$stagingDir\Stop_OMPC.bat" -Force
        Copy-Item "scripts\Stop_OMPC.bat" -Destination "C:\Users\user\Desktop\Stop_OMPC.bat" -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path "scripts\Force_Unlock_All.bat") {
        Copy-Item "scripts\Force_Unlock_All.bat" -Destination "$stagingDir\Force_Unlock_All.bat" -Force
        Copy-Item "scripts\Force_Unlock_All.bat" -Destination "C:\Users\user\Desktop\Force_Unlock_All.bat" -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path $zipPath) {
        Remove-Item -Force $zipPath -ErrorAction SilentlyContinue
    }

    Write-Host "4. Compressing to portable zip: $zipPath..."
    Compress-Archive -Path "$stagingDir\*" -DestinationPath $zipPath -CompressionLevel Optimal -Force
    Get-Item $zipPath | Select-Object Name, Length, LastWriteTime

    # Update extracted desktop folder, standalone executable on Desktop, and Local Programs folder (for Desktop Shortcut)
    try {
        New-Item -ItemType Directory -Path "$destDesktopFolder\build\web" -Force -ErrorAction SilentlyContinue | Out-Null
        Copy-Item "OMPC_Ballistic_AeroData.exe" -Destination "$destDesktopFolder\OMPC_Ballistic_AeroData.exe" -Force -ErrorAction SilentlyContinue
        Copy-Item -Recurse "build\web\*" -Destination "$destDesktopFolder\build\web" -Force -ErrorAction SilentlyContinue
        Copy-Item "OMPC_Ballistic_AeroData.exe" -Destination "C:\Users\user\Desktop\OMPC_Ballistic_AeroData.exe" -Force -ErrorAction SilentlyContinue

        $localProgramsDir = "$env:LOCALAPPDATA\Programs\OMPC_Ballistic_AeroData"
        if (Test-Path $localProgramsDir) {
            Copy-Item "OMPC_Ballistic_AeroData.exe" -Destination "$localProgramsDir\OMPC_Ballistic_AeroData.exe" -Force -ErrorAction SilentlyContinue
            Write-Host "  [OK] Synchronized executable to Local Programs folder for desktop shortcut."
        }
    } catch {
        Write-Host "Note: Desktop folder partially locked by active session; files updated where possible."
    }

    Write-Host "5. Compiling 1-Click Setup Installer: $setupExePath..."
    if (Test-Path $setupPayloadZip) {
        Remove-Item -Force $setupPayloadZip -ErrorAction SilentlyContinue
    }
    Compress-Archive -Path "$stagingDir\*" -DestinationPath $setupPayloadZip -CompressionLevel Optimal -Force

    $localInstaller = 'OMPC_Ballistic_AeroData_Setup.exe'
    if ($iconArg -ne "") {
        & $cscPath /target:winexe $iconArg /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll "/resource:$setupPayloadZip" /out:$localInstaller scripts\installer.cs
    } else {
        & $cscPath /target:winexe /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll "/resource:$setupPayloadZip" /out:$localInstaller scripts\installer.cs
    }

    if ($LASTEXITCODE -eq 0 -and (Test-Path $localInstaller)) {
        Copy-Item $localInstaller -Destination $setupExePath -Force -ErrorAction SilentlyContinue
        Get-Item $setupExePath | Select-Object Name, Length, LastWriteTime
        Write-Host "Successfully compiled 1-Click Setup Installer!"
    } else {
        Write-Warning "Setup installer compilation failed or exited with errors."
    }

    Write-Host "`nSUCCESS! Build Outputs Available on your Desktop:"
    Write-Host "  1. Setup Installer:  C:\Users\user\Desktop\OMPC_Ballistic_AeroData_Setup.exe"
    Write-Host "  2. Portable App:     C:\Users\user\Desktop\OMPC_Ballistic_AeroData.exe"
    Write-Host "  3. Portable Zip:     C:\Users\user\Desktop\OMPC_Ballistic_AeroData_Portable.zip"
} finally {
    if (Test-Path $stagingDir) {
        Remove-Item -Recurse -Force $stagingDir -ErrorAction SilentlyContinue
    }
    if (Test-Path $webBundleZip) {
        Remove-Item -Force $webBundleZip -ErrorAction SilentlyContinue
    }
    if (Test-Path $setupPayloadZip) {
        Remove-Item -Force $setupPayloadZip -ErrorAction SilentlyContinue
    }
}
