######## Script Overview ############################
## Smoke test the url for the deployed service.
##
##
##
if ($SmokeTestUrl -eq $null) { $SmokeTestUrl = "localhost:8080" }

trap {
    Write-Host "[TRAP] Error occurred during PostDeploy: "
    Write-Host $_
    exit 1
}

# Import dem modules
if ((Get-Module | Where-Object { $_.Name -eq "Shared-Deployment-Tasks" }) -eq $null) { 
    Import-Module (Join-Path -Path (Split-Path -parent $MyInvocation.MyCommand.Definition) `
        -ChildPath "Shared-Deployment-Tasks") `
        -DisableNameChecking `
        -ErrorAction Stop
}

if ($SkipSmokeTest) {
    Write-Warning "Skipping smoke test."
} else {
    @( "http://$SmokeTestUrl" ) | Test-Uri        
}
