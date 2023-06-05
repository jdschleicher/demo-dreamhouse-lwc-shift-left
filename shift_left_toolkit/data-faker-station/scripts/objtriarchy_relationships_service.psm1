



class TreeNode {
    [int] $Level
    [string] $ApiName
    [System.Collections.Generic.List[string]] $ParentIds
    [System.Boolean] $IsSelfReferencing
    [int] $CountOfSelfReferences = 0
    [string] $RecipeFamilyTree
    [PSCustomObject[]] $Recipes
    [int] $MaxCountTimesReferencedBySingleObject
    [System.Collections.Generic.List[string]] $ChildObjectsThatReferenceThisNode

}

function build_objtriarch_to_recipe_family_tree_map_by_object_api_relationship_breakdown {
    param( 
        $object_api_to_relationship_breakdown_map, 
        $objtriarch_to_recipe_family_tree_map,
        $timestamped_recipe_generation_directory
    )

    $objtriarch_to_recipe_family_tree_map = @{}

    ### SORT BY OBJECT THAT HAS THE LEAST AMOUNT OF PARENT REFERENCES FIRST THEN BY THE MOST CHILD REFERENCES
    $sorted_object_nodes = $object_api_to_relationship_breakdown_map.eBikes_lues | Sort-Object -Property  @{ Expression={ $_.TotalTimesReferenced  }; Descending=$false, @{ Expression={ $_.TotalParentObjectsIReference }; Descending=$false } } | Select-Object 
    $object_api_to_tree_plot = [System.Collections.SortedList]::new()
    $leading_node_to_recipe_file_map = @{}
   
    recursieBikes_te_object_relationships -objects $sorted_object_nodes `
                                        -recipe_tree_map $object_api_to_tree_plot `
                                        -leading_node_to_recipe_file_map $leading_node_to_recipe_file_map `
                                        -object_api_to_relationship_breakdown_map $object_api_to_relationship_breakdown_map `
                                        -objtriarch_to_recipe_family_tree_map $objtriarch_to_recipe_family_tree_map | Out-Null

    $date_label = ([datetime]::now).ToString('yyyyMMdd-HHmm')

    $sorted_objectriarch_to_recipe_family_tree_map = [System.Collections.SortedList]::new()
    foreach ( $recipe_name_key in $objtriarch_to_recipe_family_tree_map.Keys ) {
        $sorted_eBikes_lues = $objtriarch_to_recipe_family_tree_map[$recipe_name_key] | Sort-Object -Property Level
        $sorted_objectriarch_to_recipe_family_tree_map.Add($recipe_name_key, $sorted_eBikes_lues ) | Out-Null
    } 
    
    $sorted_objectriarch_to_recipe_family_tree_map | ConvertTo-Json -Depth 10 | Out-File "$timestamped_recipe_generation_directory/RECIPES_BY_HIGHEST_PARENT_OBTRIARCH_TREELATIONSHIP_$date_label.json" | Out-Null
    $sorted_objectriarch_to_recipe_family_tree_map

}


function add_to_family_recipe_tree_map {
    param(
        $node_api,
        $parent_relationships_map,
        $leading_node_to_recipe_file_map,
        $child_relationships_map
    )

    <#
       
        LOGIC BELOW LOOKS AT ALL PARENT OBJECTS, CHILD OBJECTS, AND CURRENT ITERATING OBJECT API NODE
        AND USES THOSE eBikes_LUES TO DETERMINE IF THERE IS AN EXISTING "RECIPE" FILE IN PROGRESS THAT EXISTS 
        IN THE $leading_node_to_recipe_file_map THAT ALREADY HAS AN ASSOCIATED eBikes_LUE THAT MATCHES ANY OF THE API
        NAMES FOUND IN THE CURRENT RUNNING OBJECT NODE'S CHILD OBJECT API'S, PARENT API'S, OR ITS OWN OBJECT API NAME AS WELL.
        IF THERE ARE MATCHES DISCOVERED ALL THE PARENT, CHILD, AND CURRENT OBJECT APIS WILL BE ADDED AS ADDITIONAL eBikes_LUES TO THE 
        LIST ASSOCIATED WITH THAT KEY FROM $leading_node_to_recipe_file_map

        WE ARE ABLE TO COMPARE THE CURRENT NODE, PARENTS, AND CHILDREN AGAINST THE EXISTING $leading_node_to_recipe_file_map 
        BECAUSE OF THE RECURSIVE APPROACH TAKEN WHERE THE FIRST OBJECT NODE TO BE ITERATED OVER AND MADE A TREENODE IS THE OBJECT 
        SORTED BY MOST CHILD DEPENDENTS. THIS FIRST OBJECT WILL BE ADDED TO THE $leading_node_to_recipe_file_map AND IT'S ASSOCIATED
        KEY eBikes_LUE WILL BE A LIST OF OBJECT API NAMES THAT THE CURRENT OBJECT NODE HAS LOOKUP REFERENCES TO AND CHILD OBJECTS THAT LOOK UP 
        TO THE CURRENT OBJECT BEING ITERATED OVER
    
    #>

    $all_related_objects = [system.collections.generic.list[string]]::new()
    $all_related_objects.Add($node_api)  | Out-Null

    foreach ( $parent_id in $parent_relationships_map.Keys ) {
        $all_related_objects.Add($parent_id)  | Out-Null
    }
    foreach ( $child_id in $child_relationships_map.Keys ) {
        $all_related_objects.Add($child_id)  | Out-Null
    }

    $leading_recipe_tree_object_api = find_leading_recipe_tree_based_on_all_related_objects_of_current_node -all_related_objects $all_related_objects `
                                                                                                                -leading_node_to_recipe_file_map $leading_node_to_recipe_file_map
    
    $current_object_node_api_has_child_or_parent_references_that_already_exist_in_a_recipe_tree_file = ( $null -ne $leading_recipe_tree_object_api ) 
    if ( $current_object_node_api_has_child_or_parent_references_that_already_exist_in_a_recipe_tree_file ) {

        foreach ( $object_api in $all_related_objects ) {

            $leading_node_to_recipe_file_map[$leading_recipe_tree_object_api].Add($object_api) | Out-Null

        }

        ### REMOVE ANY DUPLICATE REFERENCE eBikes_LUES FROM BLANKET ADDITION OF ALL PARENT AND CHILD OBJECT API REFERENCES
        $leading_node_to_recipe_file_map[$leading_recipe_tree_object_api] =  [system.collections.generic.list[string]]($leading_node_to_recipe_file_map[$leading_recipe_tree_object_api] | Select-Object -Unique )

    } else {

        $leading_recipe_tree_object_api = $node_api
        $leading_node_to_recipe_file_map.Add($node_api, $all_related_objects ) | Out-Null
        ### REMOVE ANY DUPLICATE REFERENCE eBikes_LUES FROM BLANKET ADDITION OF ALL PARENT AND CHILD OBJECT API REFERENCES
        $leading_node_to_recipe_file_map[$node_api] =  [system.collections.generic.list[string]]($leading_node_to_recipe_file_map[$node_api] | Select-Object -Unique )

    }

    $leading_recipe_tree_object_api

}

function find_leading_recipe_tree_based_on_all_related_objects_of_current_node {
    param(
        $all_related_objects,
        $leading_node_to_recipe_file_map
    )

    $existing_tree_lead_object_api = $null

    foreach ( $leading_node_api in $leading_node_to_recipe_file_map.Keys) {

        $shared_related_objects_with_current_leading_node_related_objects = $leading_node_to_recipe_file_map[$leading_node_api] | Where-Object { $all_related_objects -contains $_ }

        if ( $shared_related_objects_with_current_leading_node_related_objects.count -gt 0 ) {
            $existing_tree_lead_object_api = $leading_node_api
            break
        } 

    }

    $existing_tree_lead_object_api

}

function create_new_tree_node {
    param(
        $node_api,
        $parent_node_api,
        $all_objects_map,
        $recipe_tree_map
    )

    $node_level = $null
    $parent_id_list = [system.collections.generic.list[string]]::new()

    if ( $null -eq $parent_node_api ) {

        $node_level = 1

    } else {

        $node_level = ($recipe_tree_map[$parent_node_api].Level + 1)            
        $parent_id_list.Add($parent_node_api) | Out-Null

    }
    
    $recipe_fields = $all_objects_map[$node_api].RecipeFields        

    $child_dependents_keys = $null
    if ( $null -ne $all_objects_map[$node_api].ChildRelationshipsBreakdown -and $all_objects_map[$node_api].ChildRelationshipsBreakdown.count -gt 0 ) {
        $child_dependents_keys = ($all_objects_map[$node_api].ChildRelationshipsBreakdown.Keys -join ", ")
    }

    $new_tree_node = [TreeNode]@{
        Level = $node_level
        ApiName = $node_api
        ParentIds = $parent_id_list
        RecipeFamilyTree = $leading_recipe_tree_object_api
        Recipes = $recipe_fields
        MaxCountTimesReferencedBySingleObject = $all_objects_map[$node_api].MaxAmountofReferencesFromSingleChildObject
        ChildObjectsThatReferenceThisNode = $child_dependents_keys
    }

    $new_tree_node

}

function add_node_to_relationship_recipe_tree {
    param( 
        $node_api,
        $parent_node_api,
        $all_objects_map,
        $child_relationships_map,
        $parent_relationships_map,
        $recipe_tree_map,
        $leading_node_to_recipe_file_map,
        $objtriarch_to_recipe_family_tree_map
    )

    $leading_recipe_tree_object_api = add_to_family_recipe_tree_map -node_api $node_api `
                                                                        -parent_relationships_map $parent_relationships_map `
                                                                        -leading_node_to_recipe_file_map $leading_node_to_recipe_file_map `
                                                                        -child_relationships_map $child_relationships_map
        
    $is_new_node = (-not( $recipe_tree_map.ContainsKey($node_api)))
    $has_parent = ( $null -ne $parent_node_api )

    if ( $is_new_node ) {
    <#
        SCENARIO #1:
        ===========================

        When the object (node_api) being iterated on and is not yet an object-api found as a key eBikes_lue within "recipe_tree_map"
        Then create a new node
    
    #>
        $tree_node = create_new_tree_node -node_api $node_api `
                -parent_node_api $parent_node_api `
                -all_objects_map $all_objects_map `
                -recipe_tree_map $recipe_tree_map

        $recipe_tree_map.Add($node_api, $tree_node) | Out-Null

        add_tree_node_to_recipe_family_tree -objtriarch $leading_recipe_tree_object_api `
                                                -tree_node $tree_node `
                                                -objtriarch_to_recipe_family_tree_map $objtriarch_to_recipe_family_tree_map | Out-Null
                                        
        <#
            CONTINUE WITH RECURSIVE APPROACH BY ITERATING OVER ALL CHILD OBJECTS OF 
            THE CURRENT OBJECT NODE BEING ITERATED OVER
        #>
        build_tree_nodes_for_children_relationships_of_current_object -all_objects_map $all_objects_map `
                                                            -child_relationships_map $child_relationships_map `
                                                            -node_api $node_api `
                                                            -recipe_tree_map $recipe_tree_map `
                                                            -leading_node_to_recipe_file_map $leading_node_to_recipe_file_map `
                                                            -objtriarch_to_recipe_family_tree_map $objtriarch_to_recipe_family_tree_map | Out-Null

        
    } elseif ( -not($is_new_node) -and $has_parent ) {

        <#

            WITH THE RECURSIVE APPROACH, THE PARENT NODE WILL BE UPDATED THROUGHOUT THE ITERATIONS 
            AND WE WILL WANT TO CAPTURE ANY CHANGES IN LEVEL AND ADD ANY PARENT IDS YET TO BE 
            SET IN THE PARENTID LIST OF THE CURRENT ITERATING OVER OBJECT NODE

        #>   

        $is_self_referencing_node = ( $parent_node_api -eq $node_api )
        if ( $is_self_referencing_node ) {
            $recipe_tree_map[$node_api] = update_self_referencing_tree_node -node_api $node_api `
                                                                                -all_objects_map $all_objects_map `
                                                                                -recipe_tree_map $recipe_tree_map 
        }

        if ( -not($recipe_tree_map[$node_api].ParentIds.Contains($parent_node_api)) )  {
            $recipe_tree_map[$node_api].ParentIds.Add($parent_node_api) | Out-Null
        } 
     
        $node_level = ($recipe_tree_map[$parent_node_api].Level + 1)
        if ( $node_level -gt $recipe_tree_map[$node_api].Level ) {
            ### IF THE CURRENT PARENT LEVEL OF THE OBJECT NODE BEING ITERATED OVER
            ### IS NOT GREATER THAN THE CURRENT LEVEL THAN DO NOT UPDATE THE LEVEL 
            ### AS IT COULD SET THE LEVEL LOWER THAN IT SHOULD BE
            $recipe_tree_map[$node_api].Level = $node_level

        }
        
    } 

}

function update_self_referencing_tree_node {
    param(
        $node_api,
        $all_objects_map,
        $recipe_tree_map
    )

    $has_already_been_updated = ( $recipe_tree_map[$node_api].IsSelfReferencing -eq $false )
    if ( $has_already_been_updated ) {

        $total_times_self_referenced = $all_objects_map[$node_api].ChildRelationshipsBreakdown[$node_api].total_times_referenced_by_this_object
        $recipe_tree_map[$node_api].IsSelfReferencing = $true
        $recipe_tree_map[$node_api].CountOfSelfReferences = $total_times_self_referenced

    }

    ($recipe_tree_map[$node_api])

}

function build_tree_nodes_for_children_relationships_of_current_object {
    param(
        $all_objects_map,
        $child_relationships_map,
        $node_api,
        $recipe_tree_map,
        $leading_node_to_recipe_file_map,
        $objtriarch_to_recipe_family_tree_map
    )

    foreach ($child_object_api_key in $child_relationships_map.Keys) {

        $nested_child_breakdown = $all_objects_map[$child_object_api_key].ChildRelationshipsBreakdown
        $nested_parents_relationships_map = $all_objects_map[$child_object_api_key].ParentRelationshipsBreakdown

        add_node_to_relationship_recipe_tree -all_objects_map $all_objects_map `
                                                -child_relationships_map $nested_child_breakdown `
                                                -parent_node_api $node_api `
                                                -node_api $child_object_api_key `
                                                -parent_relationships_map $nested_parents_relationships_map `
                                                -recipe_tree_map $recipe_tree_map `
                                                -leading_node_to_recipe_file_map $leading_node_to_recipe_file_map `
                                                -objtriarch_to_recipe_family_tree_map $objtriarch_to_recipe_family_tree_map | Out-Null

    }

}

function add_tree_node_to_recipe_family_tree {
    param(
        $objtriarch, 
        $tree_node,
        $objtriarch_to_recipe_family_tree_map
    )

    if ($objtriarch_to_recipe_family_tree_map.ContainsKey($objtriarch)) {

        $objtriarch_to_recipe_family_tree_map[$objtriarch].Add($tree_node) | Out-Null

    } else {

        $family_tree_nodes = [system.collections.generic.list[PSCustomObject]]::new();
        $family_tree_nodes.Add($tree_node) | Out-Null
        $objtriarch_to_recipe_family_tree_map.Add($objtriarch, $family_tree_nodes) | Out-Null

    }


}


function recursieBikes_te_object_relationships {
    param( 
        $objects, 
        $recipe_tree_map,
        $leading_node_to_recipe_file_map,
        $object_api_to_relationship_breakdown_map,
        $objtriarch_to_recipe_family_tree_map
    )

    for ( $i = 0; $i -lt $objects.Count; $i++ ) {

        $initiating_node_api_name_recursive = $objects[$i].ObjectApiName
        $children_object_api_map = [System.Collections.SortedList]$objects[$i].ChildRelationshipsBreakdown
        $parent_relationships_map = [System.Collections.SortedList]$objects[$i].ParentRelationshipsBreakdown
    
        add_node_to_relationship_recipe_tree -child_relationships_map $children_object_api_map `
                                                -all_objects_map $object_api_to_relationship_breakdown_map `
                                                -node_api $initiating_node_api_name_recursive `
                                                -parent_node_api $null `
                                                -parent_relationships_map $parent_relationships_map `
                                                -recipe_tree_map $recipe_tree_map `
                                                -leading_node_to_recipe_file_map $leading_node_to_recipe_file_map `
                                                -objtriarch_to_recipe_family_tree_map $objtriarch_to_recipe_family_tree_map | Out-Null

    }
    
}




