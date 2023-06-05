if ($env:STOP_SCRIPT -eq $true) { Write-Error -Message 'CHECK .GITHUB-WORKFLOW-TMP/USERPERSONA-LOGS.TXT FOR DETAILS ON SCRIPT CANCELLING' -ErrorAction Stop }

Write-Host "[[ 7 START ]]"

$path_to_project_directory = (Get-Location).path
Import-Module -Force "$path_to_project_directory/shift_left_toolkit/customer-personas/scripts/user-persona-automation.psm1"
Import-Module -Force "$path_to_project_directory/shift_left_toolkit/customer-personas/scripts/7-add-roles-to-users.psm1"

$path_to_github_workflow_tmp_directory = "$path_to_project_directory/.github-workflow-tmp"

$map_username_to_role_info_json = Get-Content -Raw "$path_to_github_workflow_tmp_directory/map_username_to_role_info.json"
$map_username_to_role_info = $map_username_to_role_info_json | ConvertFrom-Json | ConvertTo-Hashtable
assign_roles_to_users -map_username_to_role_info $map_username_to_role_info

Write-Host "[[ 7 END ]]"
