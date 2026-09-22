@echo off
set "JAVA_HOME=C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot"
set "PATH=%JAVA_HOME%\bin;%PATH%"
set "ANDROID_HOME=C:\Users\user\android-sdk"
echo Using JAVA_HOME: %JAVA_HOME%
java -version
call "C:\Users\user\.puro\envs\stable\flutter\bin\flutter.bat" build apk --release
if %ERRORLEVEL% equ 0 (
    copy /y "build\app\outputs\flutter-apk\app-release.apk" "C:\Users\user\Desktop\OMPC_Ballistic_AeroData_v1.4.3.apk"
    copy /y "build\app\outputs\flutter-apk\app-release.apk" "C:\Users\user\Desktop\OMPC_Ballistic_AeroData.apk"
    echo [SUCCESS] Copied APK to Desktop: C:\Users\user\Desktop\OMPC_Ballistic_AeroData_v1.4.3.apk
)
