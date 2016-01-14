@echo off

rem Sets CATALINA_HOME variable from %1 then runs Tomcat service.bat
rem Usage: runservice.bat C:\Tomcat7 remove
rem Or:    runservice.bat C:\Tomcat7 install
set CATALINA_HOME=%1
echo CATALINA_HOME = %CATALINA_HOME%
echo Calling service.bat %2
%CATALINA_HOME%\bin\service.bat %2