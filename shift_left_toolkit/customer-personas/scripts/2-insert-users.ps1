if ($env:STOP_SCRIPT -eq $true) { Write-Error -Message 'CHECK .GITHUB-WORKFLOW-TMP/USERPERSONA-LOGS.TXT FOR DETAILS ON SCRIPT CANCELLING' -ErrorAction Stop }

Write-Host "[[ 2 START ]]"

$path_to_project_directory = (Get-Location).path
Import-Module -Force "$path_to_project_directory/shift_left_toolkit/customer-personas/scripts/user-persona-automation.psm1"
Import-Module -Force "$path_to_project_directory/shift_left_toolkit/customer-personas/scripts/2-insert-users.psm1"

$path_to_github_workflow_tmp_directory = "$path_to_project_directory/.github-workflow-tmp"

$path_to_user_personas_directory = "$path_to_project_directory/shift_left_toolkit/customer-personas"
$path_to_user_detail_json = "$path_to_user_personas_directory/persona-detail.json"

[array]$active_user_personas = get_active_user_personas_from_user_detailjson -path_to_project_directory $path_to_project_directory    

Write-Host "`$active_user_personas.count() is $($active_user_personas.count)"
Write-Host "`$active_user_personas is"
$active_user_personas

# return here
$map_username_to_profile_info_json = Get-Content -Raw "$path_to_github_workflow_tmp_directory/map_username_to_profile_info.json"
$map_username_to_profile_info = $map_username_to_profile_info_json | ConvertFrom-Json | ConvertTo-Hashtable

insert_users -map_username_to_profile_info $map_username_to_profile_info -user_personas $active_user_personas

Write-Host "[[ 2 END ]]"
