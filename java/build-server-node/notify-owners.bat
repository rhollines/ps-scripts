@echo OFF
set PROJECT=%1
set DAYS=%2
set USER_COMP_FILE=%3
set DRY_RUN=%4

IF (%PROJECT%) == () GOTO MISSING_PROJECT
IF (%USER_COMP_FILE%) == () GOTO MISSING_USER_COMP_FILE
IF (%DAYS%) == () set DAYS=1
IF (%DRY_RUN%) == () set DRY_RUN=false

java -cp lib\coverity-pse.jar com.coverity.ps.integrations.reporting.NotifyComponentOwnersSummary %PROJECT% %DAYS% %USER_COMP_FILE% %DRY_RUN%

GOTO END

:MISSING_PROJECT
echo.
echo You did not provide a project name. 
echo For example "notify-owners.bat Nightly coverity_user,other_coverity_user 1"
echo.

GOTO END

:MISSING_USER_COMP_FILE
echo.
echo You did not provide the name of the mapping file. 
echo For example "notify-owners.bat Nightly coverity_user,other_coverity_user 1"
echo.

:END