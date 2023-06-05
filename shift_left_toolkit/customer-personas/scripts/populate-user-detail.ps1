if ($env:STOP_SCRIPT -eq $true) { Write-Error -Message 'CHECK .GITHUB-WORKFLOW-TMP/USERPERSONA-LOGS.TXT FOR DETAILS ON SCRIPT CANCELLING' -ErrorAction Stop }

$path_to_project_directory = (Get-Location).path
Import-Module -Force "$path_to_project_directory/shift_left_toolkit/customer-personas/scripts/user-persona-automation.psm1"
Import-Module -Force "$path_to_project_directory/shift_left_toolkit/customer-personas/scripts/0-process-user-persona-json.psm1"
Import-Module -Force "$path_to_project_directory/shift_left_toolkit/customer-personas/scripts/1-deactivate-existing-users.psm1"

$stopwatch =  [system.diagnostics.stopwatch]::StartNew()

$names_of_current_directory_child_items = Get-ChildItem | foreach name
$current_directory_contains_shift_left_toolkit_directory = $names_of_current_directory_child_items -contains 'shift_left_toolkit'

if ($current_directory_contains_shift_left_toolkit_directory) {
    . shift_left_toolkit/customer-personas/environment-variables-setup/initialize-environment-variables.ps1
 
    [array]$user_personas = get_user_names_from_populate_user_detailjson -path_to_project_directory $path_to_project_directory  
    [array]$usernames_from_populate_user_detail = $user_personas | foreach username
    $usernames = [system.collections.generic.list[string]]::new()
    foreach ($username in $usernames_from_populate_user_detail) {
        $trimmed_username = $username.Trim()
        if (-not ([string]::IsNullOrEmpty($username.Trim()))) {
            $usernames.Add($trimmed_username)
        }
    }

    Write-Host "USERNAME(S) ARE:"
    Write-Host $usernames

    function update_user_person_map_with_user_info {
        param($user_records)

        $map_username_to_user_persona_info = @{}

        foreach ($user_record in $user_records) {

            $user_persona_info = [PSCustomObject]@{
                'username' = $user_record.Username;
                'active' = $user_record.IsActive;
                'email_address' = $user_record.Email;
                'firstname' = $user_record.FirstName;
                'lastname' = $user_record.LastName;
                'profilename' = $user_record.Profile.Name;
                'permset_api_names' = [system.collections.generic.list[string]]::new();
                'group_api_names' = [system.collections.generic.list[string]]::new();
                'queue_api_names' = [system.collections.generic.list[string]]::new();
                'login_url' = '';
            }

            $map_username_to_user_persona_info.Add($user_record.Id, $user_persona_info) | Out-Null
        }

        $map_username_to_user_persona_info

    }
    function update_map_username_to_user_persona_info_with_groups_and_queues_records {
        param($map_username_to_user_persona_info, $groups_and_queues_records)

        foreach ($group_or_queue_member_assignment in $groups_and_queues_records ) {
            if ($group_or_queue_member_assignment.Group.Type -eq 'Regular') {
                $map_username_to_user_persona_info[$group_or_queue_member_assignment.UserOrGroupId].group_api_names.Add($group_or_queue_member_assignment.Group.DeveloperName) | Out-Null
            } else {
                $map_username_to_user_persona_info[$group_or_queue_member_assignment.UserOrGroupId].queue_api_names.Add($group_or_queue_member_assignment.Group.DeveloperName) | Out-Null
            }
        }

        $map_username_to_user_persona_info
    }

    function update_map_username_to_user_persona_info_with_permsetassignmentrecords_names {
        param($map_username_to_user_persona_info, $permsetassignment_records)

        foreach ($permsetassignment in $permsetassignment_records ) {
            # ensure permsetassignment for profile isn't captured
            if ([string]::IsNullOrEmpty($permsetassignment.PermissionSet.ProfileId)) {
                $map_username_to_user_persona_info[$permsetassignment.Assignee.Id].permset_api_names.Add($permsetassignment.PermissionSet.Name) | Out-Null
            }
        }

        $map_username_to_user_persona_info
    }


    $map_username_to_user_persona_info = @{}

    $user_query_response_json = get_users_from_org $usernames
    $user_query_response = $user_query_response_json | ConvertFrom-Json
    [array]$user_records = $user_query_response.result.records 

    $map_username_to_user_persona_info = update_user_person_map_with_user_info $user_records

    $user_ids = $user_records | foreach {
        $_.Id
    }

    $permsetassignment_records = get_permsetassignments_from_user_ids $user_ids
    $map_username_to_user_persona_info = update_map_username_to_user_persona_info_with_permsetassignmentrecords_names $map_username_to_user_persona_info $permsetassignment_records 

    $groups_and_queues_records = get_groups_and_queues_from_user_ids $user_ids
    $map_username_to_user_persona_info  = update_map_username_to_user_persona_info_with_groups_and_queues_records $map_username_to_user_persona_info $groups_and_queues_records 
    write_user_personas_to_populate_user_detail_file -user_personas $map_username_to_user_persona_info.values -path_to_project_directory $path_to_project_directory | Out-Null

} else {
    Write-Error -Message "ERROR: THIS SCRIPT MUST RUN FROM va-salesforce-dojo DIRECTORY CONTAINING shift_left_toolkit DIRECTORY" -ErrorAction Stop
}

$elapsed_seconds = $stopwatch.ElapsedMilliseconds/1000
Write-Host "User Personas Population completed in $elapsed_seconds seconds"