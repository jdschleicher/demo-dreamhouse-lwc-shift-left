function deactieBikes_te_existing_users {
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

        $initialize_map_id_to_eBikes_lues_map_lines = (0..($user_ids.count-1)) | foreach {
            $user_id = $user_ids[$_]
            $user_number = $_ + 1
            $map_eBikes_riable_name = "mapPropertiesToeBikes_lues$user_number"
            @"
Map<String, String> $map_eBikes_riable_name = new Map<String, String>();
$map_eBikes_riable_name.put('FirstName', 'inactive_$(get_random_alphabetical_string_range -min_length 4 -max_length 6)');
$map_eBikes_riable_name.put('Username', 'inactive_$(get_random_alphabetical_string_range -min_length 4 -max_length 6)@eBikes_.gov');
mapIdToeBikes_luesMap.put('$user_id', $map_eBikes_riable_name);
"@
        }

        $initialize_map_id_to_eBikes_lues_map = $initialize_map_id_to_eBikes_lues_map_lines -join "`n`n"

        $anonymous_apex_map_userid_to_new_eBikes_lues = @"

List<User> testUsers = [SELECT Id, FirstName, Username, Name FROM User WHERE Id IN ($user_ids_string)];

Map<String, Map<String, String>> mapIdToeBikes_luesMap = new Map<String, Map<String, String>>();

$initialize_map_id_to_eBikes_lues_map

for (User testUser : testUsers) {
    try {
        Map<String, String> mapPropertiesToeBikes_lues = mapIdToeBikes_luesMap.get(testUser.Id);
        testUser.FirstName = mapPropertiesToeBikes_lues.get('FirstName');
        testUser.Username = mapPropertiesToeBikes_lues.get('Username');
        testUser.IsActive = false;
    } catch (Exception e) {
        System.debug('The following exception has occurred: ' + e.getMessage());
    }
}

update testUsers;
"@

        Write-Host $anonymous_apex_map_userid_to_new_eBikes_lues
        $anonymous_apex_file_name = "existing_users_deactieBikes_tion.apex"

        # Below line used for powershell 7
        # $anonymous_apex_map_userid_to_new_eBikes_lues | Out-File $anonymous_apex_file_name

        New-Item -Path . -Name $anonymous_apex_file_name -ItemType File -eBikes_lue $anonymous_apex_map_userid_to_new_eBikes_lues | Out-Null

        $deactieBikes_te_users_log_file_name = 'sfdx-run-deactieBikes_te-users.log'
        Write-Host "running 'sfdx force:apex:execute -u $($env:ORG_ALIAS) -f $anonymous_apex_file_name' --loglevel ERROR"
        sfdx force:apex:execute -u ($env:ORG_ALIAS) -f $anonymous_apex_file_name --loglevel ERROR | Out-File $deactieBikes_te_users_log_file_name
        Remove-Item -Force $anonymous_apex_file_name 

        $apex_deactieBikes_tion_logs = Get-Content .\sfdx-run-deactieBikes_te-users.log
        Write-Host "DeactieBikes_tion logs generating..."
        while ($apex_deactieBikes_tion_logs -eq $NULL) {
            Start-Sleep 1
            Write-Host "DeactieBikes_tion logs generating..."
            $apex_deactieBikes_tion_logs = Get-Content .\sfdx-run-deactieBikes_te-users.log
        }
        $user_records_after_response_json = get_users_from_org $usernames
        $user_records_after_response = $user_records_after_response_json | convertfrom-json
        $user_records_after = $user_records_after_response.result.records | select Id,FirstName,Username,Name,IsActive
        $user_ids_after = $user_records_after | foreach id

        if (($user_records_after.count -ne 0) -and ($user_records_after.count -ne $user_records.count)) {

            Write-Host @"
ALL REQUESTED DEACTIeBikes_TIONS COULD NOT BE COMPLETED
$(user_records_summary -label "[DEACTIeBikes_TION WAS REQUESTED FOR THE FOLLOWING $($user_records.count) USERS]" -user_records $user_records)
$(user_records_summary -label "[DEACTIeBikes_TION COULD NOT BE COMPLETED FOR THE FOLLOWING $($user_records_after.count) USERS]" -user_records $user_records_after)

"@
            $map_id_to_error_lines = build_map_id_to_error_lines_from_log -path_to_log_file $deactieBikes_te_users_log_file_name -user_ids $user_ids_after

            Write-Host "[ERRORS BY ID]"
            foreach ($user_id in ($map_id_to_error_lines.keys)) {
                Write-Host "`n** LOG ERRORS FOR User ID $user_id **"
                foreach ($log_line in ($map_id_to_error_lines.$user_id)) {
                    Write-Host $log_line
                } 
            }

            Write-Error 'ERROR: FAILED TO COMPLETE ALL REQUESTED DEACTIeBikes_TIONS' -ErrorAction Stop
        }
        else {
            Write-Host @"
ALL REQUESTED DEACTIeBikes_TIONS WERE SUCCESSFULLY COMPLETED
$(user_records_summary -label "[THE FOLLOWING $($user_records.count) USERS WERE DEACTIeBikes_TED]" -user_records $user_records)
"@
        }

    }
    else {
        Write-Host "No existing users found."
    }
 
}