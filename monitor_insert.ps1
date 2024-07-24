# Define the path to the AS3.json files and the CSV file
$as3FolderPath = "as3_output_converter_folder"
$csvFilePath = "monitors_name.csv"

# Read the list of names and monitors from the CSV file
$csvEntries = Import-Csv -Path $csvFilePath

# Get all AS3.json files from the input folder
$jsonFiles = Get-ChildItem -Path $as3FolderPath -Filter "*as3_.json"

# Loop through each JSON file
foreach ($jsonFile in $jsonFiles) {
    # Find the corresponding entry from the CSV by matching the filename
    $csvEntry = $csvEntries | Where-Object { $_.Name -eq $jsonFile.BaseName }
    #Write-Host ("csv entry is $csvEntry")
    
    # Proceed only if a matching entry is found
    if ($csvEntry) {
        # Read the content of the JSON file
        $jsonContent = Get-Content -Path $jsonFile.FullName -Raw | ConvertFrom-Json
        
        # Loop through each tenant in the declaration
        foreach ($tenantKey in $jsonContent.declaration.PSObject.Properties.Name) {
            $tenant = $jsonContent.declaration.$tenantKey
            # Check if it is a valid Tenant object
            if ($tenant.class -eq 'Tenant') {
                # Loop through each application within the tenant
                foreach ($appKey in $tenant.PSObject.Properties.Name) {
                    $application = $tenant.$appKey
                    # Check if it is a valid Application object
                    if ($application.class -eq 'Application') {
                        # Loop through each service within the application
                        foreach ($serviceKey in $application.PSObject.Properties.Name) {
                            $service = $application.$serviceKey

                            if ($service.pool) {
                             
                                $poolName = $service.pool
                                $pool = $application.$poolName
                              
                                if ($pool -and $pool.class -eq 'Pool') {
                                    $monitor_name = $csvEntry.Monitors
                                    # Replace the existing monitors array with the new monitor using the name from the CSV
                                    $pool.monitors = @(
                                        @{
                                            "bigip" = "/Common/Shared/$monitor_name"
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        
        # Convert the modified object back to JSON 
        $updatedJsonContent = $jsonContent | ConvertTo-Json -Depth 10
        
        # Write the updated JSON content back to the file
        Set-Content -Path $jsonFile.FullName -Value $updatedJsonContent
        Write-Host "Updated file: $($jsonFile.FullName)"
    }
}

Write-Host "All monitors completed"
