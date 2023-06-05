Import-Module -Force ./shift_left_toolkit/data-faker-station/scripts/generate_recipe_by_repository.psm1
Import-Module -Force ./shift_left_toolkit/data-faker-station/scripts/objtriarchy_relationships_service.psm1

$stopwatch =  [system.diagnostics.stopwatch]::StartNew()

$names_of_current_directory_child_items = Get-ChildItem | foreach name
$current_directory_contains_shift_left_toolkit_directory = $names_of_current_directory_child_items -contains 'shift_left_toolkit'

if ($current_directory_contains_shift_left_toolkit_directory) {

    $timestamp = ([datetime]::now).ToString('yyyyMMdd-HHmm')

    $timestamped_recipe_generation_directory = create_generated_recipe_timestamped_directory -timestamp $timestamp

    $object_api_to_relationship_breakdown_map = generate_snowfakery_recipe_from_repository -timestamped_recipe_generation_directory $timestamped_recipe_generation_directory
    
    $objtriarch_to_recipe_family_tree_map = $(build_objtriarch_to_recipe_family_tree_map_by_object_api_relationship_breakdown -object_api_to_relationship_breakdown_map $object_api_to_relationship_breakdown_map `
                                                -objtriarch_to_recipe_family_tree_map $objtriarch_to_recipe_family_tree_map `
                                                -timestamped_recipe_generation_directory $timestamped_recipe_generation_directory)
    
    build_recipes -objtriarch_to_recipe_family_tree_map $objtriarch_to_recipe_family_tree_map `
                    -timestamped_recipe_generation_directory $timestamped_recipe_generation_directory `
                    -timestamp $timestamp

} else {
    Write-Error -Message "ERROR: THIS SCRIPT MUST RUN FROM eBikes_-salesforce-dojo DIRECTORY CONTAINING SHIFT_LEFT_TOOLKIT DIRECTORY" -ErrorAction Stop
}

$elapsed_seconds = $stopwatch.ElapsedMilliseconds/1000
Write-Host "Snowfakery Recipe Generation completed in $elapsed_seconds seconds"