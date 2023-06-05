function deactivate_existing_users {
    param($usernames)

    Write-Host "`n[[ PROCESSING EXISTING USERS ]]"

    $user_query_response_json = get_users_from_org $usernames
    $user_query_response = $user_query_response_json | convertfrom-json
    [array]$user_records = $user_query_response.result.records | select Id,FirstName,Username,Name,IsActive

    function user_records_summary {
        param($user_records, $label)
        function user_record_summary { param($user_record) "{ `"Id`": `"$($user_record.Id)`", `"IsActive`": `"$($user_record.IsActive)`" }"  }
        $user_records_summary = "[`n$(($user_records | foreach { "`t$(user_record_summary $_)" }) -join ",`n")`n]"
        "$label`n$user_records_summary"
    }

    if ($user_records.count -gt 0) {

        $user_ids = $user_records | foreach id
        [array]$user_ids = $user_ids
        $user_ids_string = ($user_ids | foreach { "'$_'" }) -join ','    

        $initialize_map_id_to_values_map_lines = (0..($user_ids.count-1)) | foreach {
            $user_id = $user_ids[$_]
            $user_number = $_ + 1
            $map_variable_name = "mapPropertiesTovalues$user_number"
            @"
Map<String, String> $map_variable_name = new Map<String, String>();
$map_variable_name.put('FirstName', 'inactive_$(get_random_alphabetical_string_range -min_length 4 -max_length 6)');
$map_variable_name.put('Username', 'inactive_$(get_random_alphabetical_string_range -min_length 4 -max_length 6)@va.gov');
mapIdTovaluesMap.put('$user_id', $map_variable_name);
"@
        }

        $initialize_map_id_to_values_map = $initialize_map_id_to_values_map_lines -join "`n`n"

        $anonymous_apex_map_userid_to_new_values = @"

List<User> testUsers = [SELECT Id, FirstName, Username, Name FROM User WHERE Id IN ($user_ids_string)];

Map<String, Map<String, String>> mapIdTovaluesMap = new Map<String, Map<String, String>>();

$initialize_map_id_to_values_map

for (User testUser : testUsers) {
    try {
        Map<String, String> mapPropertiesTovalues = mapIdTovaluesMap.get(testUser.Id);
        testUser.FirstName = mapPropertiesTovalues.get('FirstName');
        testUser.Username = mapPropertiesTovalues.get('Username');
        testUser.IsActive = false;
    } catch (Exception e) {
        System.debug('The following exception has occurred: ' + e.getMessage());
    }
}

update testUsers;
"@

        Write-Host $anonymous_apex_map_userid_to_new_values
        $anonymous_apex_file_name = "existing_users_deactivation.apex"

        # Below line used for powershell 7
        # $anonymous_apex_map_userid_to_new_values | Out-File $anonymous_apex_file_name

        New-Item -Path . -Name $anonymous_apex_file_name -ItemType File -value $anonymous_apex_map_userid_to_new_values | Out-Null

        $deactivate_users_log_file_name = 'sfdx-run-deactivate-users.log'
        Write-Host "running 'sfdx force:apex:execute -u $($env:ORG_ALIAS) -f $anonymous_apex_file_name' --loglevel ERROR"
        sfdx force:apex:execute -u ($env:ORG_ALIAS) -f $anonymous_apex_file_name --loglevel ERROR | Out-File $deactivate_users_log_file_name
        Remove-Item -Force $anonymous_apex_file_name 

        $apex_deactivation_logs = Get-Content .\sfdx-run-deactivate-users.log
        Write-Host "Deactivation logs generating..."
        while ($apex_deactivation_logs -eq $NULL) {
            Start-Sleep 1
            Write-Host "Deactivation logs generating..."
            $apex_deactivation_logs = Get-Content .\sfdx-run-deactivate-users.log
        }
        $user_records_after_response_json = get_users_from_org $usernames
        $user_records_after_response = $user_records_after_response_json | convertfrom-json
        $user_records_after = $user_records_after_response.result.records | select Id,FirstName,Username,Name,IsActive
        $user_ids_after = $user_records_after | foreach id

        if (($user_records_after.count -ne 0) -and ($user_records_after.count -ne $user_records.count)) {

            Write-Host @"
ALL REQUESTED DEACTIvaTIONS COULD NOT BE COMPLETED
$(user_records_summary -label "[DEACTIvaTION WAS REQUESTED FOR THE FOLLOWING $($user_records.count) USERS]" -user_records $user_records)
$(user_records_summary -label "[DEACTIvaTION COULD NOT BE COMPLETED FOR THE FOLLOWING $($user_records_after.count) USERS]" -user_records $user_records_after)

"@
            $map_id_to_error_lines = build_map_id_to_error_lines_from_log -path_to_log_file $deactivate_users_log_file_name -user_ids $user_ids_after

            Write-Host "[ERRORS BY ID]"
            foreach ($user_id in ($map_id_to_error_lines.keys)) {
                Write-Host "`n** LOG ERRORS FOR User ID $user_id **"
                foreach ($log_line in ($map_id_to_error_lines.$user_id)) {
                    Write-Host $log_line
                } 
            }

            Write-Error 'ERROR: FAILED TO COMPLETE ALL REQUESTED DEACTIvaTIONS' -ErrorAction Stop
        }
        else {
            Write-Host @"
ALL REQUESTED DEACTIvaTIONS WERE SUCCESSFULLY COMPLETED
$(user_records_summary -label "[THE FOLLOWING $($user_records.count) USERS WERE DEACTIvaTED]" -user_records $user_records)
"@
        }

    }
    else {
        Write-Host "No existing users found."
    }
 
}