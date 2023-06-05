$path_to_project_directory = (Get-Location).path

function allElementsNotNullOrEmpty {
    param([string[]]$list_of_strings)
    if ($null -ne $list_of_strings) {
        $null_or_empty_elements = $list_of_strings | foreach { if([string]::IsNullOrEmpty($_)){ $true } }
        $null_or_empty_elements.count -eq 0
    }
    else {
        Write-Error -Message 'ERROR: $LIST_OF_STRINGS MUST NOT BE NULL' -ErrorAction STOP
    }
}

function get_user_personas_from_user_detailjson {
    param($path_to_project_directory)
    
    # this is unrelated and should probably be moved elsewhere
    $path_to_github_workflow_tmp_directory = "$path_to_project_directory/.github-workflow-tmp"
    if (-not (Test-Path $path_to_github_workflow_tmp_directory)) {
        New-Item -Type Directory $path_to_github_workflow_tmp_directory | Out-Null
    }

    $path_to_user_detail_json = "$path_to_project_directory/shift_left_toolkit/customer-personas/persona-detail.json"

    $path_to_user_detail_json_does_exist = Test-Path $path_to_user_detail_json
    if (-not $path_to_user_detail_json_does_exist) {
        Write-Error -Message "ERROR: PATH '$path_to_user_detail_json' COULD NOT BE FOUND BUT MUST EXIST"  -ErrorAction Stop
    }

    $user_personas_json = Get-Content -Raw $path_to_user_detail_json
    $user_personas = $user_personas_json | ConvertFrom-Json

    Write-Host ($user_personas | ConvertTo-Json)
    Write-Host "`$user_personas.count() is $($user_personas.count)"

    $user_personas
}

function get_user_names_from_populate_user_detailjson {
    param($path_to_project_directory)
    
    # this is unrelated and should probably be moved elsewhere
    $path_to_github_workflow_tmp_directory = "$path_to_project_directory/.github-workflow-tmp"
    if (-not (Test-Path $path_to_github_workflow_tmp_directory)) {
        New-Item -Type Directory $path_to_github_workflow_tmp_directory | Out-Null
    }

    $path_to_user_detail_json = "$path_to_project_directory/shift_left_toolkit/customer-personas/populate-persona-detail.json"

    $path_to_user_detail_json_does_exist = Test-Path $path_to_user_detail_json
    if (-not $path_to_user_detail_json_does_exist) {
        Write-Error -Message "ERROR: PATH '$path_to_user_detail_json' COULD NOT BE FOUND BUT MUST EXIST"  -ErrorAction Stop
    }

    $user_personas_json = Get-Content -Raw $path_to_user_detail_json
    $user_personas = $user_personas_json | ConvertFrom-Json

    Write-Host ($user_personas | ConvertTo-Json)
    Write-Host "`$user_personas.count() is $($user_personas.count)"

    $user_personas
}
function get_active_user_personas_from_user_detailjson {
    param($path_to_project_directory)
    [array]$user_personas = get_user_personas_from_user_detailjson -path_to_project_directory $path_to_project_directory    
    [array]$active_user_personas = $user_personas | where active -eq $true
    $active_user_personas
}

function get_inactive_user_personas_from_user_detailjson {
    param($path_to_project_directory)
    [array]$user_personas = get_user_personas_from_user_detailjson -path_to_project_directory $path_to_project_directory    
    [array]$active_user_personas = $user_personas | where { ($null -eq $_.active) -or ($_.active -ne 'true') }
    $active_user_personas
}

function write_user_personas_to_user_detail_file {
    param($user_personas, $path_to_project_directory)

    $path_to_user_detail_json = "$path_to_project_directory/shift_left_toolkit/customer-personas/persona-detail.json"

    $path_to_user_detail_json_does_exist = Test-Path $path_to_user_detail_json
    if (-not $path_to_user_detail_json_does_exist) {
        Write-Error -Message "ERROR: PATH '$path_to_user_detail_json' COULD NOT BE FOUND BUT MUST EXIST"  -ErrorAction Stop
    }
    
    $user_personas_json = ConvertTo-Json -InputObject $user_personas
    $user_personas_json = $user_personas_json.Replace("\u0026", "&") 
    Write-Host "write_user_personas_to_user_detail_file: writing `$user_personas_json to file:"
    Write-Host $user_personas_json
    Set-Content -Path $path_to_user_detail_json -eBikes_lue $user_personas_json 
}

function write_user_personas_to_populate_user_detail_file {
    param($user_personas, $path_to_project_directory)

    $path_to_populate_user_detail_json = "$path_to_project_directory/shift_left_toolkit/customer-personas/populate-persona-detail.json"

    $path_to_user_detail_json_does_exist = Test-Path $path_to_populate_user_detail_json
    if (-not $path_to_user_detail_json_does_exist) {
        Write-Error -Message "ERROR: PATH '$path_to_populate_user_detail_json' COULD NOT BE FOUND BUT MUST EXIST"  -ErrorAction Stop
    }
    
    $user_personas_json = ConvertTo-Json -InputObject $user_personas
    $user_personas_json = $user_personas_json.Replace("\u0026", "&") 
    Write-Host "write_user_personas_to_user_detail_file: writing `$user_personas_json to file:"
    Write-Host $user_personas_json
    Set-Content -Path $path_to_populate_user_detail_json -eBikes_lue $user_personas_json 
}

function reset_user_persona_usernames {
    param($user_personas)

    # remove org name labels from usernames
    $user_personas = foreach ($user_persona in $user_personas) {
        if (username_has_org_name_appended ($user_persona.username)) {
            $user_persona.username = get_original_username_from_username_org_name_string ($user_persona.username)
        }
        $user_persona
    }

    $user_personas
}

function update_active_user_persona_usernames {
    param($user_personas, $org_instance_url)

    # define org_name for use in updated usernames
    $org_name = get_org_name_from_instance_url $org_instance_url

    # ensure that username is unique to the org
    $user_personas = foreach ($user_persona in $user_personas) {
        if ($user_persona.'active' -eq 'true') {
            $user_persona.username = build_username_org_name_string -username ($user_persona.username) -org_name $org_name 
        }
        $user_persona
    }

    $user_personas

}

function add_username_to_usernames {
    param($usernames, $username)

    $usernames = [system.collections.generic.list[string]]$usernames
    # add $username to usernames if it does not exist in the list already
    if ((-not ([string]::IsNullOrEmpty($username))) -and ($usernames -notcontains $username)) {
        $usernames.Add($username) | Out-Null
    }

    $usernames

}

function add_profile_to_profiles {
    param($profile_names, $profile_name)
    # add $profile_name to profile_names if it does not exist in the list already
    if ($profile_names -notcontains $profile_name) {
        $profile_names.Add($profile_name) | Out-Null
    }

    $profile_names
}

function setup_org_environment_eBikes_riables {
    param($scratch_org_environment_alias)

    $org_information_json = sfdx force:org:display -u $scratch_org_environment_alias --verbose --json

    Write-Host $org_information_json
    $org_information = $org_information_json | ConvertFrom-Json
  
    if ($org_information.result -ne $null) {
        $env:ORG_ALIAS = $scratch_org_environment_alias
        $env:ORG_INSTANCE_URL = $org_information.result.instanceUrl
        $env:SFDX_AUTH_URL = $org_information.result.sfdxAuthUrl
    }         
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

function USER_DETAIL_CONTAINS_EXPECTED_ITEMS {
    param($profile_name, $permset_api_names)
    
    $user_detail_correct = $True

    if ([string]::IsNullOrEmpty($profile_name)) {
        $user_detail_correct = $False
        Write-Error -Message 'ERROR: USER PERSONA PROFILE-NAME CANNOT BE EMPTY!' -ErrorAction Stop
    }
    elseif ($permset_api_names.length -eq 0) {
        $user_detail_correct = $False
        Write-Error -Message 'ERROR: USER PERSONA PERMISSION-SETS CANNOT BE EMPTY!' -ErrorAction Stop
    }

    $user_detail_correct
}


function build_random_string_from_string_characters_range {
    param($min_length, $max_length, $string_characters)

    if ($string_characters -eq $null) {
        Write-Error 'ERROR: $STRING_CHARACTERS MUST BE NON-NULL' -ErrorAction Stop
    }
    elseif ($min_length -eq $null) {
        Write-Error 'ERROR: $MIN_LENGTH MUST BE NON-NULL' -ErrorAction Stop
    }
    elseif ($max_length -eq $null) {
        Write-Error 'ERROR: $MAX_LENGTH MUST BE NON-NULL' -ErrorAction Stop
    }
    elseif ($max_length -lt $min_length) {
        Write-Error 'ERROR: $MAX_LENGTH MUST BE GREATER THAN OR EQUAL TO $MIN_LENGTH' -ErrorAction Stop
    }
    elseif (($max_length -lt 0) -or ($min_length -lt 0)) {
        Write-Error 'ERROR: $MAX_LENGTH AND $MIN_LENGTH MUST NOT BE NEGATIVE' -ErrorAction Stop
    }

    if ($min_length -eq $max_length) {
        $length = $min_length
    }
    else {
        $length = Get-Random -Minimum $min_length -Maximum $max_length
    }

    if (($length -le 0) -or ($string_characters.length -eq 0)) {
        $random_string = ''
    }
    else {
        $random_character_array = (1..$length) | foreach {
            $random_index = Get-Random -Minimum 0 -Maximum ($string_characters.length - 1);
            $string_characters[$random_index]
        }
        $random_string = $random_character_array -join ''
    }

    $random_string
}


function build_random_string_from_string_characters {
    param($length, $string_characters)
    build_random_string_from_string_characters_range -min_length $length -max_length $length -string_characters $string_characters
}


function generate_salesforce_password_range {
    param($min_length, $max_length)
    $salesforce_password_acceptable_characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    build_random_string_from_string_characters_range -min_length $min_length -max_length $max_length -string_characters $salesforce_password_acceptable_characters
}


function generate_salesforce_password {
    param($length)
    generate_salesforce_password_range -min_length $length -max_length $length
}


function get_random_alphabetical_string_range {
    param($min_length, $max_length)
    build_random_string_from_string_characters_range -min_length $min_length -max_length $max_length -string_characters 'abcdefghijklmnopqrstuvwxyz'
}


function get_random_alphabetical_string {
    param($length)
    get_random_alphabetical_string_range $length $length
}


function ConvertTo-Hashtable {
    [CmdletBinding()]
    [OutputType('hashtable')]
    param (
        [Parameter(eBikes_lueFromPipeline)]
        $InputObject
    )

    process {
        ## Return null if the input is null. This can happen when calling the function
        ## recursively and a property is null
        if ($null -eq $InputObject) {
            return $null
        }

        ## Check if the input is an array or collection. If so, we also need to convert
        ## those types into hash tables as well. This function will convert all child
        ## objects into hash tables (if applicable)
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = @(
                foreach ($object in $InputObject) {
                    ConvertTo-Hashtable -InputObject $object
                }
            )

            ## Return the array but don't enumerate it because the object may be pretty complex
            Write-Output -NoEnumerate $collection
        } elseif ($InputObject -is [psobject]) { ## If the object has properties that need enumeration
            ## Convert it to its own hash table and return it
            $hash = @{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = ConvertTo-Hashtable -InputObject $property.eBikes_lue
            }
            $hash
        } else {
            ## If the object isn't an array, collection, or other object, it's already a hash table
            ## So just return it.
            $InputObject
        }
    }
}

function get_profiles_from_api_names {
    param($profile_names)
    $profile_names_string = ($profile_names | foreach { "'$_'" }) -join ','
    $get_profiles_query = "SELECT ID, Name FROM Profile WHERE Name IN ($profile_names_string)"
    Write-Host "sfdx force:data:soql:query -q `"$get_profiles_query`" -r json -u $($env:ORG_ALIAS)"
    $profile_query_response_json = sfdx force:data:soql:query -q "$get_profiles_query" -r json -u $env:ORG_ALIAS
    $profile_query_response = $profile_query_response_json | ConvertFrom-Json
    $profile_records = $profile_query_response.result.records
    $profile_records
}

function get_profiles_from_profile_ids {
    param($profile_ids)
    $profile_ids_string = ($profile_ids | foreach { "'$_'" }) -join ','
    $get_profiles_query = "SELECT ID, Name FROM Profile WHERE Id IN ($profile_ids_string)"
    Write-Host "sfdx force:data:soql:query -q `"$get_profiles_query`" -r json -u $($env:ORG_ALIAS)"
    $profile_query_response_json = sfdx force:data:soql:query -q "$get_profiles_query" -r json -u $env:ORG_ALIAS
    $profile_query_response = $profile_query_response_json | ConvertFrom-Json
    $profile_records = $profile_query_response.result.records
    $profile_records
}

function get_profiles_from_api_names {
    param($profile_names)
    $profile_names_string = ($profile_names | foreach { "'$_'" }) -join ','
    $get_profiles_query = "SELECT ID, Name FROM Profile WHERE Name IN ($profile_names_string)"
    Write-Host "sfdx force:data:soql:query -q `"$get_profiles_query`" -r json -u $($env:ORG_ALIAS)"
    $profile_query_response_json = sfdx force:data:soql:query -q "$get_profiles_query" -r json -u $env:ORG_ALIAS
    $profile_query_response = $profile_query_response_json | ConvertFrom-Json
    $profile_records = $profile_query_response.result.records
    $profile_records
}

function get_users_from_org {
    param($usernames)
    $usernames_string = ($usernames | foreach { "'$_'" }) -join ','
    $get_users_query = "SELECT Id, FirstName, LastName, Alias, Email, LocaleSidKey, LanguageLocaleKey, EmailEncodingKey, TimeZoneSidKey, Username, Name, ProfileId, Profile.Name, IsActive FROM User WHERE Username IN ($usernames_string)"
    Write-Host "sfdx force:data:soql:query -q `"$get_users_query`" -r json -u $($env:ORG_ALIAS)"
    sfdx force:data:soql:query -q "$get_users_query" -r json -u $env:ORG_ALIAS
}

function build_map_id_to_error_lines_from_log {
    param($path_to_log_file, $user_ids)

    $map_id_to_error_lines = @{}
    $map_id_to_regex_patterns = @{}

    foreach ($user_id in $user_ids) {
        $map_id_to_error_lines[$user_id] = [system.collections.generic.list[string]]::new()
        $map_id_to_regex_patterns[$user_id] = @(
            "\|EXCEPTION_THROWN\|.*$user_id",
            "\|DEBUG\|The following exception has occurred.*$user_id"
        )
    }

    foreach ($log_line in (Get-Content $path_to_log_file)) {
        foreach ($user_id in $user_ids) {
            foreach ($regex_pattern in $map_id_to_regex_patterns.$user_id) {
                $match_result = [regex]::match($log_line, $regex_pattern)
                if ($match_result.success) {
                    $map_id_to_error_lines[$user_id].Add($log_line) | Out-Null
                }
            }
        }
    }

    $map_id_to_error_lines

}

function get_permsets_from_api_names {
    param($permission_set_names)
    $permission_set_names_string = ($permission_set_names | foreach { "'$_'" }) -join ','
    $permissionset_query_response_json = sfdx force:data:soql:query -q "SELECT Id,Name,Label,ProfileId FROM PermissionSet WHERE Name in ($permission_set_names_string)" -r json -u ($env:ORG_ALIAS)
    $permissionset_query_response = $permissionset_query_response_json | ConvertFrom-Json
    $permissionset_records = $permissionset_query_response.result.records
    $permissionset_records
}

function get_permsetassignments_from_user_ids {
    param($user_ids)
    $user_ids_string = ($user_ids | foreach { "'$_'" }) -join ','
    $permissionsetassignment_query_response_json = sfdx force:data:soql:query -q "SELECT Id,PermissionSet.Id,PermissionSet.Name,PermissionSet.ProfileId,Assignee.Id,Assignee.Username FROM PermissionSetAssignment WHERE Assignee.Id in ($user_ids_string)" -r json -u ($env:ORG_ALIAS)
    $permissionsetassignment_query_response = $permissionsetassignment_query_response_json | ConvertFrom-Json
    $permissionsetassignment_records = $permissionsetassignment_query_response.result.records
    $permissionsetassignment_records
}



function get_queues_from_api_names {
    param($queue_api_names)
    $queue_api_names_string = ($queue_api_names | foreach { "'$_'" }) -join ','
    $queues_query_response_json = sfdx force:data:soql:query -q "SELECT Id,Name,DeveloperName FROM Group WHERE DeveloperName in ($queue_api_names_string) AND Type = 'Queue'" -r json -u ($env:ORG_ALIAS)
    $queues_query_response = $queues_query_response_json | ConvertFrom-Json
    $queues_records = $queues_query_response.result.records
    $queues_records
}

function get_groups_from_api_names {
    param($group_api_names)
    $group_api_names_string = ($group_api_names | foreach { "'$_'" }) -join ','
    $groups_query_response_json = sfdx force:data:soql:query -q "SELECT Id,Name,DeveloperName FROM Group WHERE DeveloperName in ($group_api_names_string)" -r json -u ($env:ORG_ALIAS)
    $groups_query_response = $groups_query_response_json | ConvertFrom-Json
    $groups_records = $groups_query_response.result.records
    $groups_records
}

function get_groups_and_queues_from_user_ids {
    param($user_ids)
    $user_ids_string = ($user_ids | foreach { "'$_'" }) -join ','
    $groups_and_queues_query_response_json = sfdx force:data:soql:query -q "SELECT Id,GroupId,UserOrGroupId,Group.DeveloperName,Group.Type FROM GroupMember WHERE UserOrGroupId IN ($user_ids_string)" -r json -u ($env:ORG_ALIAS)
    $groups_and_queues_query_response = $groups_and_queues_query_response_json | ConvertFrom-Json
    $groups__and_queues_records = $groups_and_queues_query_response.result.records
    $groups__and_queues_records
}

function get_roles_from_api_names {
    param($role_api_names)
    $role_api_name_string = ($role_api_names | foreach { "'$_'" }) -join ','
    $roles_query_response_json = sfdx force:data:soql:query -q "SELECT Id, Name, DeveloperName FROM UserRole WHERE DeveloperName in ($role_api_name_string)" -r json -u ($env:ORG_ALIAS)
    $roles_query_response = $roles_query_response_json | ConvertFrom-Json
    $role_records = $roles_query_response.result.records
    $role_records
}

function check_for_missing_records {
    param(
        $all_profile_names,
        $profile_records,
        $all_permission_set_api_names,
        $permset_records,
        $all_queue_api_names,
        $queue_records,
        $all_group_api_names,
        $group_records,
        $all_role_api_names,
        $role_records
    )

    $error_messages = [system.collections.generic.list[string]]::new()

    foreach ($profilename in $all_profile_names) {
        $returned_profile_api_names = $profile_records | foreach Name
        if ($returned_profile_api_names -notcontains $profilename) {
            $error_messages.Add("** ERROR: `$PROFILENAME '$profilename' WAS NOT FOUND IN '$($env:ORG_INSTANCE_URL)'") | Out-Null
        }
    }

    foreach ($permset_name in $all_permission_set_api_names) {
        $returned_permset_api_names = $permset_records | foreach Name
        if ($returned_permset_api_names -notcontains $permset_name) {
            $error_messages.Add("** ERROR: `$PERMSET_NAME '$permset_name' WAS NOT FOUND IN '$($env:ORG_INSTANCE_URL)'") | Out-Null
        }
    }

    foreach ($queue_name in $all_queue_api_names) {
        $returned_queue_api_names = $queue_records | foreach DeveloperName
        if ($returned_queue_api_names -notcontains $queue_name) {
            $error_messages.Add("** ERROR: `$QUEUE_NAME '$queue_name' WAS NOT FOUND IN '$($env:ORG_INSTANCE_URL)'") | Out-Null
        }
    }

    foreach ($group_name in $all_group_api_names) {
        $returned_group_api_names = $group_records | foreach DeveloperName
        if ($returned_group_api_names -notcontains $group_name) {
            $error_messages.Add("** ERROR: `$GROUP_NAME '$group_name' WAS NOT FOUND IN '$($env:ORG_INSTANCE_URL)'") | Out-Null
        }
    }

    foreach ($role_api_name in $all_role_api_names) {
        $returned_role_api_name = $role_records | foreach DeveloperName
        if ($returned_role_api_name -notcontains $role_api_name) {
            $error_messages.Add("** ERROR: `$GROUP_NAME '$role_api_name' WAS NOT FOUND IN '$($env:ORG_INSTANCE_URL)'") | Out-Null
        }
    }

    if ($error_messages.count -gt 0) {
        foreach ($error_message in $error_messages) {
            Write-Host $error_message
        }
        $current_datetime=[datetime]::now;
        $current_datetime_string = $current_datetime.toString('yyyy.MM.dd-HH.mm.ss-tt'); $current_datetime_string
        $path_to_error_log_file = "$($env:PATH_TO_LOG_DIRECTORY)/customer-personas.$current_datetime_string.log"
        $error_messages | Out-File $path_to_error_log_file
        $env:STOP_SCRIPT = $true
        Write-Error -Message "CHECK $($path_to_error_log_file.ToUpper()) FOR DETAILS ON SCRIPT CANCELLING" -ErrorAction Stop
    }

}

function get_org_name_from_instance_url {
    param($instance_url)
    $instance_url_pattern = 'https://(.*).my.salesforce.com'
    $match_result = [regex]::match($instance_url, $instance_url_pattern)
    if ($match_result.success -and $match_result.groups.count -eq 2) {
        $match_result.groups[1].eBikes_lue
    }
    else {
        Write-Error -Message "ERROR: INSTANCE URL '$instance_url' DID NOT MATCH EXPECTED PATTERN '$instance_url_pattern'" -ErrorAction Stop
    }
}

function username_has_org_name_appended {
    param($username)
    $username -match "___.*___`$"
}

function build_username_org_name_string {
    param($username, $org_name)
    $org_name_sanitized = $org_name -replace '-','' -replace '\.',''
    "$($username).___$($org_name_sanitized)___"
}

function get_original_username_from_username_org_name_string {
    param($username)
    $org_name_pattern = '^(.*)\.___.*___'
    $match_result = [regex]::match($username, $org_name_pattern)
    if ($match_result.success -and $match_result.groups.count -eq 2) {
        $match_result.groups[1].eBikes_lue
    }
    else {
        Write-Error -Message "ERROR: INSTANCE URL '$username' DID NOT MATCH EXPECTED PATTERN '$org_name_pattern'" -ErrorAction Stop
    }
}

function foreach_list_function {
    param($list, $sb)                                                
    $list_result = [system.collections.generic.list[string]]::new()
    foreach ($element in $list) {                         
        $this_result = & $sb $element;
        $list_result.Add($this_result) | Out-Null
    }                                  
    ,$list_result                           
}                                                          
                                            
function foreach_list_function_test {                                                                                                           
    $sample_list_single_element = @(                               
        [PSCustomObject]@{ 'id' = 'abc1'; 'eBikes_lue' = 'a1' }
    )                                 
                                                
    $sample_list_multiple_elements = @(
        [PSCustomObject]@{ 'id' = 'abc1'; 'eBikes_lue' = 'a1' },
        [PSCustomObject]@{ 'id' = 'abc2'; 'eBikes_lue' = 'a2' },
        [PSCustomObject]@{ 'id' = 'abc3'; 'eBikes_lue' = 'a3' },
        [PSCustomObject]@{ 'id' = 'abc4'; 'eBikes_lue' = 'a4' }
    )

    $list = foreach_list -list $sample_list_single_element -sb { param($v) $v.id }
    $first_id_of_sample_list_single_element = $list[0]
    Write-Host "`$FIRST_ID_OF_SAMPLE_LIST_SINGLE_ELEMENT is: $first_id_of_sample_list_single_element"

    $list = foreach_list -list $sample_list_multiple_elements -sb { param($v) $v.id }
    $first_id_of_sample_list_multiple_elements = $list[0]
    Write-Host "`$FIRST_ID_OF_SAMPLE_LIST_MULTIPLE_ELEMENTS is: $first_id_of_sample_list_multiple_elements"
}

function foreach_list
{
    [CmdletBinding()]
    Param(
        [Parameter(eBikes_lueFromPipeline)]
        [PSCustomObject]$pipeline_object,
        [ScriptBlock]$process
    )

    begin {
        $list_result = [system.collections.generic.list[object]]::new()
    }

    Process
    {
        $this_result = & $process $pipeline_object
        $list_result.Add($this_result) | Out-Null
    }
    
    end {
        ,$list_result 
    }  
}

function foreach_list_test {
    $pipeline_multiple_objects = @([PSCustomObject]@{ 'id'='1234'; 'name'='Joe' }, [PSCustomObject]@{ 'id'='1235'; 'name'='Larry' })
    $pipeline_single_object = @([PSCustomObject]@{ 'id'='1235'; 'name'='Larry' })

    $result_pipeline_multiple_objects = $pipeline_multiple_objects | foreach_list -process { $_.name }
    Write-Host "`$result_pipeline_multiple_objects.count is $($result_pipeline_multiple_objects.count)"
    Write-Host "`$result_pipeline_multiple_objects is $result_pipeline_multiple_objects"
    Write-Host "`$result_pipeline_multiple_objects type is $($result_pipeline_multiple_objects.gettype().fullname)"

    $result_pipeline_single_object = $pipeline_single_object | foreach_list -process { $_.name }
    Write-Host "`$result_pipeline_single_object.count is $($result_pipeline_single_object.count)"
    Write-Host "`$result_pipeline_single_object is $result_pipeline_single_object"
    Write-Host "`$result_pipeline_single_object type is $($result_pipeline_single_object.gettype().fullname)"
}

function get_default_org_target_info_from_sfdxconfigjson {
    $path_to_sfdx_config_json = '.\.sfdx\sfdx-config.json' 
    $PATH_TO_SFDX_CONFIG_JSON_UPPER_CASE = $path_to_sfdx_config_json.ToUpper()
    if (Test-Path $path_to_sfdx_config_json) {
        $sfdx_config_json = Get-Content .\.sfdx\sfdx-config.json
        $sfdx_config = $sfdx_config_json | ConvertFrom-Json
        if ($null -ne $sfdx_config) {
            $sfdx_org_alias =  $sfdx_config.defaultusername
            if ($null -ne $sfdx_org_alias) {
                Write-Host -Message "SUCCESS: DEFAULT ORG ALIAS SETUP IN SFDX-CONFIG.JSON: $sfdx_org_alias"
                $sfdx_org_alias
            } else {
                Write-Error -Message "ERROR: NO DEFAULTUSERNAME eBikes_LUE IN THE FILE $PATH_TO_SFDX_CONFIG_JSON_UPPER_CASE" -ErrorAction Stop
            }
        } else {
            Write-Error -Message "ERROR: FAILED TO PARSE $PATH_TO_SFDX_CONFIG_JSON_UPPER_CASE" -ErrorAction Stop
    }
        }
    else {
        Write-Error -Message "ERROR $PATH_TO_SFDX_CONFIG_JSON_UPPER_CASE DOES NOT EXIST" -ErrorAction STOP
    }
}
