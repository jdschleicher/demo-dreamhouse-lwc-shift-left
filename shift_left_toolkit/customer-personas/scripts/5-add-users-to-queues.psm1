function assign_user_queues {
    param($map_username_to_queue_info)

    Write-Host "`n[[ ASSIGNING USER QUEUES ]]"

    Write-Host "map_username_to_queue_info is"
    Write-Host $map_username_to_queue_info | ConvertTo-Json

    $queue_member_setup_lines = [system.collections.generic.list[pscustomobject]]::new()
    foreach ($username_to_queue_info_map in $map_username_to_queue_info.GetEnumerator()) {
        Write-Host $username_to_queue_info_map | ConvertTo-Json
        foreach ( $user_queue_map in $username_to_queue_info_map.value ) {
            $queue_id = $user_queue_map.queue_id
            $user_id = $user_queue_map.user_id

            $queue_assignment = @"
    new GroupMember(GroupId = '$queue_id', UserOrGroupId = '$user_id')
"@
            $queue_member_setup_lines.Add($queue_assignment) | Out-Null
        }

    }


    if ( $queue_member_setup_lines.count -gt 0 ) {

        $queue_member_apex_formatted =  $queue_member_setup_lines -join ",`n`n"

        $queue_member_apex_instantiation_lines = @"
List<GroupMember> groupMemberAssignments = new List<GroupMember>{
"@

    $queue_member_apex_closing_lines = @"
};

try {
    insert groupMemberAssignments;
}
catch (Exception e) {
    System.debug('The following exception has occurred: ' + e.getMessage());
}
"@

        $anonymous_apex_assign_queues = $queue_member_apex_instantiation_lines + "`n`n" + $queue_member_apex_formatted  + "`n`n" +  $queue_member_apex_closing_lines  
        Write-Host $anonymous_apex_assign_queues

        $anonymous_apex_file_name = "anonymous_apex_assign_queues.cls"

        New-Item -Path . -Name $anonymous_apex_file_name -ItemType "file" -value $anonymous_apex_assign_queues -Force | Out-Null
        Write-Host "running 'sfdx force:apex:execute -u $($env:ORG_ALIAS) -f $anonymous_apex_file_name' --loglevel ERROR"
        sfdx force:apex:execute -u ($env:ORG_ALIAS) -f $anonymous_apex_file_name --loglevel ERROR --json
        Remove-Item -Force $anonymous_apex_file_name

    }

}