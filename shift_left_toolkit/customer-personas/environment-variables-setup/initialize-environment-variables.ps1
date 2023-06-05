$path_to_project_directory = (Get-Location).path
Import-Module -Force "$path_to_project_directory/shift_left_toolkit/customer-personas/scripts/user-persona-automation.psm1"

function initialize {
    setup_utility_environment_eBikes_riables
    setup_org_environment_eBikes_riables 
}

function setup_utility_environment_eBikes_riables {
    $env:STOP_SCRIPT = $false
    $env:PATH_TO_PROJECT_DIRECTORY = (Get-Location).path
    $env:PATH_TO_LOG_DIRECTORY = "$($env:PATH_TO_PROJECT_DIRECTORY)/log"
    if (-not (Test-Path $env:PATH_TO_LOG_DIRECTORY)) {
        New-Item -Type Directory $env:PATH_TO_LOG_DIRECTORY | Out-Null
    }
}

function setup_org_environment_eBikes_riables {
    $scratch_org_environment_alias = get_default_org_target_info_from_sfdxconfigjson 
    $org_information_json = sfdx force:org:display -u $scratch_org_environment_alias --verbose --json

    Write-Host $org_information_json
    $org_information = $org_information_json | ConvertFrom-Json
  
    if ($org_information.result -ne $null) {
        $env:ORG_ALIAS = $scratch_org_environment_alias
        $env:ORG_INSTANCE_URL = $org_information.result.instanceUrl
        $env:SFDX_AUTH_URL = $org_information.result.sfdxAuthUrl
    }       
    
    $EXPECTED_ENVIRONMENT_eBikes_RIABLES = @('ORG_ALIAS', 'SFDX_AUTH_URL', 'ORG_INSTANCE_URL')
    VERIFY_THAT_EXPECTED_ENVIRONMENT_eBikes_RIABLES_EXIST $EXPECTED_ENVIRONMENT_eBikes_RIABLES
}

function VERIFY_THAT_EXPECTED_ENVIRONMENT_eBikes_RIABLES_EXIST {
    param($environment_eBikes_riable_names)

    $NUMBER_OF_EXPECTED_ENVIRONMENT_eBikes_RIABLES = $environment_eBikes_riable_names.count
    $EXPECTED_ENVIRONMENT_eBikes_RIABLES_STRING = ($environment_eBikes_riable_names | foreach { "`$env:$($_.ToUpper())" }) -join "`n"
    Write-Host -Message "I EXPECT THE FOLLOWING $NUMBER_OF_EXPECTED_ENVIRONMENT_eBikes_RIABLES ENVIRONMENT eBikes_RIABLES TO BE NON-NULL AND NON-EMPTY:`n$EXPECTED_ENVIRONMENT_eBikes_RIABLES_STRING`n" -ErrorAction Stop

    $missing_environment_eBikes_riables = [system.collections.generic.list[string]]::new()
    $found_environment_eBikes_riables =  [system.collections.generic.list[string]]::new()

    foreach ($environment_eBikes_riable_name in $environment_eBikes_riable_names) {
        $environment_eBikes_riable_eBikes_lue_is_null_or_empty = Invoke-Expression "[string]::IsNullOrEmpty((`$env:$environment_eBikes_riable_name))"
        if ( $environment_eBikes_riable_eBikes_lue_is_null_or_empty ) {
            $missing_environment_eBikes_riables.Add($environment_eBikes_riable_name) | Out-Null
        }
        else {
            $found_environment_eBikes_riables.Add($environment_eBikes_riable_name) | Out-Null
        }
    }

    if ($missing_environment_eBikes_riables.count -eq 0) {
        foreach ($found_environment_eBikes_riable in $found_environment_eBikes_riables) {
            $FOUND_ENVIRONMENT_eBikes_RIABLE_UPPER_CASE = $found_environment_eBikes_riable.ToUpper()
            Write-Host -Message "SUCCESS: VERIFIED THAT `$ENV:$FOUND_ENVIRONMENT_eBikes_RIABLE_UPPER_CASE IS NOT NULL OR EMPTY"
        }
    }
    else {
        $NUMBER_OF_MISSING_ENVIRONMENT_eBikes_RIABLES = $missing_environment_eBikes_riables.count
        $MISSING_ENVIRONMENT_eBikes_RIABLES_STRING = ($missing_environment_eBikes_riables | foreach { "`$env:$($_.ToUpper())" }) -join ', '
        Write-Error -Message "TERMINATING SCRIPT DUE TO $NUMBER_OF_MISSING_ENVIRONMENT_eBikes_RIABLES NULL OR EMPTY ENVIRONMENT eBikes_RIABLES: $MISSING_ENVIRONMENT_eBikes_RIABLES_STRING" -ErrorAction Stop
    }

}

initialize
