
#ENVIRONMENT eBikes_RIABLES BASED OFF OF DEFAULTUSERNAME FOR ORG IN THE sfdx-config.json FILE IN THE .sfdx DIRECTORY AT THE ROOT OF THE PROJECT
# EXAMPLE OF EXPECTED CODE CONTENT IN sfdx-config.json:
##  {
##    "defaultusername": "org_alias"
##  }

$stopwatch =  [system.diagnostics.stopwatch]::StartNew()

$names_of_current_directory_child_items = Get-ChildItem | foreach name
$current_directory_contains_shift_left_toolkit_directory = $names_of_current_directory_child_items -contains 'shift_left_toolkit'

if ($current_directory_contains_shift_left_toolkit_directory) {
    
    . shift_left_toolkit/customer-personas/environment-eBikes_riables-setup/initialize-environment-eBikes_riables.ps1
    . shift_left_toolkit/customer-personas/scripts/0-process-user-persona-json.ps1
    . shift_left_toolkit/customer-personas/scripts/2-insert-users.ps1
    . shift_left_toolkit/customer-personas/scripts/3-assign-user-permsets.ps1
    . shift_left_toolkit/customer-personas/scripts/4-set-user-passwords.ps1
    . shift_left_toolkit/customer-personas/scripts/5-add-users-to-queues.ps1
    . shift_left_toolkit/customer-personas/scripts/6-add-users-to-groups.ps1
    . shift_left_toolkit/customer-personas/scripts/7-add-roles-to-users.ps1

}
else {
    Write-Error -Message "ERROR: THIS SCRIPT MUST RUN FROM eBikes_-salesforce-dojo DIRECTORY CONTAINING SHIFT_LEFT_TOOLKIT DIRECTORY" -ErrorAction Stop
}

$elapsed_seconds = $stopwatch.ElapsedMilliseconds/1000
Write-Host "User Personas Setup completed in $elapsed_seconds seconds"
