param(
    [Parameter(Mandatory=$true)]
    $org_alias
)

$path_to_project_directory = (Get-Location).path
$path_to_org_data_seeding_directory = "$path_to_project_directory/shift_left_toolkit/data-faker-station"
$path_to_scripts_directory = "$path_to_project_directory/shift_left_toolkit/data-faker-station/scripts"
$data_config_file_name = 'config-data-seeding.json'

Import-Module -Force -DisableNameChecking "$path_to_scripts_directory/apply_data_config.psm1"
Import-Module -Force -DisableNameChecking "$path_to_scripts_directory/generate-dataset-deployment.psm1"

Write-Host "RUNNING APPLY_DATA_CONFIG_FILE ON $($data_config_file_name.ToUpper())"
$path_to_data_config_file = "$path_to_org_data_seeding_directory/$data_config_file_name"
apply_data_config_file -path_to_data_config_file $path_to_data_config_file -path_project_directory $path_to_org_data_seeding_directory -org_alias $org_alias
