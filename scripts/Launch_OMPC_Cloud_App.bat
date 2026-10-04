@echo off
title Launch OMPC Ballistic AeroData

:: Suppress Edge unsupported OS banner and deprecation notices
reg add "HKCU\Software\Policies\Microsoft\Edge" /v SuppressUnsupportedOSWarning /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Policies\Microsoft\Edge" /v HideFirstRunExperience /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Policies\Google\Chrome" /v SuppressUnsupportedOSWarning /t REG_DWORD /d 1 /f >nul 2>&1

start msedge --app=https://ompc-ballistic-aerodata.web.app --start-maximized --disable-features=msEdgeSyncNotice,msEdgeSyncNoticeDialog,msEdgeProfilePicker,msEdgeShowSyncNotice,msFirstRunExperience,msEdgeDeprecationBanner,msEdgeDeprecationNotice --disable-component-update --suppress-unsupported-os-warning --disable-sync --disable-fre --disable-infobars --suppress-message-center-popups --simulate-outdated-no-au="Tue, 31 Dec 2099 23:59:59 GMT"
if %ERRORLEVEL% neq 0 (
    start chrome --app=https://ompc-ballistic-aerodata.web.app --start-maximized --disable-features=msEdgeDeprecationBanner,msEdgeDeprecationNotice --disable-component-update --suppress-unsupported-os-warning
)
if %ERRORLEVEL% neq 0 (
    start https://ompc-ballistic-aerodata.web.app
)
exit
