# The purpose of this script is to clean up VMware DEM profiles for users that have been deleted from Active Directory
# Profile directory names are compared to a list of AD users, if the user object does not exist the directory
# is moved to an Archive folder, where after a specified number of days it's deleted.
# You must install the RSAT Active Directory Module for Windows Powershell from Server Manager to run this script
# Typically you would schedule this to run as a periodic task on your DEM manager server.
# powershell.exe -ExecutionPolicy Unrestricted -command "E:\DEMCleanup\DEMcleanup.ps1"

# Written by Rick Redfern, last updated 28 Apr 2022

# Modify these properties for your environment
$demProfilePath = "E:\DEMprofiles"				# Your default DEM profile directory
$demCleanupPath = "E:\DEMCleanup"				# Directory for this script, logfiles, and Archive
$demArchivePath = "$demCleanupPath\Archive"		# Archive directory for stale profiles to be moved to
$adName = "company.com"						    # Your Active Directory name
$adNetBiosName = "company"						# Your Active Directory NetBIOS name
$adFQDN = "OU=Users,DC=company,DC=com"			# Your Active Directory fully qualified domain name, user OU is optional
$daysToKeepArchive = 30						    # Number of days to keep stale profiles before deletion

# Active Directory Powershell module must be imported
if (!(Get-Module -Name ActiveDirectory)) {
    try {
        Import-Module -Name ActiveDirectory
    } catch {
        Write-Host "You must add the RSAT Active Directory Module for Windows Powershell from Server Manager to run this script"
        Exit
    }
}

# Create the Archive folder if it doesn't already exist
If(!(test-path $demArchivePath)) {
      New-Item -ItemType Directory -Force -Path $demArchivePath
}

# Grab the list of profiles and AD users and put them in arrays
$demProfiles = Get-ChildItem $demProfilePath | Select-Object Name
$adUsers = Get-ADUser -Filter * -SearchBase $adFQDN | Select-Object SamAccountName
$diff = 0
$diff2 = 0

# Logging
function Log {
    param(
		[Parameter(Mandatory)]
		[string]$content
	)

    # Build this month's log file name
    $logFileName = "logfile_"
    $d = Get-Date
    switch ($d.Month) {
        1 {$logFileName += "Jan_"}
        2 {$logFileName += "Feb_"}
        3 {$logFileName += "Mar_"}
        4 {$logFileName += "Apr_"}
        5 {$logFileName += "May_"}
        6 {$logFileName += "Jun_"}
        7 {$logFileName += "Jul_"}
        8 {$logFileName += "Aug_"}
        9 {$logFileName += "Sep_"}
        10 {$logFileName += "Oct_"}
        11 {$logFileName += "Nov_"}
        12 {$logFileName += "Dec_"}
    }
    $logFileName += "$($d.Year).txt"

    #Write the content to the logfile
    "$(Get-Date)" + "  " + "$($content)" | Out-File -FilePath "$demCleanupPath\$logFileName" -Append
}

# Check to make sure AD is available and the list of AD users is populated
$ADcheck = Get-ADDomain -Identity $adName
if (($ADcheck.Name -ne $adNetBiosName) -or ($adUsers.Count -eq 0)) {
    Log "Active Directory error - exiting script."
    Log "No changes made."
    Log "------------------------------------------------"
    Exit
}

# Convert the arrays to strings and make them all lowercase to ensure comparisons don't fail for string case
$dp = $demProfiles | ForEach-Object {"$($_.Name)"}
$lu = $adUsers | ForEach-Object {"$($_.SamAccountName)"}
$dpl = $dp.ToLower()
$lul = $lu.ToLower()

Log "$($dpl.count) profiles in $demCleanupPath"
Log "$($lul.count) user objects in $adName"

# Iterate the profile array and move any profiles that do not have a corresponding AD user object
$dpl | ForEach-Object {
    if (!$lul.Contains($_)) {
        Move-Item -Path "$demCleanupPath\$_" -Destination $demArchivePath
        # Change the last modified date of the archived folder so we know when it got moved
        (Get-Item "$demArchivePath\$_").LastWriteTime = (Get-Date)
        Log "$($_) archived"
        $diff = $diff + 1
    }
}

Log "** $diff profiles archived"

# Delete any profiles archived more than 30 days ago
$bakProfiles = Get-ChildItem $demArchivePath | Select-Object Name
$bakFolders = $bakProfiles | ForEach-Object {"$($_.Name)"}
$bakFolders | ForEach-Object {
    if ([int]((Get-Item "$demArchivePath\$_" | New-TimeSpan).Days) -gt $daysToKeepArchive) {
        Remove-Item -Path "$demArchivePath\$_" -Recurse -Force
        Log "$($_) deleted"
        $diff2 = $diff2 + 1
    }
}
Log "** $diff2 archived profiles deleted"

Log "------------------------------------------------"
