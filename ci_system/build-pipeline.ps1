function getauthurl_by_org_alias {
    param($org_alias)

    $verbose_result_json = sfdx force:org:display -u $org_alias --verbose --json
    $verbose_result = $verbose_result_json | ConvertFrom-Json
    $auth_url = $verbose_result.result.sfdxAuthUrl
    
    $auth_url

}

function create_test_scratch_org_and_update_repository_test_pipeline_with_cicd_test_environment_secrets {
    param($devhub_alias)

    $scratch_org_duration = 30
        
    $orgalias_to_pipeline_environment_github_secrets = @{ 
        "uat" = "AUTH_URL"        
        "prod" = "AUTH_URL"
    }

    foreach ($org_alias in $orgalias_to_pipeline_environment_github_secrets.Keys) {

        $create_scratch_result_json = (sfdx force:org:create --targetdevhubusername $devhub_alias --definitionfile config/project-scratch-def.json --setalias $org_alias --durationdays $scratch_org_duration --setdefaultusername --loglevel trace --json )
        $create_scratch_result = $create_scratch_result_json | ConvertFrom-Json
    
        $pipeline_auth_url = $null
        if ($create_scratch_result.status -eq 0 ) {
            $pipeline_auth_url = getauthurl_by_org_alias -org_alias $org_alias
            $install_package_dependencies_result_json = $( sfdx texei:package:dependencies:install -u $org_alias -v $devhub_alias --noprompt -w 120 --json)
        }
    
        Write-Host "INSTALL DEPENDENCIES RESULT: $install_package_dependencies_result_json"
    
        if ( $null -ne $pipeline_auth_url ) {

            gh secret set $($orgalias_to_pipeline_environment_github_secrets["$org_alias"]) -b "$pipeline_auth_url" --env $org_alias

        } else {
            throw "Auth URL missing for : $org_alias"
        }

    }



}

create_test_scratch_org_and_update_repository_test_pipeline_with_cicd_test_environment_secrets -devhub_alias "devhub"