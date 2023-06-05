param( $org_alias, $auth_url)

Write-Host "AUTHENTICATING SALESFORCE ORG (VIA AUTH URL)" 

$key_file = "auth_url.key"

New-Item -Type File $key_file | Out-Null
$auth_url | Out-File $key_file

$auth_result_json = $(sfdx auth:sfdxurl:store -f $key_file -a $org_alias --json)
$auth_result = $auth_result_json| ConvertFrom-Json

Remove-Item -Force $key_file
$auth_result.status

