# Define the path to the CSV file containing names
$csvFilePath = "report.csv"

# Define the path to the source file
$sourceFilePath = "report.yml"

# Define the path to the output file
$outputFolderPath = "output_folder"

# Read the CSV file
$csvData = Import-Csv $csvFilePath

# Loop through each row in the CSV file
foreach ($row in $csvData) {
    $name = $row.Name
    $outputFileName = "$outputFolderPath\$name.json"
    # Search for the name in the source file and collect text until the delimiter is found
    $collectText = $false
    $output = @()
    Write-Host "Looking for $name in source file"
    Get-Content $sourceFilePath | ForEach-Object {
        if ($_ -like "name: $name*") {
            Write-Host "I found an entry of $name"
            # Name found, start collecting text
            $collectText = $true
        }

        if ($collectText) {
            # Collect text lines
            $output += $_
        }

        if ($_ -eq "--- ##################################################") {
            # Delimiter found, stop collecting text
            $collectText = $false
        }
    }
    #convert to JSON
    $jsonOutput = $output

    Set-Content -Path $outputFileName -Value $jsonOutput
    Write-Host "Output for $name written to output file"

}

Write-Host "Processing complete. Output"
