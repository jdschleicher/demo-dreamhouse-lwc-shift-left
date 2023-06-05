function set_user_passwords {
    param($map_username_to_user_info, $path_to_project_directory)

    Write-Host "`n[[ UPDATING USER PASSWORDS ]]"

    $anon_apex_lines = [system.collections.generic.list[pscustomobject]]::new()

    foreach ($username_to_user_info_map in $map_username_to_user_info.GetEnumerator()) {
        $user_id = $username_to_user_info_map.value.user_id
        $generated_password = $username_to_user_info_map.value.password
        $apex = @"
    System.setPassword('$user_id', '$generated_password'); 
"@
        $anon_apex_lines.Add($apex) | Out-Null
    }

    $anonymous_apex_pw_update = $anon_apex_lines -join "`n`n"

    $anonymous_apex_file_name = "anonymous_apex_pw_update.cls"
    New-Item -Path . -Name $anonymous_apex_file_name -ItemType "file" -value $anonymous_apex_pw_update -Force | Out-Null

    sfdx force:apex:execute -u ($env:ORG_ALIAS) -f $anonymous_apex_file_name
    Remove-Item -Force $anonymous_apex_file_name

    #CREATE LOGIN URLS FOR NEWLY CREATED SALESFORCE USERS
    $instance_url = ($env:ORG_INSTANCE_URL)
    [array]$user_personas = get_user_personas_from_user_detailjson -path_to_project_directory $path_to_project_directory

    foreach ( $user_persona in $user_personas) {
        $username = $user_persona.'username'
        if ($map_username_to_user_info.keys -contains $username) {
            $password = $map_username_to_user_info[$username].password
            $login_url = "$($instance_url)?un=$username&pw=$password"
            $user_persona.'login_url' = $login_url
        } else {
            $user_persona.'login_url' = ""
        }
    }

    write_user_personas_to_user_detail_file -user_personas $user_personas -path_to_project_directory $path_to_project_directory

}