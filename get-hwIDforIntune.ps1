# Step 1: Ensure Execution Policy allows running scripts (run as Admin)
# You might need to adjust this based on your environment's policies.
# 'Process' scope affects only the current PowerShell session.
Set-ExecutionPolicy RemoteSigned -Scope Process -Force

# Step 2: Install the necessary PowerShell module from the PowerShell Gallery
# This module contains the Get-WindowsAutoPilotInfo script.
Install-Module WindowsAutopilotIntune -Force

# Step 3: Run the script to capture the hardware hash and save it to a CSV file
# You can change the path 'C:\DeviceHash.csv' if needed.
Get-WindowsAutopilotInfo -OutputFile C:\DeviceHash.csv