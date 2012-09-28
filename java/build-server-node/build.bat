set ROOTDIR=.
set LIBDIR=%ROOTDIR%\lib-ext
cd %ROOTDIR%
javac -cp %ROOTDIR%\bin\coverity.jar;%LIBDIR%\coverity\cim-api-v4.jar;%LIBDIR%\coverity\saaj.jar;%LIBDIR%\coverity\saaj-impl-1.3.jar;%LIBDIR%\coverity\xws-security.jar -sourcepath src -d bin src\com\coverity\ps\common\plugins\scm\*.java
javac -cp %ROOTDIR%\bin\coverity.jar;%LIBDIR%\coverity\cim-api-v4.jar;%LIBDIR%\coverity\saaj.jar;%LIBDIR%\coverity\saaj-impl-1.3.jar;%LIBDIR%\coverity\xws-security.jar -sourcepath src -d bin src\com\coverity\ps\integrations\reporting\*.java
cd bin
jar -cvf coverity.jar com
cd ..

@REM run java -classpath %ROOTDIR%\bin\coverity.jar;%LIBDIR%\coverity\cim-api-v4.jar;%LIBDIR%\coverity\saaj.jar;%LIBDIR%\coverity\saaj-impl-1.3.jar;%LIBDIR%\coverity\xws-security.jar com.coverity.ps.integrations.AssignDefectOwners true
