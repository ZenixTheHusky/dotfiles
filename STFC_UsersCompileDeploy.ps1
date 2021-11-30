#Put this file in C:\Users\<USERNAME>\Documents\MicrosoftPowerShell\Microsoft.PowerShell_profile.ps1
#Anything that takes flags needs to be made a function before having an alias set.

<# 
    1. Check if Payara has started
        a. If started - do nothing
        b. if not started - start payara w/ default domain
    2. Check if local-db started
        a. If started - do nothing
        b. if not started - start db
    3. Maven compile Users
    4. Deploy wars
    5. check if on VPN - Add warning if not incase they intend to log in with FedID
    6. Use Windows notifications to inform when script finishes.
#>

Function Grant-NonSecure-Maven-Mirrors {
    
    #    Used to remove the mirror that blocks all HTTP repo connections. 
    #    Sources the current maven install directory and edits the settings.xml file to remove the mirror.
    #
    #    This is done once and places a blank file in the directory. Each time the script is run, it checks
    #    to see if the file is present. If it is there then we skip the rest of the function.

    # Get maven install location
    if([string]::IsNullOrEmpty($env:M2_HOME)){
        Write-Host "Maven home Sys Variable not set." -ForegroundColor DarkYellow 
        Write-Host "Getting current Maven install location..." -ForegroundColor DarkYellow 
        $mvn_ver = mvn --version;
        $mvn_install_loc = Out-String -InputObject $mvn_ver -Stream | Select-String "Maven home:"; 
        $mvn_install_loc = $mvn_install_loc -replace 'Maven home: ', ''
        $env:M2_HOME = $mvn_install_loc;
        Write-Host "Maven installed at: " + $env:M2_HOME;
    }

    #Remove mirror | Assumes there is only one mirror which is the blocker
    $XPathMirrors = "//dns:mirrors"
    $XPathMirror = "//dns:mirror" # Child elements of 'mirrors'

    try {
        # Open settings file and get the namespace
        [xml] $settingsXML = (Get-Content $env:M2_HOME\conf\settings.xml -ErrorAction Stop)
        $mgr = New-Object -TypeName System.Xml.XmlNamespaceManager -ArgumentList $settingsXML.NameTable
        $mgr.AddNamespace("dns", $settingsXML.DocumentElement.NamespaceURI)

        # Using the namespace, select the mirror node and remove it
        $mirror = $settingsXML.SelectSingleNode($XPathMirror, $mgr)
        $mirrors = $settingsXML.SelectSingleNode($XPathMirrors, $mgr)
        [void] $mirrors.RemoveChild($mirror)

        # Save the new XML back to the settings file (this requires admin elevation). Then write the blank file to use as a completion flag.
        $settingsXML.save($env:M2_HOME + "\conf\settings.xml")
        Write-Output $null >> $env:M2_HOME\conf\STFC_UsersCompileDeploy_RunFlag
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        Write-Host "Failed to open the Maven settings file in" $env:M2_HOME\conf\settings.xml -ForegroundColor Red
    }
    catch [System.Management.Automation.MethodInvocationException]{
        Write-Host "Mirror node not found. Nothing to save." -ForegroundColor Yellow
    }    
    
}

Function Start-Payara {
    Write-Host "Starting Payara..." -ForegroundColor Green

    asadmin start-domain --domaindir C:\payara\domains domain1
}
Function Stop-Payara {
    asadmin stop-domain --domaindir c:\payara\domains
}

Function Start-LocalDB {
    Write-Host "Checking Local-DB..." -ForegroundColor DarkYellow
    $container_name = "docker-orchestration_bisapps-db_1"
    $check = wsl docker container inspect -f '{{.State.Status}}' $container_name
    if ( $check -eq "running" ) {
        Write-Host "$container_name already started!" -ForegroundColor Green
    } else {
        Write-Host "$container_name not started. Starting in background..." -ForegroundColor DarkYellow
        Start-Job -Name $container_name -ScriptBlock {fba-compose up bisapps-db}
        Write-Host "$container_name started." -ForegroundColor Green
    }

}

Function Remove-Payara-WARs {
    # Undeploys all user WARs from Payara by filtering the output of {@code asadmin list-applications}
    #  using the Select-String statement

    Write-Host "Removing old WAR files from Payara..." -ForegroundColor Green
    
    $apps = asadmin list-applications; 
    $apps_concat = Out-String -InputObject $apps -Stream | Select-String "users"; 
    if (![string]::IsNullOrEmpty($apps_concat)){
        foreach ($line in $apps_concat){
            asadmin undeploy ($line -split(" "))[0]
        }
    }
}

Function Install-Payara-WARs {
    Write-Host "Deploying User WAR files to Payara..." -ForegroundColor Green 
    asadmin deploy C:\Programming\Users\users\users-frontend-war\target\*.war;
    asadmin deploy C:\Programming\Users\users\users-services-war\target\*.war;
}

Function compileUsers {
    Write-Host "Compiling Users project..." -ForegroundColor Green 
    mvn clean install -f C:\Programming\Users\users
}

Function deployWars {
    Start-LocalDB
    if (-not(Test-Path -Path $env:M2_HOME\conf\STFC_UsersCompileDeploy_RunFlag -PathType Leaf)) {
        Write-Host "A Mirror blocking Maven's access to HTTP servers must be removed." -ForegroundColor DarkYellow
        Write-Host "Press Enter and type in your 03 account details. This only has to be done once." -ForegroundColor DarkYellow
        pause
        $UACProcess = Start-Process powershell -ArgumentList {-command "&{. C:\Users\hyn87611\Documents\WindowsPowerShell\STFC_UsersCompileDeploy.ps1; Grant-NonSecure-Maven-Mirrors}" -PassThru -Wait} -verb RunAs
        #$UACProcess.GetType().GetField('exitCode', 'NonPublic, Instance').GetValue($UACProcess)
        Write-Host "Done." -ForegroundColor Green
    }

    & compileUsers
    & Start-Payara
    & Start-LocalDB
    & Remove-Payara-WARs
    & Install-Payara-WARs
}

# if (!(Test-Path -Path $PROFILE)) {
#     New-Item –Path $Profile –Type File
#     Add-Content $PROFILE $env:USERPROFILE'\Documents\WindowsPowerShell\STFC_UsersCompileDeploy.ps1'
# }