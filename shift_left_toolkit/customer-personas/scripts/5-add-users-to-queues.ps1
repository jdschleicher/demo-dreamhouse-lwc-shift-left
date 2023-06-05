if ($env:STOP_SCRIPT -eq $true) { Write-Error -Message 'CHECK .GITHUB-WORKFLOW-TMP/USERPERSONA-LOGS.TXT FOR DETAILS ON SCRIPT CANCELLING' -ErrorAction Stop }

Write-Host "[[ 5 START ]]"

$path_to_project_directory = (Get-Location).path
Import-Module -Force "$path_to_project_directory/shift_left_toolkit/customer-personas/scripts/user-persona-automation.psm1"
Import-Module -Force "$path_to_project_directory/shift_left_toolkit/customer-personas/scripts/5-add-users-to-queues.psm1"

$path_to_github_workflow_tmp_directory = "$path_to_project_directory/.github-workflow-tmp"

# INITIALIZE $PERMSETID_USERNAME_LIST
$map_username_to_queue_info_json = Get-Content -Raw "$path_to_github_workflow_tmp_directory/map_username_to_queue_info.json"
$map_username_to_queue_info = $map_username_to_queue_info_json | ConvertFrom-Json | ConvertTo-Hashtable
assign_user_queues -map_username_to_queue_info $map_username_to_queue_info

Write-Host "[[ 5 END ]]"
