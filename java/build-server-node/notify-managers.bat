@echo OFF
set ROOTDIR=.
set LIBDIR=%ROOTDIR%\lib-ext
set PROJECT=%1
set RECIPIENTS=%2
set DAYS=%3
set DRY_RUN=%4

IF (%PROJECT%) == () GOTO MISSING_PROJECT
IF (%RECIPIENTS%) == () GOTO MISSING_RECIPIENTS
IF (%DAYS%) == () set DAYS=1
IF (%DRY_RUN%) == () set DRY_RUN=false

java -cp %ROOTDIR%\bin\coverity.jar;%LIBDIR%\coverity\cim-api-v4.jar;%LIBDIR%\coverity\saaj.jar;%LIBDIR%\coverity\saaj-impl-1.3.jar;%LIBDIR%\coverity\xws-security.jar com.coverity.ps.integrations.reporting.NotifyDefectManagers %PROJECT% %DAYS% %RECIPIENTS% %DRY_RUN%

GOTO END

:MISSING_PROJECT
echo.
echo You did not provide a project name. 
echo For example "notify-managers.bat Nightly coverity_user,other_coverity_user 1"
echo.

GOTO END

:MISSING_RECIPIENTS
echo.
echo You did not provide a list of recipients. 
echo For example "notify-managers.bat Nightly coverity_user,other_coverity_user 1"
echo.

:END