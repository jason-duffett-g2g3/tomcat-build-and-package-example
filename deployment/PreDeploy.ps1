######## Script Overview ############################
## Fails if Java JRE 1.6+ is not installed on server

trap {
    Write-Host "[TRAP] Error occurred during PreDeploy: "
    Write-Host $_
    exit 1
}

function Get-JavaHome ($Version) {
	$regKey = "HKLM:\Software\JavaSoft\Java Runtime Environment\$Version"
	$regEntry = "JavaHome"
	$setting = Get-ItemProperty $regKey $regEntry -ErrorAction SilentlyContinue
	if (($setting -eq $null) -or ($setting.Length -eq 0)) {
		return $null
	}
	return $setting.JavaHome
}

Write-Host "Checking for Java JRE 1.7..."
$javaHome = Get-JavaHome "1.7"
if ($javaHome -eq $null) {
	Write-Host "Checking for Java JRE 1.6..."
	$javaHome = Get-JavaHome "1.6"
}
if ($javaHome -eq $null) {
	throw "Java JRE 1.6 or later is not installed.  This needs to be installed before Solr can be deployed."
}

Write-Host -foregroundcolor green "Java JRE found at $javaHome."
