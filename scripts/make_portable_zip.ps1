$stagingDir = Join-Path $env:TEMP "OMPC_Portable_Build_$(Get-Random)"
$destDesktopFolder = 'C:\Users\user\Desktop\OMPC_Ballistic_AeroData_Portable'
$zipPath = 'C:\Users\user\Desktop\OMPC_Ballistic_AeroData_Portable.zip'
$cscPath = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$webBundleZip = 'scripts\web_bundle.zip'

try {
    Write-Host "Stopping any running OMPC instances..."
    Get-Process OMPC_Ballistic_AeroData -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500

    Write-Host "1. Bundling web application assets..."
    if (Test-Path $webBundleZip) {
        Remove-Item -Force $webBundleZip -ErrorAction SilentlyContinue
    }
    Compress-Archive -Path "build\web\*" -DestinationPath $webBundleZip -CompressionLevel Optimal -Force

    Write-Host "2. Compiling self-contained executable with embedded web resource..."
    & $cscPath /target:winexe /r:System.Windows.Forms.dll /r:System.IO.Compression.FileSystem.dll "/resource:$webBundleZip" /out:OMPC_Ballistic_AeroData.exe scripts\standalone_server.cs
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

    if (Test-Path $zipPath) {
        Remove-Item -Force $zipPath -ErrorAction SilentlyContinue
    }

    Write-Host "4. Compressing to portable zip: $zipPath..."
    Compress-Archive -Path "$stagingDir\*" -DestinationPath $zipPath -CompressionLevel Optimal -Force
    Get-Item $zipPath | Select-Object Name, Length, LastWriteTime

    # Also update the extracted desktop folder and Desktop shortcut
    try {
        New-Item -ItemType Directory -Path "$destDesktopFolder\build\web" -Force -ErrorAction SilentlyContinue | Out-Null
        Copy-Item "OMPC_Ballistic_AeroData.exe" -Destination "$destDesktopFolder\OMPC_Ballistic_AeroData.exe" -Force -ErrorAction SilentlyContinue
        Copy-Item -Recurse "build\web\*" -Destination "$destDesktopFolder\build\web" -Force -ErrorAction SilentlyContinue
        Copy-Item "OMPC_Ballistic_AeroData.exe" -Destination "C:\Users\user\Desktop\OMPC_Ballistic_AeroData.exe" -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "Note: Extracted desktop folder partially locked by active session; zip created cleanly."
    }
    Write-Host "Successfully packaged self-contained portable distribution!"
} finally {
    if (Test-Path $stagingDir) {
        Remove-Item -Recurse -Force $stagingDir -ErrorAction SilentlyContinue
    }
    if (Test-Path $webBundleZip) {
        Remove-Item -Force $webBundleZip -ErrorAction SilentlyContinue
    }
}

