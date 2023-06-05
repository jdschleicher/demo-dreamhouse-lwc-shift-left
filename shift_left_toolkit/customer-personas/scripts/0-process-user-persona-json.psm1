function add_username_for_map_username_to_permset_info {
    param($map_username_to_permset_info, $permset_api_names, $username)    
    
    foreach ($permset_api_name in $permset_api_names) {

        $permset_user_info =  [PSCustomObject]@{
            'permset_id' = $null;
            'user_id' = $null;
            'permset_name' = $permset_api_name;
        }

        if ($map_username_to_permset_info.ContainsKey($username)) {
            $map_username_to_permset_info[$username].Add($permset_user_info) | Out-Null
        } else {
            $user_info_list = [system.collections.generic.list[pscustomobject]]::new()
            $user_info_list.Add($permset_user_info) | Out-Null
            $map_username_to_permset_info.Add($username, $user_info_list) | Out-Null
        }

    }

    $map_username_to_permset_info

}

function add_username_for_map_username_to_profile_info {
    param($map_username_to_profile_info, $profilename, $username)    
    
    $profile_user_info =  [PSCustomObject]@{
        'profile_id' = $null;
        'profilename' = $profilename;
    }

    $user_info_list = [system.collections.generic.list[pscustomobject]]::new()
    $user_info_list.Add($profile_user_info) | Out-Null
    $map_username_to_profile_info.Add($username, $user_info_list) | Out-Null

    $map_username_to_profile_info

}

function add_username_for_map_username_to_queue_info {
    param($map_username_to_queue_info, $queue_api_names, $username)    
    
    foreach ($queue_name in $queue_api_names) {

        $queue_user_info =  [PSCustomObject]@{
            'queue_id' = $null;
            'user_id' = $null;
            'queue_name' = $queue_name;
        }

        if ($map_username_to_queue_info.ContainsKey($username)) {
            $map_username_to_queue_info[$username].Add($queue_user_info) | Out-Null
        } else {
            $user_info_list = [system.collections.generic.list[pscustomobject]]::new()
            $user_info_list.Add($queue_user_info) | Out-Null
            $map_username_to_queue_info.Add($username, $user_info_list) | Out-Null
        } 

    }

    $map_username_to_queue_info

}

function add_username_for_map_username_to_group_info {
    param($map_username_to_group_info, $group_api_names, $username)    
    
    foreach ($group_name in $group_api_names) {

        $group_user_info =  [PSCustomObject]@{
            'group_id' = $null;
            'user_id' = $null;
            'group_name' = $group_name;
        }

        if ($map_username_to_group_info.ContainsKey($username)) {
            $map_username_to_group_info[$username].Add($group_user_info) | Out-Null
        } else {
            $user_info_list = [system.collections.generic.list[pscustomobject]]::new()
            $user_info_list.Add($group_user_info) | Out-Null
            $map_username_to_group_info.Add($username, $user_info_list) | Out-Null
        }

    }

    $map_username_to_group_info

}

function add_username_for_map_username_to_role_info {
    param($map_username_to_role_info, $role_api_name, $username)    

    $role_user_info =  [PSCustomObject]@{
        'role_id' = $null;
        'user_id' = $null;
        'role_api_name' = $role_api_name;
    }

    $user_info_list = [system.collections.generic.list[pscustomobject]]::new()
    $user_info_list.Add($role_user_info) | Out-Null
    $map_username_to_role_info.Add($username, $user_info_list) | Out-Null
   
    $map_username_to_role_info

}

function remove_duplicates_from_list_of_strings {
    param($list_of_strings)
    $unique_list = $list_of_strings | Select-Object -Unique
    $unique_list
}


function build_username_to_permset_info_map {
    param($permset_records, $user_to_permset_info)

    foreach ($permset in $permset_records) {

        foreach ($user_permset_info_object in $user_to_permset_info ) {
            if ($user_permset_info_object.'permset_name' -eq $permset.'name') {
                $user_permset_info_object.permset_id = $permset.'id'
            }
        } 
    }

    $user_to_permset_info

}

function build_username_to_profile_info_map {
    param($profile_records, $user_to_profile_info)

    foreach ($profile in $profile_records) {

        foreach ($user_profile_info_object in $user_to_profile_info ) {
            if ($user_profile_info_object.'profilename' -eq $profile.'name') {
                $user_profile_info_object.profile_id = $profile.'id'
            }
        } 
    }

    $user_to_profile_info

}

function build_username_to_queue_info_map {
    param($queue_records, $user_to_queue_info)

    foreach ($queue in $queue_records) {

        foreach ($user_queue_info_object in $user_to_queue_info ) {
            if ($user_queue_info_object.'queue_name' -eq $queue.'DeveloperName') {
                $user_queue_info_object.queue_id = $queue.'id'
            }
        } 
    }

    $user_to_queue_info
}

function build_username_to_group_info_map {
    param($group_records, $user_to_group_info)

    foreach ($group in $group_records) {

        foreach ($user_group_info_object in $user_to_group_info ) {
            if ($user_group_info_object.'group_name' -eq $group.'DeveloperName') {
                $user_group_info_object.group_id = $group.'id'
            }
        } 
    }

    $user_to_group_info
}

function build_username_to_role_info_map {
    param($role_records, $user_to_role_info)

    foreach ($role in $role_records) {

        foreach ($user_role_info_object in $user_to_role_info ) {
            if ($user_role_info_object.'role_api_name' -eq $role.'DeveloperName') {
                $user_role_info_object.role_id = $role.'id'
            }
        } 
    }

    $user_to_role_info
}


function build_username_to_user_password_info_map {
    $todays_date = Get-Date -Uformat "%m%d%Y"
    $generated_password = generate_salesforce_password_range 8 15
    $password = ($todays_date + $generated_password)
    $user_password_info = [PSCustomObject]@{
        'user_id' = $null;
        'password' = $password;
    }

    $user_password_info
}

function reset_inactive_persona {
    param($user)
}
