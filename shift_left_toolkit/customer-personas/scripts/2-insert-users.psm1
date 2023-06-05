$path_to_project_directory = (Get-Location).path
Import-Module -Force "$path_to_project_directory/shift_left_toolkit/customer-personas/scripts/user-persona-automation.psm1"

function update_id_on_customer_persona {
    param($user_records_inserted)

    [array]$user_personas = get_user_personas_from_user_detailjson -path_to_project_directory $path_to_project_directory

    foreach ( $user_persona in $user_personas) {
        
        foreach ( $inserted_user in $user_records_inserted) {
            if ( $inserted_user.'username' -eq $user_persona.'username') {

                $user_persona.id = $inserted_user.Id

            }
        }
    }

    write_user_personas_to_user_detail_file -user_personas $user_personas -path_to_project_directory $path_to_project_directory


}

function update_map_variables_with_user_ids {
    param($user_records_inserted)

    Write-Host "UPDATING MAP DATA WITH NEW USER IDs"

    $map_username_to_permset_info_json = Get-Content -Raw .github-workflow-tmp/map_username_to_permset_info.json
    $map_username_to_permset_info = $map_username_to_permset_info_json | ConvertFrom-Json | ConvertTo-Hashtable

    $map_username_to_queue_info_json = Get-Content -Raw .github-workflow-tmp/map_username_to_queue_info.json
    $map_username_to_queue_info = $map_username_to_queue_info_json | ConvertFrom-Json | ConvertTo-Hashtable

    $map_username_to_group_info_json = Get-Content -Raw .github-workflow-tmp/map_username_to_group_info.json
    $map_username_to_group_info = $map_username_to_group_info_json | ConvertFrom-Json | ConvertTo-Hashtable

    $map_username_to_role_info_json = Get-Content -Raw .github-workflow-tmp/map_username_to_role_info.json
    $map_username_to_role_info = $map_username_to_role_info_json | ConvertFrom-Json | ConvertTo-Hashtable

    $map_username_to_user_info_json = Get-Content -Raw .github-workflow-tmp/map_username_to_user_info.json
    $map_username_to_user_info = $map_username_to_user_info_json | ConvertFrom-Json | ConvertTo-Hashtable

    Write-Host $user_records_inserted

    foreach ($user_record in $user_records_inserted) {

        ################  START PERMSETS UPDATE #####################

        $permset_mapvalue = $map_username_to_permset_info[$user_record.Username]
        $updated_perm_user_info_list = [system.collections.generic.list[pscustomobject]]::new()

        foreach ($permset_info in $permset_mapvalue) {
            if (allElementsNotNullOrEmpty @($permset_info.permset_id, $user_record.Id)) {
                $new_perm_user_info = [PSCustomObject]@{
                    'user_id'           =  $user_record.Id;
                    'permset_id'        =  $permset_info.permset_id
                }
                $updated_perm_user_info_list.Add($new_perm_user_info) | Out-Null
            }
        } 
        Write-Host $updated_perm_user_info_list
        $map_username_to_permset_info[$user_record.Username] = $updated_perm_user_info_list

        ################  END PERMSETS UPDATE #####################

         ################  START ROLES UPDATE #####################

         $role_mapvalue = $map_username_to_role_info[$user_record.Username]
         $updated_role_info_userlist = [system.collections.generic.list[pscustomobject]]::new()
 
         foreach ($role_info in $role_mapvalue) {
             if (allElementsNotNullOrEmpty @($role_info.role_id, $user_record.Id)) {
                 $new_role_user_info = [PSCustomObject]@{
                     'user_id'        =  $user_record.Id;
                     'role_id'        =  $role_info.role_id
                 }
                 $updated_role_info_userlist.Add($new_role_user_info) | Out-Null
             }
         } 
         Write-Host $updated_role_info_userlist
         $map_username_to_role_info[$user_record.Username] = $updated_role_info_userlist
 
         ################  END ROLES UPDATE #####################

        ################  START QUEUES UPDATE #####################

        $queues_mapvalue = $map_username_to_queue_info[$user_record.Username]
        $updated_queue_user_info_list = [system.collections.generic.list[pscustomobject]]::new()

        foreach ($queue_info in $queues_mapvalue) {

            if (allElementsNotNullOrEmpty @($queue_info.queue_id, $user_record.Id)) {

                $new_queue_user_info = [PSCustomObject]@{
                    'user_id'          =  $user_record.Id;
                    'queue_id'        =  $queue_info.queue_id
                }
                $updated_queue_user_info_list.Add($new_queue_user_info) | Out-Null
            }
        } 
        Write-Host $updated_queue_user_info_list
        $map_username_to_queue_info[$user_record.Username] = $updated_queue_user_info_list

        ################  END QUEUES UPDATE #####################

        ################  START GROUPS UPDATE #####################

        $groups_mapvalue = $map_username_to_group_info[$user_record.Username]
        $updated_group_user_info_list = [system.collections.generic.list[pscustomobject]]::new()

        foreach ($group_info in $groups_mapvalue) {
            if (allElementsNotNullOrEmpty @($group_info.group_id, $user_record.Id)) {
                $new_group_user_info = [PSCustomObject]@{
                    'user_id'          =  $user_record.Id;
                    'group_id'        =  $group_info.group_id
                }
                $updated_group_user_info_list.Add($new_group_user_info) | Out-Null
            }
        } 
        Write-Host $updated_group_user_info_list
        $map_username_to_group_info[$user_record.Username] = $updated_group_user_info_list

        ################  END GROUPS UPDATE #####################

        $user_mapvalue = $map_username_to_user_info[$user_record.Username]
        $user_mapvalue.user_id = $user_record.Id
        $map_username_to_user_info[$user_record.Username] = $user_mapvalue
    }
    
    Write-Host $map_username_to_permset_info | ConvertTo-Json
    Write-Host $map_username_to_queue_info | ConvertTo-Json
    Write-Host $map_username_to_group_info | ConvertTo-Json
    Write-Host $map_username_to_role_info | ConvertTo-Json
    Write-Host $map_username_to_user_info | ConvertTo-Json

    $map_username_to_permset_info | ConvertTo-Json | Out-File .github-workflow-tmp/map_username_to_permset_info.json
    $map_username_to_queue_info | ConvertTo-Json | Out-File .github-workflow-tmp/map_username_to_queue_info.json
    $map_username_to_group_info | ConvertTo-Json | Out-File .github-workflow-tmp/map_username_to_group_info.json
    $map_username_to_role_info | ConvertTo-Json | Out-File .github-workflow-tmp/map_username_to_role_info.json
    $map_username_to_user_info | ConvertTo-Json | Out-File .github-workflow-tmp/map_username_to_user_info.json

}

# persist
function get_profile_name_id_map_from_profile_names {
    param($profile_names)

    Write-Host "`n[[ GETTING PROFILE-NAME-ID-MAP FROM PROFILE NAMES ]]"

    $profile_records = get_profiles_from_api_names $profile_names

    $profile_name_id_map = @{}

    foreach ($profile in ($profile_records)) {
        $profile_name_id_map[$profile.name] = $profile.Id
    }

    $profile_name_id_map
}

function insert_users {
    param($map_username_to_profile_info, $user_personas)
    Write-Host "`n[[ INSERTING USERS ]]"

    $users_to_insert = [system.collections.generic.list[pscustomobject]]::new()

    foreach ($user_persona in $user_personas) {

        $profile_info = $map_username_to_profile_info[$user_persona.'username']
        $profile_id = $profile_info.profile_id

        $random_alias = get_random_alphabetical_string -length 8

        $new_user_info = [PSCustomObject]@{
            'Username'           =  $user_persona.'username';
            'FirstName'          =  $user_persona.'firstname';
            'LastName'           =  $user_persona.'lastname';
            'Email'              =  $user_persona.'email_address';
            'Alias'              =  $random_alias;
            'LocaleSidKey'       =  'en_US';
            'LanguageLocaleKey'  =  'en_US';
            'EmailEncodingKey'   =  'ISO-8859-1';
            'TimeZoneSidKey'     =  'America/New_York';
            'ProfileId'          =  $profile_id;
        }

        $users_to_insert.Add($new_user_info) | Out-Null

    }

    Write-Host "`$users_to_insert:"
    $users_to_insert

    $user_list_variable_name = 'users'

    $new_user_lines = (0..($users_to_insert.count-1)) | foreach {
        $new_user = $users_to_insert[$_]
        $user_number = $_+1
        @"
User newUser$user_number = new User(Username = '$($new_user.username)', FirstName = '$($new_user.firstname)', LastName = '$($new_user.lastname)', Email = '$($new_user.email)', Alias = '$($new_user.Alias)', LocaleSidKey = 'en_US', LanguageLocaleKey = 'en_US', EmailEncodingKey = 'ISO-8859-1', TimeZoneSidKey = 'America/New_York', ProfileId = '$($new_user.ProfileId)');
$user_list_variable_name.add(newUser$user_number);
"@
    }

    $initialize_new_users = $new_user_lines -join "`n"

    $anonymous_apex_insert = @"

List<User> $user_list_variable_name = New List<User>();

$initialize_new_users

try {
    insert $user_list_variable_name;
} catch (Exception e) {
    System.debug('The following exception has occurred: ' + e.getMessage());
}
"@

    Write-Host "`$anonymous_apex_insert is"
    Write-Host $anonymous_apex_insert

    $anonymous_apex_file_name = "anonymous_apex_insert.cls"
    # Below lines used for powershell 7
    # New-Item -Type File $anonymous_apex_file_name | Out-Null
    # $anonymous_apex_insert | Out-File $anonymous_apex_file_name

    if (Test-Path $anonymous_apex_file_name) {
        Write-Host "DELETING ANONYMOUS APEX FILE '$anonymous_apex_file_name' BECAUSE IT ALREADY EXISTS"
        Remove-Item -Force $anonymous_apex_file_name
    }
    New-Item -Path . -Name $anonymous_apex_file_name -ItemType "file" -value $anonymous_apex_insert | Out-Null

    $apex_execute_result_json = $( sfdx force:apex:execute -u ($env:ORG_ALIAS) -f $anonymous_apex_file_name --loglevel ERROR --json )
    $apex_execute_result = $apex_execute_result_json | ConvertFrom-Json -Depth 4
    Write-Host -BackgroundColor "White" -ForegroundColor "Yellow" $apex_execute_result.result
    Remove-Item -Force $anonymous_apex_file_name

    $usernames_string = ($users_to_insert | foreach { "'$($_.Username)'" }) -join ','
    $verify_insert_query = "select Id,Username,FirstName,LastName,Email,Alias,LocaleSidKey,LanguageLocaleKey,EmailEncodingKey,TimeZoneSidKey,ProfileId FROM User WHERE Username IN ($usernames_string)"
    Write-Host "`nverify insert query is"
    Write-Host $verify_insert_query

    $users_inserted_query__response_json = sfdx force:data:soql:query -q $verify_insert_query -r json -u ($env:ORG_ALIAS)
    $users_inserted_query__response = $users_inserted_query__response_json | ConvertFrom-Json
    $user_records_inserted = $users_inserted_query__response.result.records 

    Write-Host "$($user_records_inserted.count) USER RECORDS INSERTED:"
    $user_records_inserted | ConvertTo-Json

    if ($users_to_insert.count -ne $user_records_inserted.count) {
        $NUMBER_OF_FAILED_INSERTS = $users_to_insert.count - $user_records_inserted.count
        Write-Error "ERROR: FAILED TO INSERT $NUMBER_OF_FAILED_INSERTS OF $($users_to_insert.count) REQUESTED USER RECORDS" -ErrorAction Stop
    } else {
        Write-Host "SUCCESSFULLY INSERTED $($users_to_insert.count) OF $($users_to_insert.count) REQUESTED USER RECORDS"
    }

    update_map_variables_with_user_ids -user_records_inserted $user_records_inserted

    update_id_on_customer_persona -user_records_inserted $user_records_inserted

}