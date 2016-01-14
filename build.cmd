@echo off

setlocal ENABLEDELAYEDEXPANSION

if '%1' == '/?' goto usage
if '%1' == '-?' goto usage
if '%1' == '?' goto usage
if '%1' == '/help' goto usage
if '%1' == '--help' goto usage
if '%1' == '-help' goto usage

rem TOMCAT_VERSION can be overridden by build script
if '%TOMCAT_VERSION%'=='' set TOMCAT_VERSION=7.0.67
if '%BUILD_NUMBER%'=='' set BUILD_NUMBER=%TOMCAT_VERSION%
set REPOSITORY_ROOT=%~dp0
set WGET=%REPOSITORY_ROOT%\tools\wget.exe
set ZIP=%REPOSITORY_ROOT%\tools\7-zip\7z.exe
set PUBLISHDIR=%~dp0artifacts\publish
set PACKAGEDIR=%~dp0artifacts\package

:VARS
set ZIP_FILE=apache-tomcat-%TOMCAT_VERSION%-windows-x64.zip
set ZIP_PATH=%~dp0artifacts\%ZIP_FILE%
set ZIP_FOLDER=apache-tomcat-%TOMCAT_VERSION%
set DOWNLOAD_URL=http://www.apache.org/dist/tomcat/tomcat-7/v%TOMCAT_VERSION%/bin/%ZIP_FILE%

:CLEANPUBLISHDIR
if not exist %PUBLISHDIR% goto CLEANPACKAGEDIR
rmdir /S /Q %PUBLISHDIR%

:CLEANPACKAGEDIR
if not exist %PACKAGEDIR% goto CLEANZIP
rmdir /S /Q %PACKAGEDIR%

:CLEANZIP
if not exist "%ZIP_PATH%" goto RUN
del %ZIP_PATH%

:RUN
mkdir %PUBLISHDIR%
mkdir %PACKAGEDIR%

echo Downloading Tomcat from %DOWNLOAD_URL%...
%WGET% -nv "%DOWNLOAD_URL%" -O "%ZIP_PATH%"
if errorlevel 1 goto FAILED

echo Unzipping Tomcat to %PUBLISHDIR%...
%ZIP% x %ZIP_PATH% -r -o%PUBLISHDIR%
if errorlevel 1 goto FAILED

echo Deleting zip file %ZIP_PATH%...
del %ZIP_PATH%

echo Moving Tomcat files to root of package...
xcopy /S /Y /Q "%PUBLISHDIR%\%ZIP_FOLDER%\*.*" "%PUBLISHDIR%"
rmdir /S /Q "%PUBLISHDIR%\%ZIP_FOLDER%"

echo Applying custom configuration...
rem Use log4j instead of default java.util.logging
del "%PUBLISHDIR%\conf\logging.properties"
xcopy /S /Y %~dp0bin "%PUBLISHDIR%\bin"
xcopy /S /Y %~dp0conf "%PUBLISHDIR%\conf"
xcopy /S /Y %~dp0lib "%PUBLISHDIR%\lib"

echo Packing Tomcat...
%~dp0.nuget\nuget.exe pack %~dp0Tomcat.nuspec -Version %BUILD_NUMBER% -OutputDirectory %PACKAGEDIR% -NoPackageAnalysis

goto FINISH

:USAGE
echo.
echo Usage: build.bat
echo.
goto FINISH

:FAILED
echo Build failed
EXIT /B %ERRORLEVEL%

:FINISH