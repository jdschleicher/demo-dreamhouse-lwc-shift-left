function format_json {
    param($json, $depth=4)
    $json | convertfrom-json -NoEnumerate -Depth $depth | convertto-json -Depth $depth
}

function new_sobject {
  param($metadata_type_name, $label)

  # enforce expectations on $label and $metadata_type_name
  # [ExpectationEnforcement]::ShouldBeNonEmptyString($label, '$label')
  # [ExpectationEnforcement]::ShouldBeNonEmptyString($metadata_type_name, '$metadata_type_name')

  [PSCustomObject]@{
    'name' = $metadata_type_name;
    'label' = $label;
    'filters' = '';
    'excludedFields' = @();
  }
}

function remove_file_extension {
    param($file_name_with_extension, $file_extension)

    # enforce expectations on $file_extension and $file_name_with_extension
    # [ExpectationEnforcement]::ShouldBeNonEmptyString($file_extension, '$file_extension')    
    # [ExpectationEnforcement]::ShouldBeNonEmptyString($file_name_with_extension, '$file_name_with_extension')
    
    if ($file_name_with_extension -notlike "*$file_extension") {
      Write-Error -Message "ERROR: $file_name_with_extension does not end with '.$file_extension'" -ErrorAction Stop
    }
    else {
      ($file_name_with_extension -split "\.$file_extension")[0]
    }
}

function map_id_to_attributes {
    param($metadata_type_name, $id)

    [PSCustomObject]@{
        'type' = "$metadata_type_name";
        'referenceId' = "$($metadata_type_name)Ref$id";
    }
}

function map_snowfakery_records_to_dataset_records {
  param($snowfakery_records, $metadata_type_name)

  if ($snowfakery_records.count -gt 0){
    foreach ($snowfakery_record in $snowfakery_records) {`
        $attributes = map_id_to_attributes -id ($snowfakery_record.id) $metadata_type_name
        $snowfakery_record | Add-Member -Name 'attributes' -value $attributes -Type NoteProperty | Out-Null
        $snowfakery_record.psobject.Properties.remove('id') | Out-Null
    }
  }

  ,$snowfakery_records
}

function map_list_to_list_of_lists {
    param($monolithic_list, $new_list_size)

    if ($monolithic_list.count -gt $new_list_size) {

      $record_index = 0
      $max_index = $monolithic_list.count - 1 

      $list_of_lists = [system.collections.generic.list[[system.collections.generic.list[PSCustomObject]]]]::new()
      $list = [system.collections.generic.list[PSCustomObject]]::new()
      while ($true) {
          if (($record_index -ne 0) -and ($record_index % $new_list_size -eq 0)) {
              # accumulate record block
              $list_of_lists.Add($list) | Out-Null
              # reset record block
              $list = [system.collections.generic.list[PSCustomObject]]::new()
          }
          $this_event = $monolithic_list[$record_index]
          $list.Add($this_event) | Out-Null
          if ($record_index -eq $max_index) {
              # accumulate record block
              $list_of_lists.Add($list) | Out-Null
              # reset record block
              $list = [system.collections.generic.list[PSCustomObject]]::new()
              break
          }
          $record_index = $record_index + 1
      }
      
      $list_of_lists
      
    }
    else {
      $list_of_lists = ,$monolithic_list
      # wrap again bc outermost list will be unwrapped
      $list_of_list_of_lists = ,$list_of_lists
      $list_of_list_of_lists
    }

}

function map_dataset_records_to_dataset_json {
    param($dataset_records)
    $dataset_object = @{
      'records' = @($dataset_records)
    }
    $dataset_json = ConvertTo-Json -InputObject $dataset_object -Depth 4
    $dataset_json
}

function intialize_data_directory {
    param($path_to_generated_directory, $dataset_import_batch_size=1000, $raw_data_path)

   Write-Host "INITIALIZING DATA DIRECTORY"

    # $path_to_snowfakery_output_directory directory must exist in order to continue processing
    if (-Not (Test-Path $path_to_generated_directory)) {
      Write-Error -Message "ERROR: GENERATED OUTPUT DIRECTORY DOES NOT EXIST: '$path_to_generated_directory'" -ErrorAction Stop
    }
    else {
      
      $data_order_folder_name = "ordered_data_plan"
      $ordered_data_files_json = Get-Content "$path_to_generated_directory\$data_order_folder_name\csvw_metadata.json"
      $ordered_data_files = $ordered_data_files_json | ConvertFrom-Json -Depth 10

      $snowfakery_data_files = Get-ChildItem $raw_data_path -filter *.json
      $sobjects =  [system.collections.generic.list[PSCustomObject]]::new()

      $import_number = 1
      ### "tables" is an expected property generated from snowfakery and "url" holds the csv object api name

      foreach ( $data_file in $ordered_data_files.tables ) {
        
        foreach ($snowfakery_data_file in $snowfakery_data_files) {

          $ordered_object_api_name = remove_file_extension $data_file.url
          $metadata_type_name = remove_file_extension $snowfakery_data_file.name 'json'

          if ( $ordered_object_api_name -eq $metadata_type_name ) {

            $snowfakery_json = Get-Content -Raw $snowfakery_data_file.fullname
            $list_of_all_snowfakery_records = @(ConvertFrom-Json -InputObject $snowfakery_json -Depth 4)
            $list_of_all_dataset_records = map_snowfakery_records_to_dataset_records -snowfakery_records $list_of_all_snowfakery_records -metadata_type_name $metadata_type_name
            $list_of_dataset_records_lists = map_list_to_list_of_lists -monolithic_list $list_of_all_dataset_records -new_list_size $dataset_import_batch_size
            $list_of_dataset_jsons = foreach ($dataset_records_list in $list_of_dataset_records_lists) { map_dataset_records_to_dataset_json $dataset_records_list }
            $number_of_dataset_jsons = $list_of_dataset_jsons.count
            $total_records_to_import = $list_of_all_dataset_records.count
            
            if ($total_records_to_import -gt 0) {
    
              $log10_total_records_to_import = [math]::log10($total_records_to_import)
              $zero_fill_count_total_records_to_import = [math]::Ceiling($log10_total_records_to_import)
              $zero_fill_indices = (1..$zero_fill_count_total_records_to_import)
              $zero_fill_zeroes = $zero_fill_indices | foreach { '0' }
              $zero_fill_total_records_to_import = $zero_fill_zeroes -join ''

              $object_has_self_references = $false
    
              # INTIALIZE dataset INSERT DATA
              $records_processed = 1
              foreach ($dataset_json in $list_of_dataset_jsons) {
                  if ($number_of_dataset_jsons -gt 1) {
                    $records_imported = $records_processed * $dataset_import_batch_size
                    if ($records_imported -gt $total_records_to_import) {
                      $records_imported = $total_records_to_import
                    }
                    $percent_complete_decimal = $records_imported / $total_records_to_import * 100
                  }
                  else {
                    $records_imported = $total_records_to_import
                    $percent_complete_decimal = 100
                  }
                  $percent_complete_integer = [math]::Round($percent_complete_decimal)
                  $percent_complete_string = $percent_complete_integer.ToString('000')
                  $total_records_to_import_string = $total_records_to_import.ToString($zero_fill_total_records_to_import)
                  $label = "INSERT-percent-$percent_complete_string-$records_imported_string-of-$total_records_to_import_string"
                  $metadata_file_name = "$import_number-$($metadata_type_name)-$label.json"
                  $sobject = new_sobject -metadata_type_name $metadata_type_name -label $label
                  $sobjects.Add($sobject) | Out-Null
                  $dataset_json | Out-File "$path_to_generated_directory/$metadata_file_name"
                  $records_processed += 1
                  $import_number += 1


                  ### IF JSON BODY HAS MORE THAN ONE INSTANCE OF EXPECTED PATTERN "ObjectAPIRef1" 
                  ### THEN WE KNOW ANOTHER OBJECT IN THE JSON IS REFERENCING THAT AS A LOOKUP AND WE WILL NEED TO DO AN ENSUING UPDATE

                  $match_only_number_one_reference = "Ref1`"" ### THIS REGEX MATCHES -  Ref1" - and not just Ref1 because there could be Ref11, Ref12, etc
                  $self_object_lookup_reference_name = $ordered_object_api_name + $match_only_number_one_reference
                  $object_has_self_references = ( ([regex]::Matches($dataset_json, $self_object_lookup_reference_name )).count -gt 1 )

              }
    
              if ( $object_has_self_references ) {
                <#
                  ONLY OBJECTS THAT HAVE SELF REFERENCE LOOKUP FIELDS NEED ENSUING UPDATE
                #>

                 # INTIALIZE dataset UPDATE DATA
                $records_processed = 1
                foreach ($dataset_json in $list_of_dataset_jsons) {
                    if ($number_of_dataset_jsons -gt 1) {
                      $records_imported = $records_processed * $dataset_import_batch_size
                      if ($records_imported -gt $total_records_to_import) {
                        $records_imported = $total_records_to_import
                      }
                      $percent_complete_decimal = $records_imported / $total_records_to_import * 100
                    }
                    else {
                      $records_imported = $total_records_to_import
                      $percent_complete_decimal = 100
                    }
                    $percent_complete_integer = [math]::Round($percent_complete_decimal)
                    $percent_complete_string = $percent_complete_integer.ToString('000')
                    $records_imported_string = $records_imported.ToString($zero_fill_total_records_to_import)
                    $total_records_to_import_string = $total_records_to_import.ToString($zero_fill_total_records_to_import)
                    $label = "UPDATE-percent-$percent_complete_string-$records_imported_string-of-$total_records_to_import_string"
                    $metadata_file_name = "$import_number-$($metadata_type_name)-$label.json"
                    $sobject = new_sobject -metadata_type_name $metadata_type_name -label $label
                    $sobjects.Add($sobject) | Out-Null
                    $dataset_json | Out-File "$path_to_generated_directory/$metadata_file_name"
                    $records_processed += 1
                    $import_number += 1
                }

              }
             

            }
        
  
          }
  
        }
      }

      Write-Host $path_to_generated_directory
      Get-ChildItem $path_to_generated_directory | foreach { Write-Host $_.fullname }

    }

}
