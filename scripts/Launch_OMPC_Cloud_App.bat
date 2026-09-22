@echo off
title Launch OMPC Ballistic AeroData
start msedge --app=https://ompc-ballistic-aerodata.web.app
if %ERRORLEVEL% neq 0 (
    start chrome --app=https://ompc-ballistic-aerodata.web.app
)
if %ERRORLEVEL% neq 0 (
    start https://ompc-ballistic-aerodata.web.app
)
exit
