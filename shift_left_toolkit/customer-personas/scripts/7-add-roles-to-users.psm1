
function assign_roles_to_users {
    param($map_username_to_role_info)

    Write-Host "`n[[ ASSIGNING ROLES TO USERS ]]"

    Write-Host "map_username_to_role_info is"
    Write-Host $map_username_to_role_info | ConvertTo-Json

    $role_setup_lines = [system.collections.generic.list[pscustomobject]]::new()
    foreach ($username_to_role_info_map in $map_username_to_role_info.GetEnumerator()) {
        Write-Host $username_to_role_info_map | ConvertTo-Json
        foreach ( $user_role_map in $username_to_role_info_map.value ) {
            $role_id = $user_role_map.role_id
            $user_id = $user_role_map.user_id

            $user_role_assignment = @"
    new User(UserRoleId = '$role_id', Id = '$user_id')
"@
            $role_setup_lines.Add($user_role_assignment) | Out-Null
        }
    }

    if ( $role_setup_lines.count -gt 0 ) {

        $user_role_apex_formatted =  $role_setup_lines -join ",`n`n"

        $user_role_apex_instantiation_lines = @"
List<User> userRoleAssignments = new List<User>{
"@

    $user_role_apex_closing_lines = @"
};

try {
    update userRoleAssignments;
}
catch (Exception e) {
    System.debug('The following exception has occurred: ' + e.getMessage());
}
"@

        $anonymous_apex_assign_roles = $user_role_apex_instantiation_lines + "`n`n" + $user_role_apex_formatted  + "`n`n" +  $user_role_apex_closing_lines  
        Write-Host $anonymous_apex_assign_roles

        $anonymous_apex_file_name = "anonymous_apex_assign_roles.cls"
        New-Item -Path . -Name $anonymous_apex_file_name -ItemType "file" -value $anonymous_apex_assign_roles -Force | Out-Null
        Write-Host "running 'sfdx force:apex:execute -u $($env:ORG_ALIAS) -f $anonymous_apex_file_name' --loglevel ERROR"
        sfdx force:apex:execute -u ($env:ORG_ALIAS) -f $anonymous_apex_file_name --loglevel ERROR --json
        Remove-Item -Force $anonymous_apex_file_name

    }

}