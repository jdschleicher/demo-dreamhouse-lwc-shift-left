
function run_apex_unit_tests {
    param( $scratch_org_alias, $apex_test_classes_to_run )

    $package_classes_only_test_level = "RunSpecifiedTests"

    $comma_separated_list_of_apex_classes = $apex_test_classes_to_run -join ","

    Write-Host "sfdx force:apex:test:run -u $scratch_org_alias --resultformat human --wait 10 --testlevel $package_classes_only_test_level --tests $comma_separated_list_of_apex_classes --codecoverage --json"
    $apex_tests_result_json = $(sfdx force:apex:test:run -u $scratch_org_alias --resultformat human --wait 10 --testlevel $package_classes_only_test_level --tests $comma_separated_list_of_apex_classes --codecoverage --json)

    Write-Host "COMPLETE JSON TEST RESULT: $apex_tests_result_json"
    $apex_tests_result = $apex_tests_result_json | ConvertFrom-Json

    if ( ($apex_tests_result.status -eq 0 ) -and 
            ($apex_tests_result.result.summary.outcome -ne 'Passed') -and
            ($apex_tests_result.result.summary.outcome -ne 'Skipped') ) {
            
        Write-Host '1 OR MORE UNIT TESTS FAILED'
        $failed_tests = $apex_tests_result.result.tests | Where-Object { $_.Outcome -eq 'Fail' }
        Write-Host "FAILED TESTS: "
        foreach ($fail in $failed_tests ) {
            Write-Host $fail.FullName
        }            

        Throw "UNIT TESTS FAILED"
        
    } elseif ( $apex_tests_result.status -ne 0 ) {

        Throw "UNIT TESTS CALLOUT FAILED"

    }
    
    $apex_tests_result

}

function perform_code_coverage_check {
    param( $scratch_org_alias, $apex_files )

    # EXIT 0 = SUCCESS/ EXIT 1 = FAILURE AND STOP WORKFLOW ENTIRELY
    $fail_result = 1
    $result = 0

    $code_coverage = calculate_code_coverage $scratch_org_alias -apex_files $apex_files
    Write-Host 'CURRENT CODE COVERAGE: ' $code_coverage'%'
    if ($code_coverage -lt 75) {
        Write-Host Your "organization's" code coverage is $code_coverage'%'  "You need at least 75% coverage to complete this deployment"
        $result = $fail_result
    }

    $result

}

function calculate_code_coverage {
    param( $scratch_org_alias, $apex_files )

    $query_comma_separated_apex_files = $apex_files | Join-String -SingleQuote -Separator ','

    $query_result_json = $(sfdx force:data:soql:query -q "SELECT ApexClassOrTriggerId, ApexClassOrTrigger.Name, NumLinesUncovered,NumLinesCovered `
                                                        FROM ApexCodeCoverageAggregate `
                                                        WHERE ApexClassOrTriggerId != NULL `
                                                            AND ApexClassOrTrigger.Name!= NULL `
                                                            AND NumLinesUncovered != NULL `
                                                            AND NumLinesCovered!= NULL `
                                                            AND ApexClassOrTriggerId in `
                                                                (Select Id from ApexClass where Name IN ($query_comma_separated_apex_files)) `
                                                        ORDER BY ApexClassOrTrigger.Name" ` --usetoolingapi -u $scratch_org_alias  --json)

    Write-Host "json code coverage query result: $query_result_json"
    $query_result_object = $query_result_json | ConvertFrom-Json
    $uncovered_lines = 0
    $covered_lines = 0
    foreach ($result in $query_result_object.result.records) {
        $uncovered_lines += $result.NumLinesUncovered
        $covered_lines += $result.NumLinesCovered
    }
    $total_lines = $uncovered_lines + $covered_lines
    $coverage_percentage = 100 * ($covered_lines / $total_lines)
    $coverage_percentage = [math]::Round($coverage_percentage)
    $coverage_percentage
    
}

