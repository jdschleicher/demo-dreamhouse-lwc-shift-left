if ($env:STOP_SCRIPT -eq $true) { Write-Error -Message 'CHECK .GITHUB-WORKFLOW-TMP/USERPERSONA-LOGS.TXT FOR DETAILS ON SCRIPT CANCELLING' -ErrorAction Stop }

Write-Host "[[ 3 START ]]"

$path_to_project_directory = (Get-Location).path
Import-Module -Force "$path_to_project_directory/shift_left_toolkit/customer-personas/scripts/user-persona-automation.psm1"
Import-Module -Force "$path_to_project_directory/shift_left_toolkit/customer-personas/scripts/3-assign-user-permsets.psm1"

$path_to_github_workflow_tmp_directory = "$path_to_project_directory/.github-workflow-tmp"

# INITIALIZE $PERMSETID_USERNAME_LIST
$map_username_to_permset_info_json = Get-Content -Raw "$path_to_github_workflow_tmp_directory/map_username_to_permset_info.json"
$map_username_to_permset_info = $map_username_to_permset_info_json | ConvertFrom-Json | ConvertTo-Hashtable
assign_user_permsets -map_username_to_permset_info $map_username_to_permset_info

Write-Host "[[ 3 END ]]"
