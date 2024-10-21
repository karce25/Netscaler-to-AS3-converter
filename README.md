# AS3_converter
## General  flow
![diagram](https://github.com/user-attachments/assets/e53f3b79-f90b-48c8-b874-2a205d7d9e6a)
## Description
1. The script flow starts with the YAML report and CSV outputs from the flipper tool.
### Example
#### CSV  
![csv_flipper](https://github.com/user-attachments/assets/57e01576-1219-41fd-b0ad-a2ec1be2c147)
#### Flipper report
![flipper_report](https://github.com/user-attachments/assets/d463ca63-2fc3-4cdd-8a4f-837cda5e80b8)

Note: The CSV file should have column names like the following example:

![image](https://github.com/user-attachments/assets/22d973ab-ad10-4f79-9159-e66e72685754)


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

3. The converter script takes as an input the JSON files from the Codefinder and gives us the AS3 files per application, the converter script assigns variables based on the YAML files provided by Flipper and then selects an AS3 template based on the virtual server protocol.
**Things that currently are not being handled by the script:**
 - _Custom  monitors under Netscaler services (Service-groups work correctly)_
 - _Listen policies: Currently, the scripts only create a txt file with the listen policy that needs to be created manually with an iRule._
 - _Backup vservers: Currently the script only creates a txt file with the Virtual Servers that contain backup vservers and needs to handle that through priority groups._
 - _Chain CA certs: Currently, the script creates the Chain CA cert statically for all SSL AS3 templates._
  
5. Once we have the AS3 JSON files from the converter script we run the monitor_insert script which needs a CSV file with 2 columns (Name and Monitors) the name column should match the name of the AS3 file, for example: **VIP-name_as3_**, the name of the monitor will be configured inside each file that matches the name column.

```
if ($pool -and $pool.class -eq 'Pool') {
    $monitor_name = $csvEntry.Monitors
    # Replace the existing monitors array with the new monitor using the name from the CSV
    $pool.monitors = @(
        @{
            "bigip" = "/Common/Shared/$monitor_name"
        }

```
6. The monitor_insert script will configure all the custom monitors inside each AS3 file (these custom monitors need to be configured inside the Common/Shared partition), once we have the modified files, we run the combined script which will create a single tenant with all the applications on each AS3 file, the combined script needs the name of the new file, for example

```
# Output the merged JSON to a file
$outputFilePath = "merged_declaration_1.json"
$mergedJson | Out-File -FilePath $outputFilePath -Force

```
7. Two things need to be edited:
  - AS3 and ADC classes will appear at the end and must be configured at the beginning.
  - The tenant class needs to be configured under the tenant name.
    - Example:
```
        "schemaVersion": "3.50.0",
        "class": "ADC"
    },
    "class": "AS3",
    "action": "deploy"

```
Needs to be rewritten at the top:

```
{
    "class": "AS3",
    "action": "deploy",
    "$schema": "https://raw.githubusercontent.com/F5Networks/f5-appsvcs-extension/master/schema/latest/as3-schema.json",
    "persist": true,
    "declaration": {
        "class": "ADC",
        "schemaVersion": "3.45.0",
        "Merged-tenant": {
            "class": "Tenant",

```

# AS3 partition to Common
## General flow
![AS3-Common](https://github.com/user-attachments/assets/b14223e7-038e-4d90-a8d4-ae390818c4bb)
## Description
1. Once the AS3 declaration is successfully submitted to a BIG-IP lab we need to go inside **/config/partitions/** and extract the bigip.conf from there and rename it in txt format
2. With VSCODE find and replace the partition name with **/Common/** for example **/partition-name/path/vs-test-443 to /Common/path/vs-test-443**
3. With VSCODE find and replace  **/Common/Shared** with **/Common/**
4. Run the imperative.py script which uses regex expressions to remove all the paths from the configuration
5. Finally merge the bigip.txt file to a new LAB VE to test if the configuration is successful (need to place bigip.txt into **/var/local/scf**)
    Example:
   ```
   tmsh
   load /sys config merge file bigip_new.txt verify
   load /sys config merge file bigip_new.txt 
   save /sys config

   ```
   > [!NOTE]
   > https://my.f5.com/manage/s/article/K81271448
   






