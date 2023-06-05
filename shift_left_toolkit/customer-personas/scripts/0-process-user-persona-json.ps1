if ($env:STOP_SCRIPT -eq $true) { Write-Error -Message 'CHECK .GITHUB-WORKFLOW-TMP/USERPERSONA-LOGS.TXT FOR DETAILS ON SCRIPT CANCELLING' -ErrorAction Stop }

Write-Host "[[ 0 START ]]"

$path_to_project_directory = (Get-Location).path
$path_to_github_workflow_tmp_directory = "$path_to_project_directory/.github-workflow-tmp"
Import-Module -Force "$path_to_project_directory/shift_left_toolkit/customer-personas/scripts/user-persona-automation.psm1"
Import-Module -Force "$path_to_project_directory/shift_left_toolkit/customer-personas/scripts/0-process-user-persona-json.psm1"
Import-Module -Force "$path_to_project_directory/shift_left_toolkit/customer-personas/scripts/1-deactivate-existing-users.psm1"

[array]$user_personas = get_user_personas_from_user_detailjson -path_to_project_directory $path_to_project_directory  
[array]$usernames = $user_personas | foreach username
Write-Host "USERNAMES IS"
Write-Host $usernames

[array]$user_personas = reset_user_persona_usernames -user_personas $user_personas
[array]$user_personas = update_active_user_persona_usernames -user_personas $user_personas -org_instance_url $env:ORG_INSTANCE_URL
write_user_personas_to_user_detail_file -user_personas $user_personas -path_to_project_directory $path_to_project_directory

$org_isntance_url_usernames = $user_personas | foreach username
$org_instance_url_usernames_and_original_usernames = ($usernames + $org_isntance_url_usernames)
deactivate_existing_users -usernames $org_instance_url_usernames_and_original_usernames

[array]$active_user_personas = get_active_user_personas_from_user_detailjson -path_to_project_directory $path_to_project_directory    

Write-Host "`$active_user_personas is"
Write-Host $active_user_personas

$map_username_to_user_info = @{}
$map_username_to_permset_info = @{}
$map_username_to_queue_info = @{}
$map_username_to_group_info = @{}
$map_username_to_profile_info = @{}
$map_username_to_role_info = @{}

$all_permission_set_api_names = [system.collections.generic.list[string]]::new()
$all_queue_api_names = [system.collections.generic.list[string]]::new()
$all_group_api_names = [system.collections.generic.list[string]]::new()
$all_profile_names = [system.collections.generic.list[string]]::new()
$all_role_api_names = [system.collections.generic.list[string]]::new()


foreach ($user_persona in $active_user_personas) {
    $username = $user_persona.'username'

    $profile_name = $user_persona.'profilename'
    $all_profile_names.Add($profile_name) | Out-Null
    $map_username_to_profile_info = add_username_for_map_username_to_profile_info -map_username_to_profile_info $map_username_to_profile_info -profilename $profile_name -username $username

    $permset_names = [system.collections.generic.list[string]]$user_persona.'permset_api_names'
    $all_permission_set_api_names.AddRange($permset_names) | Out-Null
    $map_username_to_permset_info = add_username_for_map_username_to_permset_info -map_username_to_permset_info $map_username_to_permset_info -permset_api_names $permset_names -username $username
    
    $queue_names = [system.collections.generic.list[string]]$user_persona.'queue_api_names'
    $all_queue_api_names.AddRange($queue_names) | Out-Null
    $map_username_to_queue_info = add_username_for_map_username_to_queue_info -map_username_to_queue_info $map_username_to_queue_info -queue_api_names $queue_names -username $username
    
    $group_names = [system.collections.generic.list[string]]$user_persona.'group_api_names'
    $all_group_api_names.AddRange($group_names) | Out-Null
    $map_username_to_group_info = add_username_for_map_username_to_group_info -map_username_to_group_info $map_username_to_group_info -group_api_names $group_names -username $username
    
    $role_api_name = $user_persona.'role_api_name'
    $all_role_api_names.Add($role_api_name) | Out-Null
    $map_username_to_role_info = add_username_for_map_username_to_role_info -map_username_to_role_info $map_username_to_role_info -role_api_name $role_api_name -username $username

}

#REMOVE DUPLICATES AND CAST BACK AS LIST

$all_profile_names = [system.collections.generic.list[string]](remove_duplicates_from_list_of_strings -list_of_strings $all_profile_names)
$profile_records = get_profiles_from_api_names -profile_names $all_profile_names

$all_permission_set_api_names = [system.collections.generic.list[string]](remove_duplicates_from_list_of_strings -list_of_strings $all_permission_set_api_names)
$permset_records = get_permsets_from_api_names -permission_set_names $all_permission_set_api_names 

$all_queue_api_names = [system.collections.generic.list[string]](remove_duplicates_from_list_of_strings -list_of_strings $all_queue_api_names)
$queue_records = get_queues_from_api_names -queue_api_names $all_queue_api_names
`
$all_group_api_names = [system.collections.generic.list[string]](remove_duplicates_from_list_of_strings -list_of_strings $all_group_api_names)
$group_records = get_groups_from_api_names -group_api_names $all_group_api_names

$all_role_api_names = [system.collections.generic.list[string]](remove_duplicates_from_list_of_strings -list_of_strings $all_role_api_names)
$role_records = get_roles_from_api_names -role_api_names $all_role_api_names

$check_for_missing_records_args = @{
    'all_profile_names'             =  $all_profile_names;
    'profile_records'               =  $profile_records;
    'all_permission_set_api_names'  =  $all_permission_set_api_names;
    'permset_records'               =  $permset_records;
    'all_queue_api_names'           =  $all_queue_api_names;
    'queue_records'                 =  $queue_records;
    'all_group_api_names'           =  $all_group_api_names;
    'group_records'                 =  $group_records;
    'all_role_api_names'            =  $all_role_api_names;
    'role_records'                  =  $role_records;
}
check_for_missing_records @check_for_missing_records_args

$active_user_personas | foreach {
    $user_persona = $_
    $username = $user_persona.'username'
    $profile_name = $user_persona.'profilename'
    $permset_api_names = $user_persona.'permset_api_names'

    if (USER_DETAIL_CONTAINS_EXPECTED_ITEMS $profile_name $permset_api_names) {
        $map_username_to_profile_info[$username] = build_username_to_profile_info_map -profile_records $profile_records -user_to_profile_info $map_username_to_profile_info[$username]
        $map_username_to_permset_info[$username] = build_username_to_permset_info_map -permset_records $permset_records -user_to_permset_info $map_username_to_permset_info[$username]
        $map_username_to_queue_info[$username] = build_username_to_queue_info_map -queue_records $queue_records -user_to_queue_info $map_username_to_queue_info[$username]
        $map_username_to_group_info[$username] = build_username_to_group_info_map -group_records $group_records -user_to_group_info $map_username_to_group_info[$username]
        $map_username_to_role_info[$username] = build_username_to_role_info_map -role_records $role_records -user_to_role $map_username_to_role_info[$username]
        $map_username_to_user_info[$username] = build_username_to_user_password_info_map 
    }       
}

# idea: replace six map structures with one single map data structure / json indexed by username
#       where the result contains user info, profile info, permset info, group info, and queue info
# e.g. one single file "map username_to_user_config.json" to replace all five existing files
# {
#     "username1": {
#         "user_info": [],
#         "profile": [],
#         "permsets": [],
#         "groups": [],
#         "queues": [],
#         "role" : []
#     }
# }
# the function params can remain the same, but just pass the appropriate indexed values in
$map_username_to_permset_info | ConvertTo-Json | Out-File "$path_to_github_workflow_tmp_directory/map_username_to_permset_info.json"
$map_username_to_queue_info | ConvertTo-Json | Out-File "$path_to_github_workflow_tmp_directory/map_username_to_queue_info.json"
$map_username_to_group_info | ConvertTo-Json | Out-File "$path_to_github_workflow_tmp_directory/map_username_to_group_info.json"
$map_username_to_user_info | ConvertTo-Json | Out-File "$path_to_github_workflow_tmp_directory/map_username_to_user_info.json"
$map_username_to_profile_info | ConvertTo-Json | Out-File "$path_to_github_workflow_tmp_directory/map_username_to_profile_info.json"
$map_username_to_role_info | ConvertTo-Json | Out-File "$path_to_github_workflow_tmp_directory/map_username_to_role_info.json"


Write-Host "[[ 0 END ]]"
