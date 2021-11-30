#Put this file in C:\Users\<USERNAME>\Documents\MicrosoftPowerShell\Microsoft.PowerShell_profile.ps1
#Anything that takes flags needs to be made a function before having an alias set.
#Set Payara commands to functions
Function openpsadmin {Start-Process powershell -Verb RunAs}
Function windowsterminal {Start-Process wt.exe; Start-Process wt.exe }
Function vsAsAdmin { Start-Process 'C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\Common7\IDE\devenv.exe' -Verb RunAs -argumentlist "C:\Programming\Users\Authenticate\Authenticate.sln"}
Function programming {
    Set-Location C:\programming
}
Function android_emu {
    emulator -avd Pixel_4_API_28 -dns-server 8.8.8.8
}
function U
{
    param
    (
        [int] $Code
    )
 
    if ((0 -le $Code) -and ($Code -le 0xFFFF))
    {
        return [char] $Code
    }
 
    if ((0x10000 -le $Code) -and ($Code -le 0x10FFFF))
    {
        return [char]::ConvertFromUtf32($Code)
    }
 
    throw "Invalid character code $Code"
}
## STFC Functions

Function payara-start {
    asadmin start-domain --domaindir C:\payara\domains domain1
}
Function payara-stop {
    asadmin stop-domain --domaindir c:\payara\domains
}
Function payara-deploy {
    asadmin deploy "C:\Programming\Users\users\users-frontend-war\target\*.war"
    asadmin deploy "C:\Programming\Users\users\users-services-war\target\*.war"
}
Function local-db {
    fba-compose pull bisapps-db; fba-compose up bisapps-db
}

#Set Aliases. Type these into PowerShell to start the functions above.
SET-ALIAS -Name PsAdmin         -Value openpsadmin          #Open a new PowerShell Window as Admin
SET-ALIAS -Name start-term      -Value windowsterminal      #Open a new windows terminal window (if installed)
SET-ALIAS -Name auth            -Value vsAsAdmin            #Start auth in an admin visual studio window
####

Write-Output `
"
__          __   _                            ____             _    
\ \        / /  | |                          |  _ \           | |   
 \ \  /\  / /___| | ___ ___  _ __ ___   ___  | |_) | __ _  ___| | __
  \ \/  \/ // _ \ |/ __/ _ \| '_ `  _ \ / _ \ |  _ < / _`  |/ __| |/ /
   \  /\  /|  __/ | (_| (_) | | | | | |  __/ | |_) | (_| | (__|   < 
    \/  \/  \___|_|\___\___/|_| |_| |_|\___| |____/ \__,_|\___|_|\_\
                                                                    
" | lolcat


$env:path += ";" + (Get-Item "Env:ProgramFiles(x86)").Value + "\Git\bin"
Import-Module posh-git
Import-Module 'oh-my-posh'
Set-PoshPrompt stelbent.minimal
# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}
Push-Location -Path $env:USERPROFILE\Documents\WindowsPowershell
Import-Module .\STFC_UsersCompileDeploy.ps1 -Force
Pop-Location