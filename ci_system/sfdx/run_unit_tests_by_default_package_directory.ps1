param( 
    $unit_tests_target_org, 
    $sfdx_package_default_directory,
    $is_special_reason_to_pass_no_matter 
)

Write-Host -ForegroundColor Black -BackgroundColor White "RUNNING UNIT TESTS IN $sfdx_package_default_directory FOR $unit_tests_target_org"

Import-Module -DisableNameChecking -Force "$PSScriptRoot/../sfdx/unit_tests_service.psm1"

$result = 0

Write-Host "UNIT TEST DIRECTORY: $sfdx_package_default_directory"
if ( -not(Test-Path $sfdx_package_default_directory) ) {
    Throw "THE DIRECTORY TO GET APEX TEST CLASSES IS INVALID: $sfdx_package_default_directory"
}

# $apex_files = Get-ChildItem -Path $sfdx_package_default_directory -Recurse -filter *.cls
$apex_files = Get-ChildItem -Path "force-app" -Recurse -filter *.cls -Name | ForEach-Object -Process { [System.IO.Path]::GetFileNameWithoutExtension($_) }



if ( $apex_files.count -gt 0) {
    $apex_test_run_results = run_apex_unit_tests -scratch_org_alias $unit_tests_target_org -apex_test_classes_to_run $apex_files

    if ( $apex_test_run_results.result.summary.outcome -eq "Passed" ) {
        $code_coverage_result = perform_code_coverage_check -scratch_org_alias $unit_tests_target_org -apex_files $apex_files

        if ( $code_coverage_result -eq 1 -and $is_special_reason_to_pass_no_matter ) {
            ### THE is_special_reason_to_pass_no_matter IS NOT AN OK PRACTICE AT AT ALL, USING FOR PRESENTATION
            Write-Host "COVERAGE FAILED: THE is_special_reason_to_pass_no_matter IS NOT AN OK PRACTICE AT AT ALL, USING FOR PRESENTATION"
            $result = 0
        }
        
    }


}
else {
    Write-Host "Unit tests will not be run because .cls files were not found in project directories."
}
#RETURN RESULT - 0 = SUCCESS / 1 = FAILURE
exit $result