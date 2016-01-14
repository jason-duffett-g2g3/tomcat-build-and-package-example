######## Script Overview ############################
# > Stops and deletes existing Tomcat7 service
# > Sets required CATALINA_HOME environment variable
# > Installs service using service.bat
#

trap {
    Write-Host "[TRAP] Error occurred during Deploy: "
    Write-Host $_
    exit 1
}

## Import dem modules
if ((Get-Module | Where-Object { $_.Name -eq "Shared-Deployment-Tasks" }) -eq $null) { 
    Import-Module (Join-Path -Path (Split-Path -parent $MyInvocation.MyCommand.Definition) `
        -ChildPath "Shared-Deployment-Tasks") `
        -DisableNameChecking `
        -ErrorAction Stop
}

## Test permissions
if (!(Test-AdministratorPrivileges)) {
    Write-Error "This script must be run with elevated administrator privileges. Run the script again logged in as an Administrator or from an elevated shell."
    exit 1
}

## Required Variables
$ServiceName = "Tomcat7"
if ($ServiceIdentity -eq $null) { $ServiceIdentity = "NT AUTHORITY\NetworkService" }
if ($AppRoot -eq $null) { $AppRoot = (Split-Path -parent $MyInvocation.MyCommand.Definition) }

## Show our intentions
Write-Host `
  "Application Deployment for ${ServiceName}: `
     Service Identity:        $ServiceIdentity `
"

# CATALINA_HOME must be set within one cmd.exe, so 
# runservice.bat sets the environment variable then calls Tomcat7\bin\service.bat
$command = "$AppRoot\runservice.bat"

## Remove existing service
if (Get-Service $ServiceName -ErrorAction SilentlyContinue) {
    Write-Host "Removing service '$ServiceName'"
	& $command $AppRoot remove | Write-Host
	if ($LastExitCode) { exit $LastExitCode }
	Write-Host "Waiting for Windows to delete the service..."
	Start-Sleep -s 20
}

if ($OctopusEnvironmentName) {
	Write-Host "Copying server configuration for $OctopusEnvironmentName"
	## log4j.properties to set specifics for CATALINA logging
	Copy-Item "$AppRoot\lib\log4j.$OctopusEnvironmentName.properties" "$AppRoot\lib\log4j.properties" -Force
	## service.bat to set environment locations for logs (stderr, stdout, localhost_access_log, commons-daemon)
	Copy-Item "$AppRoot\bin\service.$OctopusEnvironmentName.bat" "$AppRoot\bin\service.bat" -Force
	## server.xml to set environment specific server options and localhost_access_log logging specifics
	Copy-Item "$AppRoot\conf\server.$OctopusEnvironmentName.xml" "$AppRoot\conf\server.xml" -Force
}

## Install service
Write-Host "Installing service '$ServiceName'"
& $command $AppRoot install | Write-Host
if ($LastExitCode) { exit $LastExitCode }
Start-Sleep -s 5

Write-Host "Setting auto startup and log on as $ServiceIdentity..."
& "sc.exe" config "$ServiceName" start= auto obj= "$ServiceIdentity" | Write-Host

## Remove Java memory limits 
if ($JvmInitialMemoryPoolSizeMB) {
  Write-Host "Setting initial JVM memory pool size (JvmMs): $JvmInitialMemoryPoolSizeMB MB"
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Apache Software Foundation\Procrun 2.0\Tomcat7\Parameters\Java" -Name JvmMs -Value $JvmInitialMemoryPoolSizeMB
} 

if ($JvmMaxMemoryPoolSizeMB) {
  Write-Host "Setting max JVM memory pool size (JvmMx): $JvmMaxMemoryPoolSizeMB MB"
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Apache Software Foundation\Procrun 2.0\Tomcat7\Parameters\Java" -Name JvmMx -Value $JvmMaxMemoryPoolSizeMB
} 

if (!$JvmMaxMemoryPoolSizeMB) {
  Write-Warning "No maximum JVM memory pool size specified. Removing JVM memory limits..."
  Remove-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Apache Software Foundation\Procrun 2.0\Tomcat7\Parameters\Java" -Name JvmMx #Max memory
}

## Start service
if ($DontStartService) {
  Write-Warning "Leaving service in Stopped state."
} else { 
  Write-Host -foregroundcolor green "Starting service '$ServiceName'"
  Start-Service $ServiceName -ErrorAction Stop
  Write-Host "Give it some time to get started..."
  Start-Sleep -s 10
}
