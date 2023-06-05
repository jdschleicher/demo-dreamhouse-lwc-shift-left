param($org_to_install_alias, $subscriber_package_version_id)

Write-Host "INSTALLING PACKAGE"
Write-Host "org alias: $org_to_install_alias"
Write-Host "package_version_id: $subscriber_package_version_id"

$install_package_result_json = $( sfdx force:package:install --noprompt --targetusername $org_to_install_alias --wait 20 --package $subscriber_package_version_id --upgradetype Delete --loglevel trace --json )
Write-Host $install_package_result_json
$install_package_result = $install_package_result_json| ConvertFrom-Json

$install_package_result.status