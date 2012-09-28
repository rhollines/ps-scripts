@echo OFF
set ROOTDIR=C:\Users\fredrick_cov\coverity\build-server-node
set LIBDIR=%ROOTDIR%\lib-ext
set DRY_RUN=%1

IF (%DRY_RUN%) == () set DRY_RUN=false

java -cp %ROOTDIR%\bin\coverity.jar;%LIBDIR%\coverity\cim-api-v4.jar;%LIBDIR%\coverity\saaj.jar;%LIBDIR%\coverity\saaj-impl-1.3.jar;%LIBDIR%\coverity\xws-security.jar com.coverity.ps.integrations.AssignDefectOwners %DRY_RUN%

:END