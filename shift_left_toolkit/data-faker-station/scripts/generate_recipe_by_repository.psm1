


$static_directory_paths = [PSCustomObject]@{
    path_to_source_directory = ((Get-Location).Path);
    path_to_org_data_seeding_directory = $null;
}

function get_static_directory_paths {
    if ( $null -eq $static_directory_paths.path_to_org_data_seeding_directory ) {
        $static_directory_paths.path_to_org_data_seeding_directory = "$($static_directory_paths.path_to_source_directory)/shift_left_toolkit/data-faker-station"
    } 

    $static_directory_paths
}

$static_salesforce_field_to_fake_recipe_map = @{
    'checkbox' =             [PSCustomObject]@{ 'recipe'='${{ random_choice("true","false") }}' ; }
    'currency' =             [PSCustomObject]@{ 'recipe'='${{ fake.pyfloat( right_digits = 2, positive=True, min_value=None, max_value=1000000) }}'; }
    'date' =                 [PSCustomObject]@{ 'recipe'='${{ fake.date}}'; } 
    'datetime' =             [PSCustomObject]@{ 'recipe'='${{ fake.date}}'; } 
    'email' =                [PSCustomObject]@{ 'recipe'='${{ fake.ascii_safe_email}}'; }
    'number' =               [PSCustomObject]@{ 'recipe'='${{ fake.pyint( min_value = -10000, max_value = 100000 ) }}'; }
    'percent' =              [PSCustomObject]@{ 'recipe'='${{ fake.pyint( min_value = 0, max_value = 100) }}'; }
    'picklist' =             [PSCustomObject]@{ 'recipe'='${{ random_choice("alpha","bravo","charlie","delta","foxtrot") }}'; }
    'phone' =                [PSCustomObject]@{ 'recipe'='${{ fake.phone_number }}'; }
    'multiselectpicklist' =  [PSCustomObject]@{ 'recipe'='${{ ";".join(( fake.random_sample( elements=("alpha","bravo","charlie","delta","echo","foxtrot" ) ) )) }}'; }
    'text' =                 [PSCustomObject]@{ 'recipe'='${{ fake.text(max_nb_chars=20) }}'; }
    'html' =                 [PSCustomObject]@{ 'recipe'='${{ fake.sentence }}'; }
    'textarea' =             [PSCustomObject]@{ 'recipe'='${{ fake.paragraph }}'; }
    'time' =                 [PSCustomObject]@{ 'recipe'='${{ fake.time }}'; }
    'longtextarea' =         [PSCustomObject]@{ 'recipe'='${{ fake.paragraph }}'; }
    'url' =                  [PSCustomObject]@{ 'recipe'='${{ fake.url }}'; }
    'location' =             [PSCustomObject]@{ 'recipe'='##### SEE ONE PAGER FOR NECESSARY ADJUSTMENTS: https://github.com/jdschleicher/demo-dreamhouse-lwc-shift-left/blob/main/shift_left_toolkit/data-faker-station/documentation/Snowfakery-Recipe-One-Pager.md#:~:text=by%20Field%20Type-,Location%20Field,-A%20location%20type'; }
    'lookup' =               [PSCustomObject]@{ 'recipe'='##### SEE ONE PAGER FOR NECESSARY ADJUSTMENTS: https://github.com/jdschleicher/demo-dreamhouse-lwc-shift-left/blob/main/shift_left_toolkit/data-faker-station/documentation/Snowfakery-Recipe-One-Pager.md#:~:text=fake%3A%20longitude-,Lookup%20Field,-In%20order%20to'; }
    'encryptedtext' =        [PSCustomObject]@{ 'recipe'='${{ fake.credit_card_number }}'; }
}

function generate_snowfakery_recipe_from_repository {
    param(
        $timestamped_recipe_generation_directory
    )

    $salesforce_objects_directory_path = get_objects_directory_path_if_codebase_and_config_valid_for_recipe_generation
    if ( $null -ne $salesforce_objects_directory_path )  {

        $object_api_name_to_recipe_generation_details = create_object_api_name_to_recipe_generation_map -salesforce_objects_directory_path $salesforce_objects_directory_path
        
        create_recipes_files_by_object_to_recipe_details_map -object_api_name_to_recipe_details $object_api_name_to_recipe_generation_details `
                                                                -timestamped_recipe_generation_directory $timestamped_recipe_generation_directory
    }
   
}

function create_object_api_name_to_recipe_generation_map {
    param( $salesforce_objects_directory_path )

    $object_api_name_to_recipe_detail = @{}
    $salesforce_objects_directory = Get-ChildItem $salesforce_objects_directory_path 
    foreach ( $object_directory_path in $salesforce_objects_directory) { 
        
        ### OBJECTS DIRECTORY NAME IS ASSUMING THE OBJECT PARENT DIRECTORY WILL BE THE API NAME OF THE OBJECT

        $recipe_object = [ObjectRecipe]::new()
        $recipe_object.ApiName = $object_directory_path.Name
        $recipe_object.DirectoryPath = $object_directory_path.FullName

        $record_types_directory_path = "$salesforce_objects_directory_path/$($recipe_object.ApiName)/recordTypes"
        $record_types_directory_exists = Test-Path $record_types_directory_path
        $record_type_api_name_to_field_recipe_detail = $null
        if ( $record_types_directory_exists ) {
            $record_type_api_name_to_field_recipe_detail = get_recordtypes_to_field_recipe_map -record_types_path $record_types_directory_path
        }

        $fields_directory_path = "$salesforce_objects_directory_path/$($recipe_object.ApiName)/fields"
        $fields_directory_exists = Test-Path $fields_directory_path
        if ( $fields_directory_exists ) {

            $recipe_object.RecipeFields = get_field_recipes_by_fields_directory_path -fields_directory_path $fields_directory_path
         
        } else {
            Write-Host "Field files do not exist for the object $($recipe_object.ApiName). See $fields_directory_path"
        }

        $object_api_name_to_recipe_detail.Add($recipe_object.ApiName, $recipe_object) | Out-Null

    }

    $object_api_name_to_recipe_detail
}

function get_recordtypes_to_field_recipe_map {
    param( $record_types_path )

    $record_type_api_name_to_field_recipe_detail = $null
    $record_type_files = [system.collections.generic.list[string]](Get-ChildItem $record_types_path)
    if ($record_type_files -ne $null) {

        $record_type_api_name_to_field_recipe_detail = create_recordtype_api_name_to_field_recipe_detail_map -record_type_files $record_type_files

    }

    $record_type_api_name_to_field_recipe_detail

}

function create_recordtype_api_name_to_field_recipe_detail_map {
    param( $record_type_files )

    $record_type_to_record_type_modified_field_map = @{}
    foreach ( $record_type_file in $record_type_files ) {

        $record_type_xml_detail = extract_salesforce_recordtype_xml_details -salesforce_record_type_file $record_type_file
        
        if ( $record_type_xml_detail.picklistvalues.count -gt 0 ) {

            $record_type_recipe = build_record_type_to_record_type_field_modifications -record_type_xml_detail $record_type_xml_detail
            
            $record_type_to_record_type_modified_field_map.Add($record_type_xml_detail.fullName, $record_type_recipe) | Out-Null

        }
          
    }

    $record_type_to_record_type_modified_field_map

}

function build_record_type_to_record_type_field_modifications {
    param( $record_type_xml_detail )

    $field_to_record_type_driven_field_details = @{}

    $recordtype_recipe = [RecordTypeRecipe]::new()
    $recordtype_recipe.RecordTypeApiName = $record_type_xml_detail.fullName

    foreach ( $modification_field_detail in $record_type_xml_detail.picklistvalues) {

        $impacted_recordtype_field = [RecordTypeImpactedField]::new()
        $impacted_recordtype_field.FieldApiName = $modification_field_detail.picklist

        $picklist_values = [system.collections.generic.list[string]]::new()
        foreach ( $available_value in $modification_field_detail.values ) {
            $picklist_values.Add($available_value.fullName)
        }

        $impacted_recordtype_field.Picklistvalues = $picklist_values
        $field_to_record_type_driven_field_details.Add($impacted_recordtype_field.FieldApiName, $impacted_recordtype_field)

    }

    $field_to_record_type_driven_field_details

}

function get_objects_directory_path_if_codebase_and_config_valid_for_recipe_generation {

    $static_directory_paths = get_static_directory_paths

    $path_to_org_data_seeding_directory = $static_directory_paths.path_to_org_data_seeding_directory
    $data_config_file_name = 'config-data-seeding.json'
    $path_to_data_config_file = "$path_to_org_data_seeding_directory/$data_config_file_name"
    $data_config = $null

    if (Test-Path $path_to_data_config_file) {
        $data_config_json = Get-Content -Raw $path_to_data_config_file
        $data_config = $data_config_json | ConvertFrom-Json
    } else {
        Write-Error -Message "ERROR: ORG DATA CONFIG FILE NOT DEFINED: '$path_to_data_config_file'" -ErrorAction Stop
    }

    $path_to_recipes_is_defined = -not ([string]::IsNullOrWhiteSpace($data_config.path_to_recipes))
    $path_to_recipes_folder = "$path_to_org_data_seeding_directory/$($data_config.path_to_recipes)"
    $recipes_directory_exists = Test-Path $path_to_recipes_folder
    if (-not $path_to_recipes_is_defined) {
        # Ensure that $data_config.path_to_recipes is defined
        Write-Error -Message 'ERROR: PATH_TO_RECIPES NOT DEFINED' -ErrorAction Stop
    }
    elseif (-not $recipes_directory_exists) {
        # Ensure that $path_to_recipes_folder does exist
        Write-Error -Message "ERROR: RECIPES DIRECTORY DOES NOT EXIST: '$path_to_recipes_folder'" -ErrorAction Stop
    }

    $path_to_objects_is_defined = -not ([string]::IsNullOrWhiteSpace($data_config.path_to_objects_directory))
    $path_to_objects_folder = "$($static_directory_paths.path_to_source_directory)/$($data_config.path_to_objects_directory)"
    $objects_directory_exists = Test-Path $path_to_objects_folder

    if ( -not $path_to_objects_is_defined ) {
        # Ensure that $data_config.path_to_objects_directory is defined THROW WRITE ERROR IF NOT 
        Write-Error -Message 'ERROR: PATH_TO_OBJECTS_DIRECTORY NOT DEFINED' -ErrorAction Stop
    } 
    elseif ( -not $objects_directory_exists ) {
        # Ensure OJBECTS ACTUALLY EXIST IN CODEBASE, THROW WRITE ERROR IF NOT 
        Write-Error -Message "ERROR: OBJECTS DIRECTORY DOES NOT EXIST: '$path_to_objects_folder'" -ErrorAction Stop
    } 

    ### RETURN OBJECTS FOLDER PATH IF SETUP CORRECTLY AND config-data-seeding.json HAS vaLID SETUP AND REQUIRED vaLUES
    $path_to_objects_folder
}

function create_recipes_files_by_object_to_recipe_details_map {
    param( $object_api_name_to_recipe_details, $timestamped_recipe_generation_directory )

    $object_api_to_relationship_breakdown_map = [System.Collections.SortedList]::new()

    foreach ( $object_api_key in $object_api_name_to_recipe_details.Keys) {

        $object_recipe_fields = $object_api_name_to_recipe_details[$object_api_key].RecipeFields

        foreach ( $field_recipe in $object_recipe_fields) {
            
            if ( $field_recipe.IsLookup ) {

                $lookup_key = $field_recipe.LookupRecipe.LookupObjectApiName

                if ($object_api_to_relationship_breakdown_map.ContainsKey($lookup_key)) {

                    $child_relationship_lookup_detail = [ChildRelationshipDetail]@{
                        FieldApiNameLookingUpToMe = $field_recipe.ApiName
                        ParentObjectApiToUpdate = $lookup_key
                        ChildObjectApiToAdd = $object_api_key
                    }

                    $object_api_to_relationship_breakdown_map = update_child_relationship_breakdown_by_child_relationship_detail -object_api_to_relationship_breakdown_map $object_api_to_relationship_breakdown_map `
                        -child_relationship_lookup_detail $child_relationship_lookup_detail `
                        -parent_api_of_current_object $lookup_key `
                        -object_api_key $object_api_key
                    
                    $parent_relationship_lookup_detail = [ParentRelationshipLookupDetail]@{
                        ParentObjectILookUpTo = $lookup_key
                        ObjectApiNameToUpdate = $object_api_key
                        FieldHoldingReference = $field_recipe.ApiName
                    }

                    if ( $object_api_to_relationship_breakdown_map.ContainsKey($object_api_key ) ) {

                            $object_api_to_relationship_breakdown_map = update_existing_object_relationship_breakdown_for_parent_relationship_breakdown_with_new_lookup_parent_relationship_detail -object_api_to_relationship_breakdown_map $object_api_to_relationship_breakdown_map `
                            -parent_relationship_lookup_detail $parent_relationship_lookup_detail `
                            -object_api_key $object_api_key `
                            -parent_api_key $lookup_key

                    } else {

                        $object_api_to_relationship_breakdown_map = update_parent_relationship_breakdown_by_parent_relationship_detail -object_api_to_relationship_breakdown_map $object_api_to_relationship_breakdown_map `
                            -parent_relationship_lookup_detail $parent_relationship_lookup_detail `
                            -object_recipe_fields $object_recipe_fields `
                            -object_api_key $object_api_key `
                            -parent_api_key $lookup_key

                    }

                } else {

                    $fields_referencing_me = [system.collections.generic.list[string]]::new()
                    $fields_referencing_me.Add($field_recipe.ApiName) | Out-Null

                    $new_child_relationship_breakdown = [PSCustomObject]@{
                        "fields_referencing_me" = $fields_referencing_me
                        "total_times_referenced_by_this_object" = 1
                    }

                    $lookup_child_relationships_breakdown = [System.Collections.SortedList]::new()
                    $lookup_child_relationships_breakdown.Add($object_api_key, $new_child_relationship_breakdown) | Out-Null

                    $lookup_recipe_fields = $null 
                    if ( $null -ne $object_api_name_to_recipe_details[$lookup_key].RecipeFields ) {
                        $lookup_recipe_fields = $object_api_name_to_recipe_details[$lookup_key].RecipeFields
                    } 

                    $empty_lookup_parent_relationships_breakdown = [System.Collections.SortedList]::new()
                    $referenced_object_relationship_breakdown = [ObjectRelationshipBreakdown]@{ 
                         ChildRelationshipsBreakdown = $lookup_child_relationships_breakdown
                         TotalTimesReferenced = 1
                         ObjectApiName = $lookup_key
                         MaxAmountofReferencesFromSingleChildObject = 1
                         TotalParentObjectsIReference = 0
                         ParentRelationshipsBreakdown = $empty_lookup_parent_relationships_breakdown
                         RecipeFields = $lookup_recipe_fields
                    }
                                    
                    $object_api_to_relationship_breakdown_map.Add($lookup_key, $referenced_object_relationship_breakdown) | Out-Null

                    if ( $object_api_to_relationship_breakdown_map.ContainsKey($object_api_key) ) {

                        $fields_referencing_me = [system.collections.generic.list[string]]::new()
                        $fields_referencing_me.Add($field_recipe.ApiName) | Out-Null

                        $current_iterating_object_parent_relationships_breakdown = [PSCustomObject]@{
                            "parent_object_api_name" = $lookup_key
                            "total_times_i_look_up_to_this_object" = 1
                            "fields_holding_reference" = $fields_referencing_me
                        }
                    
                        $object_api_to_relationship_breakdown_map[$object_api_key].ParentRelationshipsBreakdown.Add($lookup_key, $current_iterating_object_parent_relationships_breakdown ) | Out-Null
                        $object_api_to_relationship_breakdown_map[$object_api_key].TotalParentObjectsIReference++
        
                    }
                }

                <# 
                    IF NO OBJECT API KEY YET PRESENT FOR CURRENT OBJECT BEING ITERATED OVER IN THE $object_api_to_relationship_breakdown_map 
                    THEN ADD OBJECT API KEY TO MAP WITH NEWLY CREATED EMPTY CHILD AND PARENT RELATIONSHIP CAPTURING CURRENT LOOKUP 
                #>
                if ( -not($object_api_to_relationship_breakdown_map.ContainsKey($object_api_key) )) {

                    $current_iterating_over_object_to_relationship_breakdown = create_new_relationship_breakdown_by_lookup_and_child_object -object_api_name $object_api_key `
                            -lookup_api_name $lookup_key `
                            -object_recipe_fields $object_recipe_fields `
                            -referencing_field $field_recipe.ApiName
                        
                    $object_api_to_relationship_breakdown_map.Add($object_api_key, $current_iterating_over_object_to_relationship_breakdown) | Out-Null

                } 
                
            }   
       
        }

        ### IF ATER ITERATING OVER ALL FIELDS, THERE ARE NO FIELDS ON THE OBJECT THAT HAVE A LOOKUP 
        ### WE WANT TO STILL CAPTURE A REFERENCE IN OUR OBJECT-RELATIONSHIPS MAP
        if ( -not($object_api_to_relationship_breakdown_map.ContainsKey($object_api_key)) ) {

            $object_to_empty_relationships_breakdown = build_empty_object_relationship_breakdown -object_api_name $object_api_key -object_recipe_fields $object_recipe_fields
            $object_api_to_relationship_breakdown_map.Add($object_api_key, $object_to_empty_relationships_breakdown)
                    
        }

    }

    ### USED FOR TROUBLESHOOTING ONLY
    $date_label = ([datetime]::now).ToString('yyyyMMdd-HHmm')
    $sorted_recipe_generation = $object_api_to_relationship_breakdown_map.GetEnumerator() | Sort-Object -Property Name
    $sorted_recipe_generation | ConvertTo-Json -Depth 14 | Out-File "$timestamped_recipe_generation_directory/OBJECT_BY_RELATIONSHIPS_$date_label.json" | Out-Null

    $object_api_to_relationship_breakdown_map
    
}


function create_new_relationship_breakdown_by_lookup_and_child_object {
    param( 
        $object_api_name, 
        $lookup_api_name, 
        $object_recipe_fields,
        $referencing_field
    )

    $object_child_relationships_breakdown = [System.Collections.SortedList]::new()

    $fields_holding_reference_to_parent = [system.collections.generic.list[string]]::new()
    $fields_holding_reference_to_parent.Add( $referencing_field ) | Out-Null
    $parent_relationships_breakdown = [PSCustomObject]@{
        "parent_object_api_name" = $lookup_api_name
        "total_times_i_look_up_to_this_object" = 1
        "fields_holding_reference" = $fields_holding_reference_to_parent
    }

    $parent_relationships_map = [System.Collections.SortedList]::new()
    $parent_relationships_map.Add($lookup_key, $parent_relationships_breakdown) | Out-Null
    
    $is_self_referencing_lookup = ( $object_api_name -eq $lookup_api_name )
    $total_child_objects_referencing_me = $is_self_referencing_lookup ? 1 : 0
    $object_relationship_breakdown = [ObjectRelationshipBreakdown]@{ 
        ChildRelationshipsBreakdown = $object_child_relationships_breakdown
        TotalTimesReferenced = $total_child_objects_referencing_me
        ObjectApiName = $object_api_name
        MaxAmountofReferencesFromSingleChildObject = 0
        TotalParentObjectsIReference = 1
        ParentRelationshipsBreakdown = $parent_relationships_map
        RecipeFields = $object_recipe_fields
    }

    $object_relationship_breakdown

}

function build_empty_object_relationship_breakdown {
    param( $object_api_name, $object_recipe_fields )

    $empty_child_relationships_breakdown = @{}
    $empty_parent_relationships_breakdown = @{}
    $object_with_empty_relationship_breakdown = [ObjectRelationshipBreakdown]@{ 
        ChildRelationshipsBreakdown = $empty_child_relationships_breakdown
        TotalTimesReferenced = 0
        ObjectApiName = $object_api_key
        MaxAmountofReferencesFromSingleChildObject = 0
        ParentRelationshipsBreakdown = $empty_parent_relationships_breakdown
        TotalParentObjectsIReference = 0
        RecipeFields = $object_recipe_fields
    }

    $object_with_empty_relationship_breakdown

}

function  update_child_relationship_breakdown_by_child_relationship_detail {
    param( 
        $object_api_to_relationship_breakdown_map, 
        $child_relationship_lookup_detail, 
        $parent_api_of_current_object,
        $object_api_key
    )

    $object_api_to_relationship_breakdown_map[$parent_api_of_current_object].TotalTimesReferenced++ 
    
    if ( $object_api_to_relationship_breakdown_map[$parent_api_of_current_object].ChildRelationshipsBreakdown.ContainsKey($object_api_key) ) {

        $object_api_to_relationship_breakdown_map[$parent_api_of_current_object].ChildRelationshipsBreakdown[$object_api_key].fields_referencing_me.Add($child_relationship_lookup_detail.FieldApiNameLookingUpToMe) | Out-Null
        $object_api_to_relationship_breakdown_map[$parent_api_of_current_object].ChildRelationshipsBreakdown[$object_api_key].total_times_referenced_by_this_object++

        $children_relationships_breakdown = $object_api_to_relationship_breakdown_map[$parent_api_of_current_object]
        
        <#
            FILTER COUNT OF TOTAL TIMES REFERENCED BY A CHILD OBJECT. FOR EXAMPLE THERE COULD BE 3 FIELDS
            ON AN OBJECT THAT ARE LOOKUPS TO 3 DIFFERENT TYPES OF USERS
            MAY NOT BE THE BEST WAY TO RELATE DATA.....BUT THAT CAN HAPPEN.
            THIS MAX TOTAL COUNT WILL BE NEEDED TO DETERMIN HOW MANY OBJECT BLOCKS OF A SPECIFIC OBJECT GETS 
            ADDED TO A RECIPE SO THAT 3 DIFFERENT OBJECTS CAN HAVE 3 DIFFERENT NICK NAMES FOR THE 3 FIELDS REFERENCING THE SAME OBJECT BUT DIFFERENT USERS
        #>
        $total_times_referenced_property = "total_times_referenced_by_this_object"
        $max_times_referenced_by_single_object = $children_relationships_breakdown.ChildRelationshipsBreakdown.values | Sort-Object -Property $total_times_referenced_property -Descending | Select-Object -First 1 -ExpandProperty $total_times_referenced_property
        $object_api_to_relationship_breakdown_map[$parent_api_of_current_object].MaxAmountofReferencesFromSingleChildObject = $max_times_referenced_by_single_object

    } else {

        $fields_referencing_me = [system.collections.generic.list[string]]::new()
        $fields_referencing_me.Add($child_relationship_lookup_detail.FieldApiNameLookingUpToMe) | Out-Null
        $new_child_relationship_breakdown = [PSCustomObject]@{
            "fields_referencing_me" = $fields_referencing_me
            "total_times_referenced_by_this_object" = 1
        }

        if ( $object_api_to_relationship_breakdown_map[$parent_api_of_current_object].MaxAmountofReferencesFromSingleChildObject -eq 0 ) {
            $object_api_to_relationship_breakdown_map[$parent_api_of_current_object].MaxAmountofReferencesFromSingleChildObject = 1
        }
        $object_api_to_relationship_breakdown_map[$parent_api_of_current_object].ChildRelationshipsBreakdown.Add($object_api_key, $new_child_relationship_breakdown)  | Out-Null

    }


    $object_api_to_relationship_breakdown_map

}

function  update_existing_object_relationship_breakdown_for_parent_relationship_breakdown_with_new_lookup_parent_relationship_detail {
    param( 
        $object_api_to_relationship_breakdown_map, 
        $parent_relationship_lookup_detail,
        $object_api_key,
        $parent_api_key
    )
    
    if ( $object_api_to_relationship_breakdown_map[$object_api_key].ParentRelationshipsBreakdown.ContainsKey($parent_api_key) ) {

        $object_api_to_relationship_breakdown_map[$object_api_key].ParentRelationshipsBreakdown[$parent_api_key].total_times_i_look_up_to_this_object++
        $object_api_to_relationship_breakdown_map[$object_api_key].ParentRelationshipsBreakdown[$parent_api_key].fields_holding_reference.Add($parent_relationship_lookup_detail.FieldHoldingReference)

    } else {

        $object_api_to_relationship_breakdown_map[$object_api_key].TotalParentObjectsIReference++ 

        $fields_holding_reference_to_parent = [system.collections.generic.list[string]]::new()

        $fields_holding_reference_to_parent.Add($parent_relationship_lookup_detail.FieldHoldingReference) | Out-Null
        $new_parent_relationship_breakdown = [PSCustomObject]@{
            "parent_object_api_name" = $parent_relationship_lookup_detail.ParentObjectILookUpTo
            "total_times_i_look_up_to_this_object" = 1
            "fields_holding_reference" = $fields_holding_reference_to_parent
        }            

        $object_api_to_relationship_breakdown_map[$object_api_key].ParentRelationshipsBreakdown.Add($parent_api_key, $new_parent_relationship_breakdown)  | Out-Null
    
    }

    $object_api_to_relationship_breakdown_map

}

function  update_parent_relationship_breakdown_by_parent_relationship_detail {
    param( 
        $object_api_to_relationship_breakdown_map, 
        $parent_relationship_lookup_detail, 
        $object_recipe_fields, 
        $object_api_key,
        $parent_api_key
    )

    $child_relationships_breakdown =  [System.Collections.SortedList]::new()
    $fields_holding_reference_to_parent = [system.collections.generic.list[string]]::new()
    $fields_holding_reference_to_parent.Add($parent_relationship_lookup_detail.FieldHoldingReference) | Out-Null
    $new_parent_relationship_breakdown = [System.Collections.SortedList]::new()
    $new_parent_relationship = [PSCustomObject]@{
        "parent_object_api_name" = $parent_api_key
        "total_times_i_look_up_to_this_object" = 1
        "fields_holding_reference" = $fields_holding_reference_to_parent
    }
    $new_parent_relationship_breakdown.Add($parent_api_key, $new_parent_relationship) | Out-Null

    $referenced_object_relationship_breakdown = [ObjectRelationshipBreakdown]@{
        ChildRelationshipsBreakdown = $child_relationships_breakdown
        TotalTimesReferenced = 0
        ObjectApiName = $object_api_key
        MaxAmountofReferencesFromSingleChildObject = 0
        ParentRelationshipsBreakdown = $new_parent_relationship_breakdown
        TotalParentObjectsIReference = 1
        RecipeFields = $object_recipe_fields
    }

    $object_api_to_relationship_breakdown_map.Add($object_api_key, $referenced_object_relationship_breakdown) | Out-Null
    $object_api_to_relationship_breakdown_map

}

function get_recipes_field_markup_by_node {
    param( $recipe_tree_node )

    $recipe_fields_markup = $null
    $field_indent = $(indent 4)

    foreach ( $recipe in $recipe_tree_node.Recipes ) {
       
        $attention_to_reference_comment = $null
        if ( $recipe.IsLookup ) {
            $attention_to_reference_comment = "### TODO: THIS NICKNAME MUST MATCH UNIQUE 'NICKNAME' INDEX VALUE OF THE EXPECTED LOOKUP OBJECT ABOVE"
        }
        $recipe_here_string = @"
$($field_indent)$($recipe.ApiName): $($recipe.Recipevalue)   $attention_to_reference_comment
"@

        <#
            TO COMBINE ALL FIELD RECIPE HERE STRINGS TOGETHER WE FIRST CHECK TO SEE IF $object_here_string_based_on_single_object_references
            HAS BEEN POPULATED YET THEN USE THE LINE BREAK TO COMBINE TWO HERE STRINGS TOGETHER
            SO SEPARETE OBJECTS HAVE A SPACE BETWEEN
        #> 
        if ( $null -eq $recipe_fields_markup ) {

            $recipe_fields_markup = $recipe_here_string

        } else {

            $recipe_fields_markup = $($recipe_fields_markup, $recipe_here_string -join "`n")

        }

    }

    $recipe_fields_markup

}

function build_recipes {
    param( $objtriarch_to_recipe_family_tree_map, $timestamped_recipe_generation_directory, $timestamp )

    foreach ( $objtriarch in $objtriarch_to_recipe_family_tree_map.Keys ) {

        $full_recipe_file_markup = $null

        $recipe_family_tree = $objtriarch_to_recipe_family_tree_map[$objtriarch]
        $sorted_recipe_family_tree = $recipe_family_tree | Sort-Object -Property Level

        foreach ( $recipe_tree_node in $sorted_recipe_family_tree ) {

            $recipe_fields = get_recipes_field_markup_by_node -recipe_tree_node $recipe_tree_node

            if ( $null -eq $recipe_fields ) {
                $recipe_fields = "### TODO: ATTENTION NEEDED HERE FOR NON-INCLUDED FIELD RECIPE vaLUES  ###"
            }
         
            $CHILD_DEPENDENTS_TODO_MESSAGE = $null
            if ( $null -ne $recipe_tree_node.ChildObjectsThatReferenceThisNode -and $recipe_tree_node.ChildObjectsThatReferenceThisNode -gt 0 ) {
                $CHILD_DEPENDENTS_TODO_MESSAGE = "`n### TODO: THERE ARE DEPENDENT OBJECTS BELOW NEEDING REFERENCE OF THIS OBJECT'S `"nickname`": $($recipe_tree_node.ChildObjectsThatReferenceThisNode) "          
            }

            $object_here_string_based_on_single_object_references = $null
            ### IN THE EVENT THERE ARE NO CHILD LOOKUPS THEN INCREMENT THE COUNT TO 1 TO ENSURE A RECIPE IS CREATED
            $max_count = ( $recipe_tree_node.MaxCountTimesReferencedBySingleObject -eq 0 ) ? 1 : $recipe_tree_node.MaxCountTimesReferencedBySingleObject
            for ($i = 0; $i -lt $max_count; $i++) {

                $nickname_identifier = ( $max_count -gt 1 ) ? ($i + 1) : ""

                $object_here_string =@"
$CHILD_DEPENDENTS_TODO_MESSAGE         
- object: $($recipe_tree_node.ApiName)
$(indent 2 )count: $(1)
$(indent 2 )nickname: $($recipe_tree_node.ApiName)_NickName$($nickname_identifier)
$(indent 2 )fields:
$($recipe_fields)
"@

                <#
                    TO COMBINE ALL SAME OBJECT HERE STRINGS TOGETHER WE FIRST CHECK TO SEE IF $object_here_string_based_on_single_object_references
                    HAS BEEN POPULATED YET THEN USE THE LINE BREAK TO COMBINE TWO HERE STRINGS TOGETHER
                    SO SEPARETE OBJECTS HAVE A SPACE BETWEEN
                #> 
                if ( $null -eq $object_here_string_based_on_single_object_references) {

                    $object_here_string_based_on_single_object_references = $object_here_string

                } else {

                    $object_here_string_based_on_single_object_references = $($object_here_string_based_on_single_object_references, $object_here_string -join "`n")

                }

            }


            <#
                TO COMBINE OBJECT HERE STRINGS TOGETHER WE FIRST CHECK TO SEE IF $full_recipe_file_markup
                HAS BEEN POPULATED YET THEN USE THE LINE BREAK TO COMBINE TWO HERE STRINGS TOGETHER
                SO SEPARETE OBJECTS HAVE A SPACE BETWEEN
            #> 
            if ( $null -eq $full_recipe_file_markup ) {

                $full_recipe_file_markup = $object_here_string_based_on_single_object_references

            } else {

                $full_recipe_file_markup = $($full_recipe_file_markup, $object_here_string_based_on_single_object_references -join "`n")

            }

        }

        $recipe_file_name = "$($objtriarch)_$timestamp.yml"
        create_recipe_files_by_object_api_name_and_associated_recipe_body -recipe_file_name $recipe_file_name -recipe_body $full_recipe_file_markup -timestamped_recipe_generation_directory $timestamped_recipe_generation_directory

    }
            
}

function update_object_api_to_recipe_relationship_map_by_object_api_name_and_reference_type {
    param(
        $object_api_to_recipe_relationship_map,
        $object_api_name_to_be_key,
        $originating_object_api_name_to_recipe_details,
        $originating_child_object_api
    )
    
    if ($object_api_to_recipe_relationship_map.ContainsKey($object_api_name_to_be_key)) {

        $child_reference_object_to_object_recipe_detail = @{ 
            "$originating_child_object_api" = $originating_object_api_name_to_recipe_details
        }

        $object_api_to_recipe_relationship_map[$object_api_name_to_be_key].Add($child_reference_object_to_object_recipe_detail) | Out-Null

    } else {

        $child_relationship_structures = [system.collections.generic.list[PSCustomObject]]::new();

        $child_reference_object_to_object_recipe_detail = @{ 
            "$originating_child_object_api" = $originating_object_api_name_to_recipe_details
        }

        $child_relationship_structures.Add($child_reference_object_to_object_recipe_detail)
        $object_api_to_recipe_relationship_map.Add($object_api_name_to_be_key, $child_relationship_structures) | Out-Null

    }

    $object_api_to_recipe_relationship_map_ref
     
}

function create_recipe_files_by_object_api_name_and_associated_recipe_body {
    param(
        $recipe_file_name, 
        $recipe_body,
        $timestamped_recipe_generation_directory
    )

    $recipes_path = "$timestamped_recipe_generation_directory/recipes"
    $recipes_path_exists = -not (Test-Path $recipes_path)
    if ($recipes_path_exists) {
        New-Item -Type Directory $recipes_path | Out-Null
    }

    $recipe_name_yml = "$timestamped_recipe_generation_directory/recipes/$recipe_file_name"
    $recipe_body | Out-File $recipe_name_yml
    Write-Host "Your recipe created at: $recipe_name_yml"

}

function create_generated_recipe_timestamped_directory {
    param($timestamp)

    $static_directory_paths = get_static_directory_paths
    $path_to_recipe_output_directory = "$($static_directory_paths.path_to_org_data_seeding_directory)/inactive_recipes/generated_by_repository"
    $output_directory_does_not_exist = -not (Test-Path $path_to_recipe_output_directory)
    if ($output_directory_does_not_exist) {
        New-Item -Type Directory $path_to_recipe_output_directory | Out-Null
    }

    $path_to_repo_recipes_by_date = "$path_to_recipe_output_directory/$timestamp"
    $repo_recipes_by_date_directory_does_not_exist = -not (Test-Path $path_to_repo_recipes_by_date)
    if ($repo_recipes_by_date_directory_does_not_exist) {
        New-Item -Type Directory $path_to_repo_recipes_by_date | Out-Null
    }

    $timestamped_directory_path = "$path_to_recipe_output_directory/$timestamp"

    $timestamped_directory_path

}

function get_field_recipes_by_fields_directory_path {
    param($fields_directory_path)

    $field_recipes = [system.collections.generic.list[FieldRecipe]]::new()
    $field_files = Get-ChildItem $fields_directory_path
    foreach ( $field_file in $field_files) {

        $field_recipe_detail = extract_salesforce_field_details -salesforce_field_file $field_file -

        ### DO NOT POPULATE AUTO-vaLUED FORMULA FIELDS IN RECIPE
        if ( -not($field_recipe_detail.IsFormulaField) ) {

            $field_recipes.Add($field_recipe_detail) | Out-Null

        }
        
    }

    $field_recipes

}

function get_salesforce_record_type_field_detail_from_record_type_xml {
    param( $salesforce_record_type, $salesforce_field_xml_detail )

        <# $field_recipe_detail = [PSCustomObject]@{
             "full_api_name"         = $salesforce_field_xml_detail.'fullName'
             "type"                  = $salesforce_field_type.ToLower();
             "recipe_value"          = "${{ fake.pyfloat }}"
             "reference_type_detail" = @{
                  "reference_type_field_api_name" = PSCustom{
                       'reference_api_name = 'User'
                       'reference_type' = 'lookup'
                       'releationship_api_name = 'Broker_Workflow_Run'
                       'relationship_order = '1'
                   }
              }
        #>

    $field_detail = [PSCustomObject]@{
        "full_api_name"         = $salesforce_field_xml_detail.'fullName';
        "type"                  = $salesforce_field_type.ToLower();
        "recipe_value"          = $null;
        "reference_type_detail" = @{};
        "is_formula_field"      = $false

    }

    $recipe_value = $null
    ### ENSURE PICKLIST FIELD IS NOT DEPENDENT PICKLIST 
    if ( $salesforce_field_type -eq "picklist" -and ($null -eq $salesforce_field_xml_detail.valueSet.controllingField) ) {

        $recipe_value = get_picklist_recipe_values_from_xml -picklist_xml_detail $salesforce_field_xml_detail
    
    } elseif ( $salesforce_field_type -eq "lookup" -or $salesforce_field_type -eq "masterdetail" ) {

        $reference_type_detail = get_reference_type_detail -reference_field_xml_detail $salesforce_field_xml_detail -field_type $salesforce_field_type
        $field_detail.reference_type_detail.Add($field_detail.full_api_name, $reference_type_detail) | Out-Null
        $recipe_value = get_special_reference_recipe_value_from_xml -reference_field_xml_detail $salesforce_field_xml_detail

    } elseif ( $salesforce_field_xml_detail.PSobject.Properties.name -contains "formula" ) {

        ### DO NOT POPULATE AUTO-vaLUED FORMULA FIELDS IN RECIPE
        $field_detail.is_formula_field = $true

    } elseif ( $salesforce_field_type -eq "multiselectpicklist" ) {

        $recipe_value = get_multiselect_picklist_recipe_values_from_xml -multiselect_picklist_xml_detail $salesforce_field_xml_detail

    } elseif ( $salesforce_field_type -eq "picklist" -and (-not($null -eq $salesforce_field_xml_detail.valueSet.controllingField)) ) {

        $recipe_value = get_dependent_picklist_recipe_value_from_xml -dependent_picklist_xml_detail $salesforce_field_xml_detail
    
    }

    $field_detail.recipe_value = $recipe_value
    $field_detail

}

function get_salesforce_field_recipe_from_xml_by_salesforce_type {
    param( $salesforce_field_type, $salesforce_field_xml_detail )

    $field_recipe = [FieldRecipe]::new()
    $field_recipe.ApiName = $salesforce_field_xml_detail.'fullName'
    $field_recipe.Type = $salesforce_field_type.ToLower()

    $recipe_value = $null
    ### ENSURE PICKLIST FIELD IS NOT DEPENDENT PICKLIST 
    if ( $salesforce_field_type -eq "picklist" -and ($null -eq $salesforce_field_xml_detail.valueSet.controllingField) ) {

        $recipe_value = get_picklist_recipe_values_from_xml -picklist_xml_detail $salesforce_field_xml_detail
    
    } elseif ( $salesforce_field_type -eq "lookup" -or $salesforce_field_type -eq "masterdetail" ) {

        $field_recipe.IsLookup = $true
        $field_recipe.LookupRecipe = get_lookup_recipe_by_reference_xml_detail -reference_field_xml_detail $salesforce_field_xml_detail -field_type $salesforce_field_type
        $recipe_value = get_special_reference_recipe_value_from_xml -reference_field_xml_detail $salesforce_field_xml_detail

    } elseif ( $salesforce_field_xml_detail.PSobject.Properties.name -contains "formula" ) {

        ### DO NOT POPULATE AUTO-vaLUED FORMULA FIELDS IN RECIPE
        $field_recipe.IsFormulaField = $true

    } elseif ( $salesforce_field_type -eq "multiselectpicklist" ) {

        $recipe_value = get_multiselect_picklist_recipe_values_from_xml -multiselect_picklist_xml_detail $salesforce_field_xml_detail

    } elseif ( $salesforce_field_type -eq "picklist" -and (-not($null -eq $salesforce_field_xml_detail.valueSet.controllingField)) ) {

        $recipe_value = get_dependent_picklist_recipe_value_from_xml -dependent_picklist_xml_detail $salesforce_field_xml_detail
    
    }

    $field_recipe.Recipevalue = $recipe_value
    $field_recipe

}

function get_special_reference_recipe_value_from_xml {
    param( $reference_field_xml_detail )

    $reference_api_name = "$($reference_field_xml_detail.referenceTo)"
    $reference_type_recipe_value = "$($reference_api_name)Ref`${{ reference($($reference_api_name)_NickName)}}"
    
    $reference_type_recipe_value

}

function get_lookup_recipe_by_reference_xml_detail {
    param( $reference_field_xml_detail, $field_type )

    $lookup_recipe = [LookupRecipe]::new()
    $lookup_recipe.LookupType = $field_type
    $lookup_recipe.LookupObjectApiName = $reference_field_xml_detail.referenceTo
    $lookup_recipe.RelationshipApiName = $reference_field_xml_detail.relationshipName

    $lookup_recipe

}

function get_picklist_recipe_values_from_xml {
    param( $picklist_xml_detail )

    ###  ".valueSet.valueSetDefinition.value" IS THE EXPECTED PROPERTY INVOCATION PATH 
    ### THAT LEADS TO THE AvaILABLE PICKLIST vaLUES 
    $picklist_xml_node_all_values_location = $picklist_xml_detail.valueSet.valueSetDefinition.value
    

    # ${{ random_choice("alpha","bravo","charlie","delta","foxtrot") }}';
    $all_picklist_value_api_names = $picklist_xml_node_all_values_location | Select-Object -ExpandProperty fullName
    $quoted_api_names = $all_picklist_value_api_names -join '","'
    $recipe_value = @" 
`${{ random_choice("$quoted_api_names") }}
"@

    $recipe_value

}

function get_multiselect_picklist_recipe_values_from_xml {
    param( $multiselect_picklist_xml_detail )

    <# EXPECTED FAKE SYNTAX FOR MULTISELECT
        # picklistmultiselect1__c: ${{ ';'.join(( fake.random_sample( elements=('alpha','bravo','charlie','delta','echo','foxtrot') ) )) }}
    #>

    ###  ".valueSet.valueSetDefinition.value" IS THE EXPECTED PROPERTY INVOCATION PATH 
    ### THAT LEADS TO THE AvaILABLE PICKLIST vaLUES 
    $multiselect_picklist_xml_node_all_values_location = $multiselect_picklist_xml_detail.valueSet.valueSetDefinition.value
    

    $all_multiselect_picklist_value_api_names = $multiselect_picklist_xml_node_all_values_location | Select-Object -ExpandProperty fullName
    $quoted_api_names = $all_multiselect_picklist_value_api_names -join "','"

    $recipe_value = @" 
`${{ ';'.join(( fake.random_sample( elements=('$quoted_api_names') ) )) }}
"@

    $recipe_value

}

function get_dependent_picklist_recipe_value_from_xml {
    param( $dependent_picklist_xml_detail )

    <# EXPECTED FAKE SYNTAX FOR MULTISELECT
        dependentpicklist1__c:
      if:
        - choice:
            when: ${{picklist1__c=='alpha'}}
            pick:
              random_choice:
                - sierra
        - choice:
            when: ${{picklist1__c=='bravo'}}
            pick:
              random_choice:
                - sierra
                - tango
        - choice:
            when: ${{picklist1__c=='delta'}}
            pick:
              random_choice:
                - sierra
                - tango
                - uniform
                - victor
    #>

    ###  ".valueSet.controllingField" IS THE EXPECTED CONTROLLING FIELD FOR THE PICKLIST     
    $controlling_field = $dependent_picklist_xml_detail.valueSet.controllingField

    $dependent_picklist_control_and_available_choices = @"
`n      if:
"@

    $controlling_field_to_picklist_options_map = get_controlling_field_to_options_map_by_depenedent_picklist_value_settings -dependent_picklist_value_settings $dependent_picklist_xml_detail.valueSet.valueSettings

    foreach ( $controlling_picklist_key in $controlling_field_to_picklist_options_map.Keys ) {

        $dependent_picklist_options = $controlling_field_to_picklist_options_map[$controlling_picklist_key]
        
        $available_choices_breakdown = @"
        - choice:
            when: `${{ $controlling_field == '$controlling_picklist_key' }}
            pick:
              random_choice:
"@

        $dependent_picklist_control_and_available_choices = $($dependent_picklist_control_and_available_choices , $available_choices_breakdown -join "`n")

        foreach ( $picklist_option in $dependent_picklist_options ) {
            
            $picklist_option_here_string = @"
                - $picklist_option
"@

            $dependent_picklist_control_and_available_choices = $($dependent_picklist_control_and_available_choices , $picklist_option_here_string -join "`n")

        }

    }


    $recipe_value = @" 
$dependent_picklist_control_and_available_choices
"@

    $recipe_value

}

function get_controlling_field_to_options_map_by_depenedent_picklist_value_settings {
    param( $dependent_picklist_value_settings )

    $controlling_field_to_picklist_options = @{}
    foreach ( $value_settings in $dependent_picklist_value_settings) {

        $dependent_picklist_option = $value_settings.valueName

        foreach ( $picklist_controlling_field in $value_settings.controllingFieldvalue ) {

            if ($controlling_field_to_picklist_options.ContainsKey($picklist_controlling_field)) {
        
                $controlling_field_to_picklist_options[$picklist_controlling_field].Add($dependent_picklist_option) | Out-Null
        
            } else {

                $dependent_picklist_options = [system.collections.generic.list[string]]::new()  
                $dependent_picklist_options.Add($dependent_picklist_option)
                $controlling_field_to_picklist_options.Add($picklist_controlling_field, $dependent_picklist_options) | Out-Null
        
            }
    
        }
    }


    $controlling_field_to_picklist_options

}

function extract_salesforce_field_details {
    param($salesforce_field_file)

    $salesforce_field_file = Get-Content -Raw $salesforce_field_file
    [xml]$xml_object = [xml]$salesforce_field_file
    $xml_members = $xml_object | Get-Member -MemberType Property
    
    foreach ($xml_member in $xml_members) {
        if ($xml_member.name -ne 'xml' -and $null -ne $xml_object.($xml_member.name).'type' ) {

            $salesforce_field_type = $xml_object.($xml_member.name).'type'.ToLower();
            $salesforce_field_xml_detail = $xml_object.($xml_member.name);
            $field_recipe = get_salesforce_field_recipe_from_xml_by_salesforce_type -salesforce_field_type $salesforce_field_type -salesforce_field_xml_detail $salesforce_field_xml_detail

            if ( [string]::IsNullOrEmpty($field_recipe.Recipevalue) ) {
                $field_recipe.Recipevalue = $static_salesforce_field_to_fake_recipe_map[$field_recipe.Type].recipe
            }
            $field_recipe  
            break
        }
    }
}

function extract_salesforce_recordtype_xml_details {
    param($salesforce_record_type_file)

    $salesforce_record_type_file = Get-Content -Raw $salesforce_record_type_file
    [xml]$xml_object = [xml]$salesforce_record_type_file
    $xml_members = $xml_object | Get-Member -MemberType Property
    
    foreach ($xml_member in $xml_members) {
        if ($xml_member.name -ne 'xml' -and $null -ne $xml_object.($xml_member.name).'fullName' ) {

            $salesforce_record_type_xml_detail = $xml_object.($xml_member.name);
            break
        }
    }

    $salesforce_record_type_xml_detail
}

function indent {
    param($indent_amount)
    ' ' * $indent_amount
}

class Recipe {

    [string] $Name
    [string] $Body

}

class ObjectRecipe {

    [string] $DirectoryPath
    [string] $ApiName
    [FieldRecipe[]] $RecipeFields
    [RecordTypeRecipe[]] $RecordTypes
    [System.Collections.Hashtable] $RecipeLookupToRecipes
    [RecipeRelationship] $RecipeRelationship


}

class RecordTypeRecipe {

    [string] $RecordTypeApiName
    [RecordTypeImpactedField[]] $ImpactedFields

}

class RecordTypeImpactedField {

    [string] $FieldApiName
    [string[]] $Picklistvalues   

}

class FieldRecipe {

    [string] $ApiName
    [string] $Type
    [string] $Recipevalue
    [System.Boolean] $IsLookup
    [LookupRecipe] $LookupRecipe
    [System.Boolean] $IsFormulaField

}

class LookupRecipe {

    [string] $LookupType
    [string] $LookupObjectApiName
    [string] $RelationshipApiName

}

class ObjectRelationshipBreakdown {
    [System.Collections.SortedList] $ChildRelationshipsBreakdown
    [int] $TotalTimesReferenced
    [System.Collections.SortedList] $ParentRelationshipsBreakdown
    [int] $TotalParentObjectsIReference
    [int] $MaxAmountofReferencesFromSingleChildObject
    [string] $ObjectApiName
    [FieldRecipe[]] $RecipeFields

}

class ChildRelationshipDetail {
    [string] $FieldApiNameLookingUpToMe
    [string] $ParentObjectApiToUpdate
    [string] $ChildObjectApiToAdd
}

class ParentRelationshipLookupDetail {
    [string] $ParentObjectILookUpTo
    [string] $ObjectApiNameToUpdate
    [string] $FieldHoldingReference
}

class RecipeRelationship {
    
    [int] $TotalUniqueObjectsReferencingMeCount
    [int] $TotalLookupsCount = 0

}

