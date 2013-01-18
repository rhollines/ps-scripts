@echo OFF
set PROJECT=%1
set DAYS=%2
set RECIPIENTS=%3
set DRY_RUN=%4

IF (%PROJECT%) == () GOTO MISSING_PROJECT
IF (%RECIPIENTS%) == () GOTO MISSING_RECIPIENTS
IF (%DAYS%) == () set DAYS=1
IF (%DRY_RUN%) == () set DRY_RUN=false

java -cp lib\coverity-pse.jar com.coverity.ps.integrations.reporting.NotifyComponentManagers %PROJECT% %DAYS% %RECIPIENTS% %DRY_RUN%

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