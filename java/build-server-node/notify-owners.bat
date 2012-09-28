@echo OFF
set ROOTDIR=C:\Users\fredrick_cov\coverity\build-server-node
set LIBDIR=%ROOTDIR%\lib-ext
set PROJECT=%1
set DAYS=%2
set DRY_RUN=%3

IF (%PROJECT%) == () GOTO MISSING_PROJECT
IF (%DAYS%) == () set DAYS=1
IF (%DRY_RUN%) == () set DRY_RUN=false

java -cp %ROOTDIR%\bin\coverity.jar;%LIBDIR%\coverity\cim-api-v4.jar;%LIBDIR%\coverity\saaj.jar;%LIBDIR%\coverity\saaj-impl-1.3.jar;%LIBDIR%\coverity\xws-security.jar com.coverity.ps.integrations.reporting.NotifyDefectOwners %PROJECT% %DAYS% %DRY_RUN%

GOTO END

:MISSING_PROJECT
echo.
echo You did not provide a project name. 
echo For example "notify-owners.bat Nightly 1"
echo.

:END