@echo OFF
set ROOTDIR=C:\Users\fredrick_cov\coverity\build-server-node
set LIBDIR=%ROOTDIR%\lib-ext
set STREAM=%1
set DRY_RUN=%2

IF (%STREAM%) == () GOTO MISSING_STREAM
IF (%DRY_RUN%) == () set DRY_RUN=false

java -cp %ROOTDIR%\bin\coverity.jar;%LIBDIR%\coverity\cim-api-v4.jar;%LIBDIR%\coverity\saaj.jar;%LIBDIR%\coverity\saaj-impl-1.3.jar;%LIBDIR%\coverity\xws-security.jar com.coverity.ps.integrations.AssignSeverity %STREAM% false %ROOTDIR%\config\coverity-bn-severity.xml %DRY_RUN%

GOTO END

:MISSING_STREAM
echo.
echo You did not provide a stream name. 
echo For example "set-defect-severity.bat Game-Stream-MAIN"
echo.

:END