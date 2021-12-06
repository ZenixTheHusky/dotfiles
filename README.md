# dotfiles
Personal Dot Files used for work and home.

## STFC PowerShell dotfile

### Setup

0. Enable unrestricted script execution: `Set-ExecutionPolicy Unrestricted -Scope LocalMachine` as admin.
1. Make sure you have a PowerShell profile created. See [here](https://www.howtogeek.com/126469/how-to-create-a-powershell-profile/) to find out how to create a profile if you don't already have one.
2. Download the script from [here](https://raw.githubusercontent.com/ZenixTheHusky/dotfiles/main/STFC_UsersCompileDeploy.ps1). Do this by right clicking on the page and selecting "Save Page As..." in FireFox, or "Save As..." in Chrome. (If using Chrome, make sure that the file is saved as a `.ps1` file format, not a `.txt` format.)
3. Place the file in the same folder as your PS Profile (C:\Users\\[FED ID]\Documents\WindowsPowerShell)
4. In the newly created profile, add the line `Import-Module .\STFC_UsersCompileDeploy.ps1 -Force`
5. Close and reopen any existing PowerShell windows and try executing the command `deploywars`. This command will start the local DB, Payara, compile the Users WAR files, and redeploy them onto the Payara server. 

Notes:
1. The Local-DB is started in the background using the `Start-Job` function provided by PowerShell. To stop the Local-DB, the script provides the command `Stop-LocalDB` which stops and removes the job.
2. Payara is not started in the background but a similar command exists to stop it, called `Stop-Payara`
3. If you have not allowed non-secure Maven repos, you can run the command `Grant-NonSecure-Maven-Mirrors` in an admin PowerShell session. This removes the mirror that redirects any non-secure HTTP connections. This must be done to use the version of Maven you installed during the 'Installing Maven' section of the Developer Software wiki pages.

---
| Function Name                 | Description                                                                                   |
|-------------------------------|-----------------------------------------------------------------------------------------------|
| Grant-NonSecure-Maven-Mirrors | Can be called to remove the pre-existing mirror that blocks non-secure HTTP repos.            |
| Start-Payara                  | Starts Payara on the local machine.                                                           |
| Stop-Payara                   | Stops Payara on the local machine.                                                            |
| Start-LocalDB                 | Starts the local DB in the background.                                                        |
| Stop-LocalDB                  | Stops the local DB.                                                                           |
| Remove-Payara-WARs            | Removes all Java WAR files from Payara.                                                       |
| Install-Payara-WARs           | Adds Users WAR files to Payara.                                                               |
| compileUsers                  | Compiles the Users project.                                                                   |
| deployWars                    | Calls Start-Payara, Start-LocalDB, compileUsers, Remove-Payara-WARs, and Install-Payara-WARs. |

### See it in action:
[![asciicast](https://asciinema.org/a/3k6AjYdkJo5W0RQvIqbJ0n0ga.svg)](https://asciinema.org/a/3k6AjYdkJo5W0RQvIqbJ0n0ga)