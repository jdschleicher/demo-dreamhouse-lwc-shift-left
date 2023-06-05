$default_package_detail = $null
$sfdxprojectjson_path = "sfdx-project.json"
if ( -not(Test-Path $sfdxprojectjson_path) ) {
    
    throw "sfdx-project.json doesn't exist"

}  else {

    $sfdxprojectjson_content = Get-Content $sfdxprojectjson_path
    $sfdxproject_detail = $sfdxprojectjson_content | ConvertFrom-Json
    $default_package_detail = $sfdxproject_detail.packageDirectories | Where { $_.default -eq $true} 

}

Write-Host -ForegroundColor Blue -BackgroundColor White "DEFAULT PROJECT DETAIL: $sfdxprojectjson_content"

# THE BELOW SYNTAX OF ">> $env:GITHUB_OUTPUT" ALLOWS FOR GH ACTIONS TO CAPTURE THESE VALUES AND AVAILABLE FOR
# ANY NECESSARY SEQUENTIAL JOBS OR STEPS WHERE THE VALUES WOULD NOT BE AVAILABLE IN THE NEW CONTEXT
$default_package_name = $default_package_detail.package
Write-Host "default package name: $default_package_name"
"default_package_name=$default_package_name" >> $env:GITHUB_OUTPUT

$default_package_directory = $default_package_detail.path
Write-Host "default_package_directory: $default_package_directory"
"default_package_directory=$default_package_directory" >> $env:GITHUB_OUTPUT

### SPLITTING BY .NEXT GRABS major.minor.patch convention from expected release version pattern of 1.0.0.NEXT
### THE ZERO INDEX GRAPS THE FIRST RESULT OF THE SPLIT WICH IS THE VERSION DETAIL
$latest_package_version = $default_package_detail.versionNumber.split(".NEXT")[0]
Write-Host "latest_package_version: $latest_package_version"
"latest_package_version=$latest_package_version" >> $env:GITHUB_OUTPUT

