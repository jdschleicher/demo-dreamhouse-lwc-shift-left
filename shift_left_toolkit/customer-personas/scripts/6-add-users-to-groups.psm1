
function assign_user_groups {
    param($map_username_to_group_info)

    Write-Host "`n[[ ASSIGNING USER GROUPS ]]"

    Write-Host "map_username_to_group_info is"
    Write-Host $map_username_to_group_info | ConvertTo-Json

    $group_member_setup_lines = [system.collections.generic.list[pscustomobject]]::new()
    foreach ($username_to_group_info_map in $map_username_to_group_info.GetEnumerator()) {
        Write-Host $username_to_group_info_map | ConvertTo-Json
        foreach ( $user_group_map in $username_to_group_info_map.value ) {
            $group_id = $user_group_map.group_id
            $user_id = $user_group_map.user_id

            $group_assignment = @"
        new GroupMember(GroupId = '$group_id', UserOrGroupId = '$user_id')
"@
            $group_member_setup_lines.Add($group_assignment) | Out-Null
        }
    }

    if ( $group_member_setup_lines.count -gt 0 ) {


        $group_member_apex_formatted =  $group_member_setup_lines -join ",`n`n"

        $group_member_apex_instantiation_lines = @"
List<GroupMember> groupMemberAssignments = new List<GroupMember>{
"@

    $group_member_apex_closing_lines = @"
};

try {
    insert groupMemberAssignments;
}
catch (Exception e) {
    System.debug('The following exception has occurred: ' + e.getMessage());
}
"@

        $anonymous_apex_assign_groups = $group_member_apex_instantiation_lines + "`n`n" + $group_member_apex_formatted  + "`n`n" +  $group_member_apex_closing_lines  
        Write-Host $anonymous_apex_assign_groups

        $anonymous_apex_file_name = "anonymous_apex_assign_groups.cls"
        # Below lines used for powershell 7
        # New-Item -Type File $anonymous_apex_file_name | Out-Null
        # $anonymous_apex_assign_queues | Out-File $anonymous_apex_file_name
        New-Item -Path . -Name $anonymous_apex_file_name -ItemType "file" -value $anonymous_apex_assign_groups -Force | Out-Null
        Write-Host "running 'sfdx force:apex:execute -u $($env:ORG_ALIAS) -f $anonymous_apex_file_name' --loglevel ERROR"
        sfdx force:apex:execute -u ($env:ORG_ALIAS) -f $anonymous_apex_file_name --loglevel ERROR --json
        Remove-Item -Force $anonymous_apex_file_name

    }

}