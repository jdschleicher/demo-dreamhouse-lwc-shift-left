function assign_user_permsets {
    param($map_username_to_permset_info)

    Write-Host "`n[[ ASSIGNING USER PERMSETS ]]"

    Write-Host "map_username_to_permset_info is"
    Write-Host $map_username_to_permset_info | ConvertTo-Json

    $permset_assignment_setup_lines = [system.collections.generic.list[pscustomobject]]::new()
    foreach ($username_to_permset_info_map in $map_username_to_permset_info.GetEnumerator()) {
        Write-Host $username_to_permset_info_map | ConvertTo-Json
        foreach ( $user_permset_map in $username_to_permset_info_map.value ) {
            $permset_id = $user_permset_map.permset_id
            $user_id = $user_permset_map.user_id

            $permset_assignment = @"
    new PermissionSetAssignment(PermissionSetId = '$permset_id', AssigneeId = '$user_id')
"@
            $permset_assignment_setup_lines.Add($permset_assignment) | Out-Null
        }
    }

    if ( $permset_assignment_setup_lines.count -gt 0 ) {

        $permset_assignment_apex_formatted =  $permset_assignment_setup_lines -join ",`n`n"

        $permset_apex_instantiation_lines = @"
List<PermissionSetAssignment> permissionSetAssignments = new List<PermissionSetAssignment>{
"@

    $permset_apex_closing_lines = @"
};

try {
    insert permissionSetAssignments;
}
catch (Exception e) {
    System.debug('The following exception has occurred: ' + e.getMessage());
}
"@

        $anonymous_apex_assign_permsets = $permset_apex_instantiation_lines + "`n`n" + $permset_assignment_apex_formatted  + "`n`n" +  $permset_apex_closing_lines  
        Write-Host $anonymous_apex_assign_permsets

        $anonymous_apex_file_name = "anonymous_apex_assign_permsets.cls"
        # Below lines used for powershell 7
        # New-Item -Type File $anonymous_apex_file_name | Out-Null
        # $anonymous_apex_assign_permsets | Out-File $anonymous_apex_file_name
        New-Item -Path . -Name $anonymous_apex_file_name -ItemType "file" -value $anonymous_apex_assign_permsets -Force | Out-Null

        Write-Host "running 'sfdx force:apex:execute -u $($env:ORG_ALIAS) -f $anonymous_apex_file_name' --loglevel ERROR"
        sfdx force:apex:execute -u ($env:ORG_ALIAS) -f $anonymous_apex_file_name --loglevel ERROR --json

        Remove-Item -Force $anonymous_apex_file_name

    }

}