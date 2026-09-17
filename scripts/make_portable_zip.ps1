$stagingDir = Join-Path $env:TEMP "OMPC_Portable_Build_$(Get-Random)"
$destDesktopFolder = 'C:\Users\user\Desktop\OMPC_Ballistic_AeroData_Portable'
$zipPath = 'C:\Users\user\Desktop\OMPC_Ballistic_AeroData_Portable.zip'

try {
    if (Test-Path $stagingDir) {
        Remove-Item -Recurse -Force $stagingDir -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path "$stagingDir\build\web" -Force | Out-Null
    Copy-Item "OMPC_Ballistic_AeroData.exe" -Destination "$stagingDir\OMPC_Ballistic_AeroData.exe" -Force
    Copy-Item -Recurse "build\web\*" -Destination "$stagingDir\build\web" -Force

    if (Test-Path $zipPath) {
        Remove-Item -Force $zipPath -ErrorAction SilentlyContinue
    }

    Compress-Archive -Path "$stagingDir\*" -DestinationPath $zipPath -CompressionLevel Optimal -Force
    Get-Item $zipPath | Select-Object Name, Length, LastWriteTime

    # Also update the extracted desktop folder if possible
    try {
        New-Item -ItemType Directory -Path "$destDesktopFolder\build\web" -Force -ErrorAction SilentlyContinue | Out-Null
        Copy-Item "OMPC_Ballistic_AeroData.exe" -Destination "$destDesktopFolder\OMPC_Ballistic_AeroData.exe" -Force -ErrorAction SilentlyContinue
        Copy-Item -Recurse "build\web\*" -Destination "$destDesktopFolder\build\web" -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "Note: Extracted desktop folder partially locked by active session; zip created cleanly."
    }
} finally {
    if (Test-Path $stagingDir) {
        Remove-Item -Recurse -Force $stagingDir -ErrorAction SilentlyContinue
    }
}
