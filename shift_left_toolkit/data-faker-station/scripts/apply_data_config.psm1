
function check_and_set_sfdx_connection_by_org_alias {
    param($org_alias)

    $org_connection_information_json = $( sfdx force:org:display --targetusername $org_alias --verbose --json )
    $org_connection_information = $org_connection_information_json | ConvertFrom-Json

    $sfdx_connection_detail = $null

    if ( $org_connection_information.status -ne 0 ) {

        Write-Error "THERE WAS AN ISSUE AUTHENTICATING AND CAPTURING ORG INFORMATION FOR $org_alias :"
        Write-Error "JSON: $org_connection_information_json"
        Throw

    } else {

        Write-Host -ForegroundColor Green "SFDX CONNECTION SUCCESSFUL TO: $org_alias"
        $sfdx_connection_detail = [PSCustomObject]@{
            access_token = $org_connection_information.result.accessToken
            instance_url = $org_connection_information.result.instanceUrl
            org_alias = $org_alias
            api_version = $org_connection_information.result.apiVersion
        }

        $sfdx_connection_detail_json = $sfdx_connection_detail | ConvertTo-Json -Compress
        $enc = [System.Text.Encoding]::UTF8
        $enc_utf8_bytes = $enc.GetBytes($sfdx_connection_detail_json)
        $base64encoded_sfdx_connection_detail_json = [Convert]::ToBase64String($enc_utf8_bytes)
        $env:SFDX_CONNECTION = $base64encoded_sfdx_connection_detail_json

    }

    $sfdx_connection_detail

}

function reuse_generated_data {
    param($datetime_stamp, $org_alias, $path_to_generated_dataset_directory)
    $dataset_data_import_folders = Get-ChildItem -Directory $path_to_generated_dataset_directory -filter "*$datetime_stamp*"
    
    foreach ($dataset_data_import_folder in $dataset_data_import_folders) {
        $relative_path_to_dataset_data_import_folder = $dataset_data_import_folder | Resolve-Path -Relative
        perform_dataset_upsert -org_alias $org_alias -path_to_dataset_json $relative_path_to_dataset_data_import_folder 
    }
}

function apply_recipe {
    param($path_to_recipe_yml, $path_to_data_folder, $raw_data_path)

    $recipe_file_exists = Test-Path $path_to_recipe_yml
    $data_folder_exists = Test-Path $path_to_data_folder

    if (-Not $recipe_file_exists) {
        Write-Error -Message "ERROR: RECIPE FILE DOES NOT EXIST '$path_to_recipe_yml'" -ErrorAction Stop
    }
    elseif (-Not $data_folder_exists) {
        Write-Error -Message "ERROR: DATA FOLDER DOES NOT EXIST '$path_to_data_folder'" -ErrorAction Stop
    } else {

        Write-Host " ######################## SNOWFAKERY GENERATION RESULTS ####################### "
        $snowfakery_result_file_name = "snowfakery_generation.txt"
        $(snowfakery --output-format=csv --output-folder $path_to_data_folder $path_to_recipe_yml *> $snowfakery_result_file_name) | Out-Null
        $snowfakery_results = (Get-Content -Raw $snowfakery_result_file_name)
        Remove-Item $snowfakery_result_file_name
        Write-Host " ######################## "
        Write-Host "`n$snowfakery_results`n"
        Write-Host " ######################## "

        $snowfakery_error_message_strings = @(
            "An error occurred",
            "Error:",
            "Cannot parse"
        )

        for ($i = 0; $i -lt $snowfakery_error_message_strings.Count; $i++) {
            
            $error_message = $snowfakery_error_message_strings[$i];
            if ( $snowfakery_results -match $error_message) {
                Write-Error "SNOWFAKERY GENERATION FAILED"
                Write-Error $snowfakery_results
                throw "EXITING APPLY DATA CONFIG"
            }
        }

        Write-Host "`nCREATE ORDERED DATA UPSERTS DIRECTORY" 
        $data_order_folder_name = "ordered_data_plan"
        Write-Host "`nMOVE ORDERED CSVW_METADATA.JSON FILE TO ORDERED PLAN DIRECTORY"
        New-Item "$path_to_data_folder\$data_order_folder_name" -ItemType Directory        
        $data_order_file = Get-ChildItem $path_to_data_folder -Filter "*.json"
        Move-Item -Path $data_order_file -Destination "$path_to_data_folder\$data_order_folder_name" | Out-Null


        Write-Host "`nin data directory: map each csv file to data object"
        $csv_files = Get-ChildItem -Filter *.csv $path_to_data_folder
        foreach ($csv_file in $csv_files) {
            $filename_split = $csv_file.name -split '\.csv'
            $data_type_name = $filename_split[0]
            $data_as_csv = get-content -raw $csv_file.fullname
            $data_as_object = ConvertFrom-Csv -InputObject $data_as_csv
            ### commenting out for now to keepcsvs entact Remove-Item -Force $csv_file.fullname | Out-Null
            $data_as_json = $data_as_object | ConvertTo-Json
            $data_as_json | Out-File "$raw_data_path/$data_type_name.json"
            ### MOVE ORIGINATING CSV FILE TO RAW DATA FILES
            Move-Item -Path $csv_file -Destination "$raw_data_path/$($csv_file.name)" | Out-Null
        }


    }

}

function apply_data_config {
    param($data_config, $path_project_directory, $org_alias)

    # ENSURE THAT $ORG_ALIAS IS AUTHENTCATED
    $sfdx_connection_detail = check_and_set_sfdx_connection_by_org_alias $org_alias
    
    if ( $null -eq $sfdx_connection_detail) {
        Write-Error -Message "ERROR: ORG ALIAS NOT AUTHENTICATED: '$org_alias'"
    }

    # ENSURE THAT *GENERATED ORG DATA SEEDING DIRECTORY* IS CONFIGURED CORRECTLY
    $path_to_generated_org_data_seeding_directory = "$path_project_directory/$($data_config.path_to_generated_org_data_seeding)"
    $generated_org_data_seeding_directory_exists = Test-Path $path_to_generated_org_data_seeding_directory
    if (-not $generated_org_data_seeding_directory_exists) {
        New-Item -Type Directory $path_to_generated_org_data_seeding_directory | Out-Null
    }

    # ENSURE $PATH_PROJECT_DIRECTORY IS SET UP
    $path_project_directory_not_defined = [string]::IsNullOrWhiteSpace($path_project_directory)
    $path_project_directory_does_not_exist = -not (Test-Path $path_project_directory)
    if ($path_project_directory_not_defined -or $path_project_directory_does_not_exist) {
        Write-Host '$PATH_PROJECT_DIRECTORY PROVIDED WAS NOT vaLID - USING LOCAL DIRECTORY'
        $path_project_directory = (Get-Location).path
    }

    # IMPORT DATA - EITHER REUSE EXISTING OR GENERATE NEW
    $use_existing_is_defined = -not ([string]::IsNullOrWhiteSpace($data_config.use_existing))
    if ($use_existing_is_defined -and ($data_config.use_existing -eq 'true')) {
        # TODO - this block needs attention
        Write-Host 'USE EXISTING DATA'
        # ensure that existing data directory is configured correctly
        $datetime_stamp = $data_config.reuse_datetime_stamp
        $reuse_datetime_stamp_is_undefined_or_empty = [string]::IsNullOrWhiteSpace($datetime_stamp)
        if ($reuse_datetime_stamp_is_undefined_or_empty) {
            # Ensure that $data_config.reuse_datetime_stamp is defined
            Write-Error -Message 'ERROR: REUSE_DATETIME_STAMP NOT DEFINED' -ErrorAction Stop
        }

        $folders_within_existing_data_folder = Get-ChildItem -Directory $path_to_generated_org_data_seeding_directory -filter "*$datetime_stamp*"
        if ($folders_within_existing_data_folder.count -lt 1) {
            # Ensure that $path_to_generated_snowfakery_directory contains some matching subfolders
            Write-Error -Message "ERROR: EXISTING DATA DIRECTORY CONTAINS NO MATCHING SUBFOLDERS: '$path_to_generated_snowfakery_directory'" -ErrorAction Stop
        }
        else {
            # Write-Host 'RUNNING REUSE_GENERATED_DATA'
            reuse_generated_data -datetime_stamp ($data_config.reuse_datetime_stamp) -org_alias $org_alias -path_to_generated_dataset_directory $path_to_generated_org_data_seeding_directory
        }
    }
    else {
        # Write-Host 'GENERATE NEW DATA'

        $path_to_recipes_is_defined = -not ([string]::IsNullOrWhiteSpace($data_config.path_to_recipes))
        $path_to_recipes_folder = "$path_project_directory/$($data_config.path_to_recipes)"
        $recipes_directory_exists = Test-Path $path_to_recipes_folder
        if (-not $path_to_recipes_is_defined) {
            # Ensure that $data_config.path_to_recipes is defined
            Write-Error -Message 'ERROR: PATH_TO_RECIPES NOT DEFINED' -ErrorAction Stop
        }
        elseif (-not $recipes_directory_exists) {
            # Ensure that $path_to_recipes_folder does exist
            Write-Error -Message "ERROR: RECIPES DIRECTORY DOES NOT EXIST: '$path_to_recipes_folder'" -ErrorAction Stop
        }
        else {
            Write-Host 'Generating New Data from Recipes'
            $datetime_label = ([datetime]::now).ToString('yyyyMMdd-HHmm')
            $recipe_files = Get-ChildItem $path_to_recipes_folder -filter *.yml

            if ( $recipe_files.count -eq 0 ) {
                Write-Error "###################################################"
                Write-Error "NO RECIPE FILE FOUND IN $path_to_recipes_folder"
                Write-Error "###################################################"
                Throw
            }
            foreach ($recipe_file in $recipe_files) {
                $recipe_name = ($recipe_file.name -split '\.yml')[0]
                $path_to_recipe = $recipe_file.fullname
                $path_to_generated_directory = "$path_to_generated_org_data_seeding_directory/$($datetime_label)_$recipe_name"

                # Ensure $output_directory_does_not_exist directory exists
                $output_directory_does_not_exist = -not (Test-Path $path_to_generated_directory)
                if ($output_directory_does_not_exist) {
                    New-Item -Type Directory $path_to_generated_directory | Out-Null
                }

                Write-Host "apply_recipe -path_to_recipe_yml '$path_to_recipe' -path_to_data_folder '$path_to_generated_directory'"
                
                $stopwatch_apply_recipe = [System.Diagnostics.Stopwatch]::new()
                $stopwatch_apply_recipe.start() | Out-Null

                ### RAW DATA FILES DIRECTORY WILL CONTAIN RAW CSV AND JSON FILES OF THE DATA GENERATED FROM SNOWFAKERY
                ### THIS DIRECTORY IS MEANT TO KEEP THEM ORGANIZED FROM OTHER DATA ARTIFACTS
                $raw_data_folder_name = "raw_data_files"
                $raw_data_path = "$path_to_generated_directory/$raw_data_folder_name"
                New-Item -ItemType Directory -Path $raw_data_path

                apply_recipe -path_to_recipe_yml $path_to_recipe -path_to_data_folder $path_to_generated_directory -org_alias $org_alias -raw_data_path $raw_data_path
                $stopwatch_apply_recipe.stop() | Out-Null
                $elapsed_seconds_apply_recipe = $stopwatch_apply_recipe.ElapsedMilliseconds / 1000
                Write-Host "`SNOWFAKERY DATA GENERATION COMPLETED IN $elapsed_seconds_apply_recipe SECONDS`n"

                $stopwatch_intialize_data_directory = [System.Diagnostics.Stopwatch]::new()
                $stopwatch_intialize_data_directory.start() | Out-Null
                intialize_data_directory -path_to_generated_directory $path_to_generated_directory -raw_data_path $raw_data_path
                $stopwatch_intialize_data_directory.stop() | Out-Null
                $elapsed_seconds_intialize_data_directory = $stopwatch_intialize_data_directory.ElapsedMilliseconds / 1000
                Write-Host "`ndataset DATA GENERATION COMPLETED IN $elapsed_seconds_intialize_data_directory SECONDS`n"

                Write-Host "IMPORT ATTEMPT - START - $path_to_generated_directory"
                perform_dataset_upsert -org_alias $org_alias `
                                        -path_to_dataset_json $path_to_generated_directory `
                                        -originating_recipe_file $recipe_file
               
            }
        }
    }
}


function perform_dataset_upsert {
    param(
       $org_alias,
       $path_to_dataset_json,
       $originating_recipe_file
    )

    $text_art = get_random_text_art

    Push-Location $path_to_dataset_json

        $upsert_stopwatch_apply_recipe = [System.Diagnostics.Stopwatch]::new()
        $upsert_stopwatch_apply_recipe.start() | Out-Null

        try {

            upsert_saleforce_data_files -target_org $org_alias `
                                            -allornone $false `
                                            -path "." `
                                            -originating_recipe_file $originating_recipe_file

            Write-Host -ForegroundColor Yellow "################################################################################################################"
            Write-Host -ForegroundColor Yellow "################################################################################################################"
            Write-Host -ForegroundColor Green "SUCCESSFUL IMPORTED DIRECTORY: $path_to_dataset_json"
            Write-Host `n
            Write-Host -ForegroundColor Black -BackgroundColor White "$text_art"
            Write-Host `n
            Write-Host -ForegroundColor Yellow "################# ----- JSON RESULTS ------- ###############"
            Write-Host -ForegroundColor Gray "$dataset_import_json"
            Write-Host -ForegroundColor Yellow "################################################################################################################"
            Write-Host -ForegroundColor Yellow "################################################################################################################"


        }
        catch {

            if($_.ErrorDetails.Message) {
                Write-Error "ERROR UPSERTING RECIPE: $originating_recipe_file : $($_.ErrorDetails.Message)"
            } else {
                Write-Error "ERROR UPSERTING RECIPE: $originating_recipe_file : $_"
            }
     
            Throw "ERROR UPSERTING THE DATA FILES"

        }
                

        $upsert_stopwatch_apply_recipe.stop() | Out-Null
        
        $elapsed_seconds = $upsert_stopwatch_apply_recipe.ElapsedMilliseconds/1000
        Write-Host "DATA UPSERTING TIME TOOK $elapsed_seconds SECONDS"
        
    Pop-Location
    Write-Host "IMPORT ATTEMPT - END - $path_to_dataset_json"

} 

function upsert_saleforce_data_files {
    param(
        $target_org,
        $allornone,
        $path,
        $originating_recipe_file
    ) 

    <#
        FROM import.ts from dataset
        # let recTypeInfos = new Map<string, string>();
        # // Get Record Types information with newly generated Ids
        # recTypeInfos = await this.getRecordTypeMap(sobjectName);

        EXPLANATION: Capturing record type ids associated with human readable record type
        developer names listed in the recipes. It doesn't matter which org we are using, we don't 
        care about the different record type Id's needed, just give me the Id when I give you 
        the record type api developer name
    #>
    $sobject_to_record_type_developer_name_to_id_map = @{}
    $reference_id_to_associated_lookup_record_id_map = @{}
    $sobject_to_lookups_map = @{}

    <#
        TO ENSURE CORRECT FILES AND CORRECT ORDER OF FILES ARE PROCESSED:
        - ONLY CAPTURE JSON FILES
        - SORT BY CREATION TIME BECAUSE THEY WERE CREATED IN THE CORRECT ORDER
        - ONLY CAPTURE FILES THAT HAVE A NUMBER THAT STARTSS OFF THE FILE NAME
    #>
    $start_of_string_regex_pattern = "^"
    $number_match_regex_pattern = "\d"
    $regex_pattern = $start_of_string_regex_pattern + $number_match_regex_pattern
    $ordered_data_files_to_upsert = $(Get-ChildItem $path -Filter *.json | Sort-Object CreationTime | Where-Object { $_.Name -match "$regex_pattern" })
    if ( $ordered_data_files_to_upsert.count -eq 0 ) {
        Throw "THERE WERE NO DATA FILES FOUND FOR UPSERTING"
    }

    <# 
        CREATE NEW RECIPE_APPLICATION_RESULTS FOLDER FOR THE CURRENT RUN
    #>
    $applied_recipe_run_results_path = "recipe_application_results"
    New-Item -ItemType Directory -Name $applied_recipe_run_results_path

    if ( $null -ne $originating_recipe_file ) {
        Copy-Item $originating_recipe_file -Destination "." | Out-Null
    }

    foreach ( $data_file in $ordered_data_files_to_upsert ) {

        $sobject_api_name = $null
        if ( -not($data_file -is [System.IO.DirectoryInfo]) ) {
            $sobject_api_name = get_sobject_api_name_by_file -data_file $data_file
        } else {
            continue
        }

        if ( -not($sobject_to_record_type_developer_name_to_id_map.ContainsKey($sobject_api_name)) ) {
            $sobject_to_record_type_developer_name_to_id_map = update_sobject_to_record_type_developer_name_to_id_map -sobject_to_record_type_developer_name_to_id_map $sobject_to_record_type_developer_name_to_id_map -sobject_api_name $sobject_api_name
        }
        $sobject_to_associated_lookups = update_sobject_to_lookups_by_sobject_api_name -sobject_api_name $sobject_api_name -sobject_to_lookups_map $sobject_to_lookups_map
        $lookup_fields = $sobject_to_associated_lookups[$sobject_api_name]
        
        $prepared_data = prepare_data_files_for_upsert -data_file $data_file `
                            -reference_id_to_associated_lookup_record_id_map $reference_id_to_associated_lookup_record_id_map `
                            -lookup_fields $lookup_fields `
                            -record_type_developer_name_to_record_type_id_map $sobject_to_record_type_developer_name_to_id_map[$sobject_api_name]
                            
        $upserted_records_results = upsert_prepared_data -prepared_data $prepared_data `
                                                            -sobject_api_name $sobject_api_name `
                                                            -applied_recipe_run_results_path $applied_recipe_run_results_path

        $reference_id_to_associated_lookup_record_id_map = update_reference_id_to_associated_record_id_map -reference_id_to_associated_lookup_record_id_map $reference_id_to_associated_lookup_record_id_map `
                                                                     -upserted_records_results $upserted_records_results `
                                                                     -prepared_data_for_capturing_index_to_reference_id $prepared_data


    }

} 

function get_sobject_api_name_by_file {
    param( $data_file ) 

    $file_path = $data_file.Name

    if ( $file_path.IndexOf("-") -eq -1 -or $file_path.IndexOf(".json") -eq -1 ) {
        Write-Error "INvaLID FILE NAME AT: $($file_path.Name)"
    }
    
    $sobject_name_from_file = $file_path.indexOf("-")
    $sobject_name_from_file = $file_path.Split("-")[1]

    $sobject_name_from_file
}

function update_sobject_to_lookups_by_sobject_api_name {
    param(
        $sobject_api_name,
        $sobject_to_lookups_map
    )

    if ( -not($sobject_to_lookups_map.ContainsKey($sobject_api_name)) ) {

        $sobject_describe = get_object_describe_by_object -sobject_api_name $sobject_api_name
        $sobject_lookup_fields = parse_field_lookup_detail_from_object_describe -sobject_describe $sobject_describe

        $sobject_to_lookups_map.Add($sobject_api_name, $sobject_lookup_fields ) | Out-Null
    } 

    $sobject_to_lookups_map
   
}

function get_sfdx_connection_detail {

    $base64_environment_sfdx_connection_detail = $env:SFDX_CONNECTION
    $decoded_base64_sfdx_connection = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($base64_environment_sfdx_connection_detail))
    $sfdx_connection_detail = $decoded_base64_sfdx_connection | ConvertFrom-Json
    
    if ( [string]::IsNullOrEmpty($sfdx_connection_detail) `
        -or ([string]::IsNullOrEmpty($sfdx_connection_detail.access_token)) `
        -or ([string]::IsNullOrEmpty($sfdx_connection_detail.instance_url)) `
        -or ([string]::IsNullOrEmpty($sfdx_connection_detail.api_version)) ) {

        Write-Error "THE AUTHENTICATION DATA HAS NOT BEEN POPULATED"
        Throw
    }

    $sfdx_connection_detail

}

function get_object_describe_by_object {
    param( $sobject_api_name )

    $sfdx_connection_detail = get_sfdx_connection_detail

    $sobject_describe_uri = "$($sfdx_connection_detail.instance_url)/services/data/v$($sfdx_connection_detail.api_version)/sobjects/$sobject_api_name/describe"
    $method = "GET"
    $content_type = "application/json"

    Try {

        $rest_call_result = $(
        Invoke-RestMethod -URI $sobject_describe_uri `
            -ContentType $content_type `
            -Method $method `
            -Headers @{ 
                "Authorization" = "OAuth " + $($sfdx_connection_detail.access_token);"Accept"="application/json"
            }
        )

    } Catch {

       if($_.ErrorDetails.Message) {
           Write-Error "ERROR GETTING SOBJECT DESCRIBE DATA. THIS OBJECT MORE THAN LIKELY DOES NOT EXIST ON THE TARGET ORG: $sobject_api_name : $($_.ErrorDetails.Message)"
       } else {
           Write-Error "ERROR GETTING SOBJECT DESCRIBE DATA. THIS OBJECT MORE THAN LIKELY DOES NOT EXIST ON THE TARGET ORG: $sobject_api_name  : $_"
       }

       Throw "GET SOBJECT RETRIEvaL FAILED FOR $sobject_api_name"

    }

    $rest_call_result

}

function parse_field_lookup_detail_from_object_describe {
    param( $sobject_describe )

    $field_lookups = [system.collections.generic.list[PSCustomObject]]::new()
    foreach ( $field in $sobject_describe.fields ) {

        if ( $field.createable -and -not( [string]::IsNullOrEmpty($field.referenceTo)) ) {
            $field_lookups.Add( $field ) | Out-Null
        }
    }

    $field_lookups
    
}

function prepare_data_files_for_upsert {
    param(
        $data_file,
        $reference_id_to_associated_lookup_record_id_map,
        $lookup_fields,
        $record_type_developer_name_to_record_type_id_map
    )

    $data_file_content_json = Get-Content $data_file
    $data = $data_file_content_json | ConvertFrom-Json  

    foreach ( $record in $data.records) {

        foreach ( $lookup in $lookup_fields ) {

            $lookup_field_api_name = $lookup.name
            $lookup_field_value = $record.$lookup_field_api_name
            if ( $null -ne $lookup_field_value) {

                $expected_reference_trailing_text = "Ref"
                if ( $lookup_field_value -like "*$expected_reference_trailing_text*") {
                    $record.$lookup_field_api_name = $reference_id_to_associated_lookup_record_id_map[$record.$lookup_field_api_name]
                }
                
            }

        }

        ### REPLACE REFERENCES OF RECORD TYPE DEVELOPER NAME WITH ASSOCIATED RECORD TYPE ID FOR 
        ### TARGETED ORG (IF EXISTS)
        if ( $null -eq $record.RecordTypeId -and $record_type_developer_name_to_record_type_id_map.count -gt 0 ) {
            $record.RecordTypeId = $record_type_developer_name_to_record_type_id_map[$record.RecordTypeId]
        }
    
        # IF OBJECT WAS ALREADY INSERTED, ADD ID FIELD TO TREAT IT AS AN UPSERT
        $reference_id = $record.attributes.referenceId
        if ( $reference_id_to_associated_lookup_record_id_map.ContainsKey($reference_id) ) {
            ### DYNAMICALLY ADD EMPTY ID FIELD FOR UPSERTS
            $record | Add-Member -NotePropertyName Id -NotePropertyvalue ""
            $existing_record_id_from_previous_run = $reference_id_to_associated_lookup_record_id_map[$reference_id]
            $record.Id = $existing_record_id_from_previous_run 
        }
    
    }

    $data

}

function upsert_prepared_data {
    param(
        $prepared_data,
        $sobject_api_name,
        $applied_recipe_run_results_path
    )

    <#
    
        THE UPSERT COLLECTION SALEFORCE API ENDPOINT REQUIRES A NONSENSICAL EXTERNAL ID THAT WE DO NOT NEED OR HAVE TIME TO ADD AND MAINTAIN TO EVERY OBJECT EVER....
        THERFORE WE NEED TO IDENTIFY WHICH RECORDS ARE GOING TO BE UPDATES VS INSERTS
    
    #>

    $insert_records = [system.collections.generic.list[PSCustomObject]]::new()
    $update_records = [system.collections.generic.list[PSCustomObject]]::new()
    foreach ( $record in $prepared_data.records ) {

        if ( -not([string]::IsNullOrEmpty( $record.Id )) ) {
            # IF AN EXISTING ID LIVES ON THE RECORD THEN IT WILL BE AN UPDATE

            $update_records.Add($record) | Out-Null

        } else {

            $insert_records.Add($record) | Out-Null

        }
    }

    $saved_records_callout_results = [system.collections.generic.list[PSCustomObject]]::new()
    if ( $update_records.count -gt 0 ) {

        $updated_records_results = [system.collections.generic.list[PSCustomObject]](update_saleforce_records -update_records $update_records -sobject_api_name $sobject_api_name -applied_recipe_run_results_path $applied_recipe_run_results_path)
        $saved_records_callout_results.AddRange($updated_records_results) | Out-Null

    }
    
    if ( $insert_records.count -gt 0 ) {

        $inserted_records_results = [system.collections.generic.list[PSCustomObject]](insert_saleforce_records -insert_records $insert_records -sobject_api_name $sobject_api_name -applied_recipe_run_results_path $applied_recipe_run_results_path)
        $saved_records_callout_results.AddRange($inserted_records_results) | Out-Null

    }

    $saved_records_callout_results

}

function update_saleforce_records {
    param( $update_records, $sobject_api_name, $applied_recipe_run_results_path ) 

    $method = "PATCH"
   
    $update_batch_results = make_collections_rest_api_call_by_method -method $method -records $update_records
    
    $failed_saves = $update_batch_results | Where-Object { $_.success -eq $false } 

    if ( $failed_saves.count -ne $update_batch_results.count ) {
        $success_results = $update_batch_results | Where-Object { $_.success -eq $true } 
        update_success_results -save_results $success_results `
                                -sobject_api_name $sobject_api_name `
                                -method $method `
                                -applied_recipe_run_results_path $applied_recipe_run_results_path
    } else {
        Write-Error "$($failed_saves.count) FAILED"
    }
                                            
    if ( $failed_saves.count -gt 0 ) {

        output_failed_save_results -failed_saves $failed_saves `
                                    -sobject_api_name $sobject_api_name `
                                    -applied_recipe_run_results_path $applied_recipe_run_results_path `
                                    -method $method

        Throw "$method IMPORT FAILED"
    }

    $update_batch_results
  
}

function insert_saleforce_records {
    param( $insert_records, $sobject_api_name, $applied_recipe_run_results_path ) 

    $method = "POST"
   
    $insert_batch_results = make_collections_rest_api_call_by_method -method $method -records $insert_records
    
    $failed_saves = $insert_batch_results | Where-Object { $_.success -eq $false } 

    if ( $failed_saves.count -ne $insert_batch_results.count ) {
        $success_results = $insert_batch_results | Where-Object { $_.success -eq $true } 
        update_success_results -save_results $success_results `
                                -sobject_api_name $sobject_api_name `
                                -method $method `
                                -applied_recipe_run_results_path $applied_recipe_run_results_path
    }

                                            
    if ( $failed_saves.count -gt 0 ) {

        output_failed_save_results -failed_saves $failed_saves `
                                    -sobject_api_name $sobject_api_name `
                                    -applied_recipe_run_results_path $applied_recipe_run_results_path `
                                    -method $method

        Throw "$method IMPORT FAILED"
    }

    $insert_batch_results
  
}

function update_success_results {
    param( 
        $save_results, 
        $sobject_api_name, 
        $applied_recipe_run_results_path,
        $method
    )

    $save_results_json = $save_results | ConvertTo-Json -Depth 12

    Write-Host -ForegroundColor Green -BackgroundColor White "$($save_results.count) SAVED RESULTS DETAILS AT $($applied_recipe_run_results_path)" 
    update_result_file_by_sobject_and_outcome -sobject_api_name $sobject_api_name `
                                                                    -new_save_json_results $save_results_json `
                                                                    -save_outcome "SUCCESS" `
                                                                    -results_path $applied_recipe_run_results_path


}

function output_failed_save_results {
    param( 
        $failed_saves, 
        $sobject_api_name, 
        $applied_recipe_run_results_path,
        $method
    )

    $failed_saves_json = $failed_saves | ConvertTo-Json -Depth 12
    Write-Error "FAILED $method INSERTS FOR $sobject_api_name :"
    Write-Error "########### ERRORS START $sobject_api_name #############"

    for ($i = 0; $i -lt $failed_saves.Count; $i++) {

        Write-Host -ForegroundColor Yellow "--------- $i ERROR START  -----------`n"

        Write-Host -ForegroundColor Red -BackgroundColor White "SOBJECT:" -NoNewline
        Write-Host -ForegroundColor Red "  $($sobject_api_name)"

        Write-Host -ForegroundColor Red -BackgroundColor White  "FIELD:" -NoNewline
        Write-Host -ForegroundColor Red "  $($failed_saves[$i].errors.fields)"

        Write-Host -ForegroundColor Red -BackgroundColor White "ERROR CODE:" -NoNewline
        Write-Host -ForegroundColor Red "  $($failed_saves[$i].errors.statusCode)"

        Write-Host -ForegroundColor Red -BackgroundColor White "MESSAGE:" -NoNewline
        Write-Host -ForegroundColor Red "  $($failed_saves[$i].errors.message) `n"

        Write-Host -ForegroundColor Yellow "--------- $i ERROR END  -----------`n"

    }

    Write-Host -ForegroundColor Red -BackroundColor White "TOTAL FAILED SAVES: $($failed_saves.count)"

    Write-Error "########### ERRORS END $sobject_api_name #############"

    update_result_file_by_sobject_and_outcome -sobject_api_name $sobject_api_name `
                                                -new_save_json_results $failed_saves_json `
                                                -save_outcome "FAIL" `
                                                -results_path $applied_recipe_run_results_path

}

function update_result_file_by_sobject_and_outcome {
    param(
        $sobject_api_name,
        $results_path,
        $new_save_json_results,
        $save_outcome
    )

    if ( $save_outcome -eq "FAIL" ) {

        $expected_file_name_by_sobject_api_name = "$results_path/$($sobject_api_name)--ERROR_RESULTS.json"

        if ( Test-Path $expected_file_name_by_sobject_api_name ) {
            <#
                IF RESULTS FILE ALREADY EXISTS, GET CONTENT ADD TO LATEST BATCH OF JSON RESULTS, THEN OVERWRITE FILE WITH COMBINED RESULTS
            #>
            $existing_sobject_failures_json = Get-Content $expected_file_name_by_sobject_api_name
            $existing_failed_saves = $existing_sobject_failures_json | ConvertFrom-Json
            $new_failed_saves = $new_save_json_results | ConvertFrom-Json

            $all_failed_saves = ( $existing_failed_saves + $new_failed_saves )
            $all_failed_results_json = $all_failed_saves | ConvertTo-Json

            $all_failed_results_json | Out-File -FilePath $expected_file_name_by_sobject_api_name

        } else {

            $new_save_json_results | Out-File -FilePath $expected_file_name_by_sobject_api_name

        }

    } else {

        $expected_file_name_by_sobject_api_name = "$results_path/$($sobject_api_name)--SUCCESS_RESULTS.json"

        if ( Test-Path $expected_file_name_by_sobject_api_name ) {
            <#
                IF RESULTS FILE ALREADY EXISTS, GET CONTENT ADD TO LATEST BATCH OF JSON RESULTS, THEN OVERWRITE FILE WITH COMBINED RESULTS
            #>
            $existing_sobject_successes_json = Get-Content $expected_file_name_by_sobject_api_name
            $existing_sobject_saves = $existing_sobject_successes_json | ConvertFrom-Json
            $new_success_saves = $new_save_json_results | ConvertFrom-Json

            $all_successful_save_results = ( $existing_sobject_saves + $new_success_saves )
            $all_successful_results_json = $all_successful_save_results | ConvertTo-Json

            $all_successful_results_json | Out-File -FilePath $expected_file_name_by_sobject_api_name

        } else {

            $new_save_json_results | Out-File -FilePath $expected_file_name_by_sobject_api_name

        }

    }

}

function make_collections_rest_api_call_by_method {
    param(
        $method,
        $records
    )

    
    <# FOR POST (INSERT) EXPECTED EXAMPLE BODY (https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_composite_sobjects_collections_create.htm)
    # {
    #     "allOrNone" : false,
    #     "records" : [{
    #        "attributes" : {"type" : "Account"},
    #        "Name" : "example.com",
    #        "BillingCity" : "San Francisco"
    #     }, {
    #        "attributes" : {"type" : "Contact"},
    #        "LastName" : "Johnson",
    #        "FirstName" : "Erica"
    #     }]
    #  }
    #>

    <# FOR PATCH (UPDATE) EXPECTED EXAMPLE BODY (https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_composite_sobjects_collections_update.htm)
    #   {
    #       "allOrNone" : false,
    #       "records" : [
                    {
    #                   "attributes" : {"type" : "Account"},
    #                   "id" : "001xx000003DGb2AAG",
    #                   "NumberOfEmployees" : 27000
    #               },
    #               {
    #                    "attributes" : {"type" : "Contact"},
    #                    "id" : "003xx000004TmiQAAS",
    #                    "Title" : "Lead Engineer"
    #               }
    #       ]
    #   }
    #>

    $sfdx_connection_detail = get_sfdx_connection_detail
    
    $content_type = "application/json"
    $save_collection_records_uri = "$($sfdx_connection_detail.instance_url)/services/data/v$($sfdx_connection_detail.api_version)/composite/sobjects"

    $save_batch_results = [system.collections.generic.list[PSCustomObject]]::new()

    $batch_size_allowable_for_collections_api_endpoint = 200
    for ($i = 0; $i -lt $records.Count; $i += $batch_size_allowable_for_collections_api_endpoint ) {

        $batch_chunk_records_to_save = $records | Select-Object -Skip $i -First $batch_size_allowable_for_collections_api_endpoint

        ### BELOW $chunk_records CUSTOM OBJECT NEEDED TO RECREATE THE EXPECTED
        ### JSON STRUCTURE FOR THE COMPOSITE API ENDPOINT
        if ( $batch_chunk_records_to_save.count -eq 1 ) {
            ### ENSURE TYPE IS TREATED LIKE ARRAY IN ORDER TO CONVERT CORRECTLY TO JSON FOR ENDPOINT CALLOUT
            $batch_chunk_records_to_save = [PSCustomObject[]]$batch_chunk_records_to_save
        }

        #### GET CORRECT OBJECT STRUCTURE THAT WILL CONVERT TO EXPECTED REQUEST BODY JSON
        $records_to_save = [PSCustomObject]@{
            allOrNone = "false"
            records = $batch_chunk_records_to_save
        }
        $chunk_records_json = $records_to_save | ConvertTo-Json -Depth 12
    
        Try {

            $collections_save_rest_call_result = $(
                Invoke-RestMethod -URI $save_collection_records_uri `
                    -ContentType $content_type `
                    -Body $chunk_records_json `
                    -Method $method `
                    -Headers @{ 
                        "Authorization" = "OAuth " + $($sfdx_connection_detail.access_token);"Accept"="application/json"
                    }
            )  

        } Catch {

           if($_.ErrorDetails.Message) {
               Write-Error "Error importing records: $($_.ErrorDetails.Message)"
           } else {
               Write-Error "Error importing records: $_"
           }

           Throw "IMPORT FAILED"

        }

        $collections_save_rest_call_result = [system.collections.generic.list[PSCustomObject]]($collections_save_rest_call_result)
        $save_batch_results.AddRange($collections_save_rest_call_result) | Out-Null

    }

    $save_batch_results

}



function update_reference_id_to_associated_record_id_map {
    param(
        $upserted_records_results,
        $reference_id_to_associated_lookup_record_id_map,
        $prepared_data_for_capturing_index_to_reference_id
    )

    $record_index = 0
    ### ENSURE RESULTS TYPE IS OF LIST; POWERSHELL AUTO CASTS WHEN PASSING LIST vaRIABLES THAT HAVE ONLY 1 ITEM IN THE COLLECTION
    $upserted_records_results = [PSCustomObject[]]$upserted_records_results
    $prepared_data_for_capturing_index_to_reference_id = [PSCustomObject[]]$prepared_data_for_capturing_index_to_reference_id
    foreach ( $completed_data_upsert_result in $upserted_records_results ) {

        $record_id = $completed_data_upsert_result.Id
        $reference_id = $prepared_data_for_capturing_index_to_reference_id.records[$record_index].attributes.referenceId

        if ( -not($reference_id_to_associated_lookup_record_id_map.ContainsKey($reference_id)) ) {

            $reference_id_to_associated_lookup_record_id_map.Add( $reference_id, $record_id) | Out-Null

        } 

        $record_index++
    }

    $reference_id_to_associated_lookup_record_id_map

}

function update_sobject_to_record_type_developer_name_to_id_map {
    param(
        $sobject_to_record_type_developer_name_to_id_map,
        $sobject_api_name
    )

    $record_type_query_string = "SELECT+Id,DeveloperName+FROM+RecordType+WHERE+SObjectType+=+'`"$sobject_api_name`"'"

    $sfdx_connection_detail = get_sfdx_connection_detail

    $sobject_record_type_query_uri = "$($sfdx_connection_detail.instance_url)/services/data/v$($sfdx_connection_detail.api_version)/queryAll/?q=$record_type_query_string"
    $method = "GET"
    $content_type = "application/json"

    Try {

        $record_type_rest_call_result = $(
            Invoke-RestMethod -URI $sobject_record_type_query_uri -ContentType $content_type `
                -Method $method `
                -Headers @{ 
                    "Authorization" = "OAuth " + $($sfdx_connection_detail.access_token);"Accept"="application/json"
                }
        )

    } Catch {

       if($_.ErrorDetails.Message) {
           Write-Error "ERROR CALLING SOQL FOR RECORD TYPE DETAIL ON SOBJECT $sobject_api_name : $($_.ErrorDetails.Message)"
       } else {
           Write-Error "ERROR CALLING SOQL FOR RECORD TYPE DETAIL ON SOBJECT $sobject_api_name : $_"
       }

       Throw "RECORD TYPE RETRIEvaL FAILED FOR $sobject_api_name"

    }

    $record_type_developer_name_to_record_type_id_map = @{}
    
    if ( $record_type_rest_call_result.records.count -eq 0 ) {
        Write-Host -ForegroundColor Yellow "THERE WERE NO RECORD TYPES RETRIEVED FROM $sobject_api_name. THIS OBJECT MAY NOT EXIST YET ON THE TARGET ORG."
    }

    foreach ( $record_type in $record_type_rest_call_result.records ) {
        $record_type_developer_name_to_record_type_id_map.Add($record_type.DeveloperName, $record_type.Id) | Out-Null
    }

    $sobject_to_record_type_developer_name_to_id_map.Add($sobject_api_name, $record_type_developer_name_to_record_type_id_map) | Out-Null

    $sobject_to_record_type_developer_name_to_id_map

}

function get_take_my_money_art {

    $take_money = @"

    
                                                ─────███────██
                                                ──────████───███
                                                ────────████──███
                                                ─────────████─█████
                                                ████████──█████████
                                                ████████████████████
                                                ████████████████████
                                                █████████████████████
                                                █████████████████████
                                                █████████████████████
                                                ██─────██████████████
                                                ███────────█████████
                                                █──█───────────████
                                                █──────────────██
                                                ██──────────────█────────▄███████▄
                                                ██───███▄▄──▄▄███──────▄██$█████$██▄
                                                ██──█▀───▀███────█───▄██$█████████$██▄
                                                ██──█───█──██───█─█──█$█████████████$█
                                                ██──█──────██─────█──█████████████████
                                                ██──██────██▀█───█─────██████████████
                                                ─█───██████──▀████───────███████████
                                                ──────────────────█───────█████████
                                                ─────────────▀▀████──────███████████
                                                ────────────────█▀──────██───████▀─▀█
                                                ────────────────▀█──────█─────▀█▀───█
                                                ──▄▄▄▄▄▄▄────────██────█───████▀───██
                                                ─█████████████────▀█──█───███▀──▄▄██
                                                ─█▀██▀██▀████▀█████▀──█───██████▀─▀█
                                                ─█────────█▄─────────██───████▀───██
                                                ─██▄████▄──██────────██───██──▄▄▄██
                                                ──██▄▄▄▄▄██▀─────────██──█████▀───█
                                                ─────────███────────███████▄────███
                                                ────────███████─────█████████████
                                                ───────▄██████████████████████
                                                ████████─██████████████████
                                                ─────────██████████████
                                                ────────███████████
                                                ───────█████
                                                ──────████
                                                ─────████

"@

    $take_money
}

function get_random_text_art {

    $text_art_collection = [system.collections.generic.list[string]]::new()

    $wreck_it = get_wreck_it_text_art
    $text_art_collection.add($wreck_it) | Out-Null

    $wick = get_john_wick_text_art
    $text_art_collection.add($wick) | Out-Null

    $take_money = get_take_my_money_art
    $text_art_collection.add($take_money) | Out-Null

    $random_art_index = Get-Random -Maximum ($text_art_collection.count -1)
    $text_art = $text_art_collection[$random_art_index]
    $text_art

}
function get_john_wick_text_art {
    $wick = @"

                                            ⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣀⣀⣀⣀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀
                                            ⠀⠀⠀⠀⠀⢀⣴⣾⣿⣿⣿⣿⣿⣿⣿⣿⣷⣦⡀⠀⠀⠀⠀⠀
                                            ⠀⠀⠀⢀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⠀⠀⠀⠀
                                            ⠀⠀⢀⣾⣿⣿⣿⣿⡿⠿⠿⣿⣿⠿⠿⢿⣿⣿⣿⣿⣧⡀⠀⠀
                                            ⠀⠀⣾⣿⣿⣿⣿⠏⠀⠀⠀⠈⠁⠀⠀⠀⠹⣿⣿⣿⣿⣧⠀⠀
                                            ⠀⣸⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⣿⣿⣿⣿⡆⠀
                                            ⠀⣿⣿⣿⣿⣿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⣿⣿⣿⣿⣿⠀
                                            ⢠⣿⣿⣿⣿⡇⠈⠛⣿⡟⠀⠀⠀⠀⢻⣿⠛⠁⢸⣿⣿⣿⣿⡀
                                            ⢸⣿⣿⣿⣿⣇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⣿⣿⣿⣿⡇
                                            ⠸⣿⣿⣿⣿⣿⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⣿⣿⣿⣿⣿⠁
                                            ⠀⣿⣿⣿⣿⣿⣿⠀⢠⣶⣿⣿⣿⣿⣶⡄⠀⣿⣿⣿⣿⣿⣿⠀
                                            ⠀⠘⣿⣿⣿⣿⣿⡄⢸⡟⠋⠉⠉⠙⢻⡇⢠⣿⣿⣿⣿⣿⠃⠀
                                            ⠀⠀⠈⠛⠿⣿⣿⣿⣾⣇⢀⣿⣿⡀⣸⣷⣿⣿⣿⠿⠛⠁⠀⠀
                                            ⠀⠀⠀⠀⠀⠀⠀⠙⢿⣿⣿⣿⣿⣿⣿⡿⠋⠀⠀⠀⠀⠀⠀⠀
                                            ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠙⠛⠛⠋⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀

"@

    $wick
}
function get_wreck_it_text_art {
    $wreck_it = @"

████████████████████████████████
██████▓▓▓▓█████▓▓▓▓████▓▓▓▓█████
████████▓▓▓▓▓▓▓▓▓▓▓██▓▓▓▓███████
███▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓███
█████▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓█████
█▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓█
███▓▓▓▓▓▓▓▓░░░░░░░░░░▓▓▓▓▓▓▓▓███
█████▓▓▓▓▒▒██░░░░░░██▒▒▓▓▓▓█████
███▓▓▓▓▓▓▒▒▒▒██▓▓██▒▒▒▒▓▓▓▓▓▓███
█▓▓▒▒▒▒▓▓▒▒────▒▒────▒▒▓▓▒▒▒▒▓▓█
███░░▒▒▓▓░░──██░▒██──░░▓▓▒▒░░███
███░░░░▓▓░░░░▓▓▓▓▓▓░░░░▓▓░░░░███
███████░░░░░░▓▓▓▓▓▓░░░░░░███████
███████░░░░░░░░░░░░░░░░░░███████
█████░░░░██▀▀▀▀▀▀▀▀▀▀██░░░░█████
█████░░████▄▄▄▄▄▄▄▄▄▄████░░█████
█████░░██████████████████░░█████
█████░░██▒▒██▓▓▓▓▓▓██▒▒██░░█████
█████░░██▓█▀▀▀▀▀▀▀▀▀▀█▓██░░█████
█████░░████▄▄▄▄▄▄▄▄▄▄████░░█████
███████░░░░░░░░░░░░░░░░░░███████
█████████▒▒▒▒▒▒▒▒▒▒▒▒▒▒█████████
████████████████████████████████

"@


    $wreck_it
}

function apply_data_config_file {
    param($path_to_data_config_file, $path_project_directory, $org_alias)
    if (Test-Path $path_to_data_config_file) {
        $data_config_json = Get-Content -Raw $path_to_data_config_file
        $data_config = $data_config_json | ConvertFrom-Json
        apply_data_config -data_config $data_config -path_project_directory $path_project_directory -org_alias $org_alias
    }
    else {
        Write-Error -Message "ERROR: DATA CONFIG DOES NOT EXIST: '$path_to_data_config_file'" -ErrorAction Stop
    }
}
