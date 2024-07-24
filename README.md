# AS3_converter
## General scripting flow
![diagram](https://github.com/user-attachments/assets/e53f3b79-f90b-48c8-b874-2a205d7d9e6a)
## Description
1. The script flow starts with the YAML report and CSV outputs from the flipper tool.
### Example
#### CSV  
![csv_flipper](https://github.com/user-attachments/assets/57e01576-1219-41fd-b0ad-a2ec1be2c147)
#### Flipper report
![flipper_report](https://github.com/user-attachments/assets/d463ca63-2fc3-4cdd-8a4f-837cda5e80b8)

2. The Codefinder PowerShell  uses the CSV file against the YAML report to give us one JSON file per application found on the CSV file.
#### Codefinder inputs
```
# Define the path to the CSV file containing names
$csvFilePath = "report.csv"

# Define the path to the source file
$sourceFilePath = "report.yml"

# Define the path to the output file
$outputFolderPath = "output_folder"

```

3. The converter script takes as an input the JSON files from the Codefinder and gives us the as3 files per application
4. 

