# DEMCleanup
Powershell script to clean up stale VMware Dynamic Environment Manager profiles

The purpose of this script is to clean up VMware DEM profiles for users that have been deleted from Active Directory
Profile directory names are compared to a list of AD users, if the user object does not exist the directory
is moved to an Archive folder, where after a specified number of days it's deleted.

You must install the RSAT Active Directory Module for Windows Powershell from Server Manager to run this script
Typically you would schedule this to run as a periodic task on your DEM manager server.

Suggested command line for scheduled task:
powershell.exe -ExecutionPolicy Unrestricted -command "E:\DEMCleanup\DEMcleanup.ps1"

Written by Rick Redfern, last updated 28 Apr 2022
