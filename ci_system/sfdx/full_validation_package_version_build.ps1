param( 
    $package_name,
    $devhub_alias
)

Write-host "devhub: $($devhub_alias.length)"
Write-host "package_name: $($package_name.length)"

$devhub_alias = $devhub_alias.trim()
$package_name = $package_name.trim()

Write-host "devhub: $($devhub_alias.length)"
Write-host "package_name: $($package_name.length)"

Write-Host "sfdx force:package:version:create -v $devhub_alias --package $package_name --codecoverage --installationkeybypass --wait 120 --json "
$result_json = $( sfdx force:package:version:create -v $devhub_alias --package $package_name --codecoverage --installationkeybypass --wait 120 --json  )  

Write-Host "package version creation result json: $result_json "
$package_version_creation_result = $result_json | ConvertFrom-Json

### 0 status return -> success, non-zero status -> failure
if ( $package_version_creation_result.status -ne 0 ) {

    Write-Host "$package_version_creation_result_json"
    Throw "THERE WAS AN ISSUE PERFORMING QUICK PACKAGE VERSION BUILD SEE ABOVE JSON RESULTS FOR FURTHER ERROR DETAILS"

} else {

    $subscriber_package_version_id = $package_version_creation_result.result.SubscriberPackageVersionId
    Write-Host "subscriber_package_version_id: $subscriber_package_version_id"
    ### SET SUBSCRIBER ID AS GITHUB OUTPUT ACCESSIBLE FOR DOWNSTREAM STEPS/JOBS
    "full_build_package_version_subscriber_id=$subscriber_package_version_id" >> $env:GITHUB_OUTPUT

}
