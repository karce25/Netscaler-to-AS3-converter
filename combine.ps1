# Define the path to the directory containing the AS3 JSON files
$as3FilesPath = "C:\Users\karce\OneDrive - F5, Inc\Documents\Consulting\FIS_combine\lrtc_non_prod_ssl_july22_monitor"

# Get the list of AS3 JSON files in the directory
$as3Files = Get-ChildItem -Path $as3FilesPath -Filter "*as3_.json"

# Initialize the base structure for the merged declaration
$mergedDeclaration = @{
    "class"       = "AS3"
    "action"      = "deploy"
    "persist"     = $true
    "declaration" = @{
        "class"         = "ADC"
        "schemaVersion" = "3.50.0"
        "MergedTenant"  = @{            #CHANGE THE NAME ACCORDING THE DESIRED TENANT
            "class" = "Tenant"
            
        }
    }
}


# Loop through each AS3 file and merge applications
foreach ($file in $as3Files) {
    try {
        # Read and parse the JSON content
        $jsonContent = Get-Content -Path $file.FullName -Raw
        $as3Object = ConvertFrom-Json -InputObject $jsonContent

        # Check if it is a valid AS3 declaration and has a tenant
        if ($as3Object.class -eq 'AS3' -and $as3Object.declaration.class -eq 'ADC') {
            foreach ($tenant in $as3Object.declaration.PSObject.Properties) {
                if ($tenant.Value.class -eq 'Tenant') {
                    foreach ($app in $tenant.Value.PSObject.Properties) {
                      #  Write-Host "the app is $app"
                        if ($app.Value.class -eq 'Application') {
                            # Merge the Application into the "MergedTenant" if it is different change the variable below
                            $mergedDeclaration.declaration.MergedTenant[$app.Name] = $app.Value  
                            
                        }
                    }
                }
            }
        }
    } catch {
        Write-Host "Error processing file: $($file.Name)"
        Write-Host "Error details: $_"
    }
}

# Convert the merged declaration to JSON
$mergedJson = $mergedDeclaration | ConvertTo-Json -Depth 100

# Output the merged JSON to a file
$outputFilePath = "C:\Users\karce\OneDrive - F5, Inc\Documents\Consulting\FIS_combine\output_combined\merged_declaration_lrtc_non_prod_ssl_july22_3.json"
$mergedJson | Out-File -FilePath $outputFilePath -Force

Write-Host "Merged AS3 declaration saved to: $outputFilePath"