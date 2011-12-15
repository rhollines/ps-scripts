cd ..\checkstyle
java -jar checkstyle-5.4-all.jar com.puppycrawl.tools.checkstyle.Main -c sun_checks.xml -r "C:\Users\rhollines\Desktop\src" -f xml -o ..\queues\input\cs.xml
cd ..\queues