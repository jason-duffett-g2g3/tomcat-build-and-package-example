@echo off

REM Reset CATALINA_HOME as Tomcat folder will change
SET CATALINA_HOME=

setlocal EnableDelayedExpansion

if '%1' == '/?' goto PRINT_USAGE
if '%1' == '-?' goto PRINT_USAGE
if '%1' == '?' goto PRINT_USAGE
if '%1' == '/help' goto PRINT_USAGE
if '%1' == '--help' goto PRINT_USAGE
if '%1' == '-help' goto PRINT_USAGE

SET REPOSITORY_ROOT=%~dp0..\..
set APPLICATION=Tomcat
set SERVICENAME=Tomcat7
set PACKAGESOURCE=%~dp0artifacts\package
set TARGETDIRECTORY=%SYSTEMDRIVE%\Apps
set WGET=%REPOSITORY_ROOT%\Build-Tools\wget.exe
set NUGET=%~dp0.nuget\NuGet.exe

goto CHECK_ARGS

rem ### Script Usage ##########################################
:PRINT_USAGE
echo.
echo ERROR: Missing arguments.
echo Correct usage: 
echo    %0 [PackageSource] [TargetDir]
echo.
echo    PackageSource:  Path or Uri to the NuGet source containing the %APPLICATION% package. Defaults to .\artifacts\package
echo    TargetDir:      Path to deploy the application to. Defaults to %SYSTEMDRIVE%\Apps
echo.
goto FAILED

:CHECK_ARGS
rem ### Check Arguments #######################################
if not '%1'=='' set PACKAGESOURCE=%1
if not '%2'=='' set TARGETDIRECTORY=%2
if not '%3'=='' goto PRINT_USAGE

:RUN
rem ### Run deployment ########################################

rem ## Find version number which will be installed
FOR /F "usebackq tokens=2" %%i IN (`%NUGET% list %APPLICATION% -Source %PACKAGESOURCE%`) DO SET VERSION=%%i
rem ## Application destination directory
set APPLICATIONDIRECTORY=%TARGETDIRECTORY%\%APPLICATION%.%VERSION%

echo.
echo #####################################################################################################
echo.
echo Running deployment for:
echo     Application:       %APPLICATION%
echo     Package:           %PACKAGESOURCE%
echo     Target Directory:  %APPLICATIONDIRECTORY%
echo     Version:           %VERSION%
echo.
echo #####################################################################################################
echo.

:UNINSTALL
rem ## Nuget won't install a package if it finds the package file is already there
rem ## and won't overwrite files that already exist when installing.
if not exist %APPLICATIONDIRECTORY% goto INSTALL
echo Stopping service
sc.exe stop %SERVICENAME%
timeout 5
echo Removing existing contents of %APPLICATIONDIRECTORY%
rmdir /S /Q %APPLICATIONDIRECTORY%
if errorlevel 1 goto FAILED

:INSTALL
rem ## Install the nuget package to the target directory
echo Installing %APPLICATION% to %APPLICATIONDIRECTORY%
%NUGET% install %APPLICATION% ^
	-Source %PACKAGESOURCE% ^
	-OutputDirectory %TARGETDIRECTORY%
if errorlevel 1 goto FAILED
echo Removing Nupkg file
del /f /q "%APPLICATIONDIRECTORY%\%APPLICATION%.%VERSION%.nupkg" 

rem ## Octopus Deploy script conventions
set PS_PREDEPLOY=%APPLICATIONDIRECTORY%\PreDeploy.ps1
set PS_DEPLOY=%APPLICATIONDIRECTORY%\Deploy.ps1
set PS_POSTDEPLOY=%APPLICATIONDIRECTORY%\PostDeploy.ps1

rem ## Execute Deploy PS scripts with appropriate environment variables
set ps_variables=

:PRE_DEPLOY
rem ## Execute Octopus PreDeploy script
if not exist %PS_PREDEPLOY% goto DEPLOY
powershell ^
	-NonInteractive ^
	-NoProfile ^
	-ExecutionPolicy unrestricted ^
	-command "& { %ps_variables% %PS_PREDEPLOY%; exit $LastExitCode }"
if errorlevel 1 goto FAILED

:DEPLOY
rem ## Execute Octopus Deploy script
if not exist %PS_DEPLOY% goto POST_DEPLOY
powershell ^
	-NonInteractive ^
	-NoProfile ^
	-ExecutionPolicy unrestricted ^
	-command "& { %ps_variables% %PS_DEPLOY%; exit $LastExitCode }"
if errorlevel 1 goto FAILED

:POST_DEPLOY
rem ## Execute Octopus PostDeploy script
if not exist %PS_POSTDEPLOY% goto COMPLETE
powershell ^
	-NonInteractive ^
	-NoProfile ^
	-ExecutionPolicy unrestricted ^
	-command "& { %ps_variables% %PS_POSTDEPLOY%; exit $LastExitCode }"
if errorlevel 1 goto FAILED

:COMPLETE

:EXIT
endlocal
exit /b 0

:FAILED
echo.
echo Deployment of %APPLICATION% failed.
echo.
endlocal
exit /b 1
