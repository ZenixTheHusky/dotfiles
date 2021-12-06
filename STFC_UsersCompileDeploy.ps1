#Put this file in C:\Users\<USERNAME>\Documents\MicrosoftPowerShell\

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

        try{
            #Try removing the mirror. Will error out if mirror node does not exist.
            [void] $mirrors.RemoveChild($mirror)
        }
        catch [System.Management.Automation.MethodInvocationException]{
            #If mirror node does not exist, unsecure maven repos will be allowed so we create the flag anyway.
            Write-Host "Mirror node not found. Nothing to save." -ForegroundColor Yellow
        }

        # Save the new XML back to the settings file (this requires admin elevation). Then write the blank file to use as a completion flag.
        $settingsXML.save($env:M2_HOME + "\conf\settings.xml")
        Write-Output $null >> $env:M2_HOME\conf\STFC_UsersCompileDeploy_RunFlag
        Write-Host "Flag created." -ForegroundColor Green
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        Write-Host "Failed to open the Maven settings file in" $env:M2_HOME\conf\settings.xml -ForegroundColor Red
    }
    
}

Function Start-Payara {
    Write-Host "`nStarting Payara..." -ForegroundColor Green

    asadmin start-domain --domaindir C:\payara\domains domain1
}
Function Stop-Payara {
    asadmin stop-domain --domaindir c:\payara\domains
}

Function Start-LocalDB {
    Write-Host "`nChecking Local-DB..." -ForegroundColor DarkYellow
    $container_name = "docker-orchestration_bisapps-db_1"
    $check = wsl docker container inspect -f '{{.State.Status}}' $container_name
    if ( $check -eq "running" ) {
        Write-Host "$container_name already started!" -ForegroundColor Green
    } else {
        Write-Host "$container_name not started. Starting in background..." -ForegroundColor DarkYellow
        Start-Job -Name $container_name -ScriptBlock {fba-compose up bisapps-db}
        Write-Host "`n$container_name started.`n" -ForegroundColor Green
    }

}

Function Stop-LocalDB {
    Write-Host "Checking and stopping Local-DB..." -ForegroundColor DarkYellow
    $container_name = "docker-orchestration_bisapps-db_1"
    $check = wsl docker container inspect -f '{{.State.Status}}' $container_name

    if ( $check -eq "running" ) {
        #Stop docker within WSL, then stop the job from powershell.
        wsl docker container stop $container_name
        stop-job $container_name; remove-job $container_name
    }
}

Function Remove-Payara-WARs {
    # Undeploys all user WARs from Payara by filtering the output of `asadmin list-applications`
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
    Write-Host "`nDeploying User WAR files to Payara..." -ForegroundColor Green 
    asadmin deploy C:\Programming\Users\users\users-frontend-war\target\*.war;
    asadmin deploy C:\Programming\Users\users\users-services-war\target\*.war;
}

Function compileUsers {
    Write-Host "Compiling Users project..." -ForegroundColor Green 
    mvn clean install -f C:\Programming\Users\users
}

Function deployWars {
    Start-LocalDB
    #if (-not(Test-Path -Path $env:M2_HOME\conf\STFC_UsersCompileDeploy_RunFlag -PathType Leaf)) {
    #    Write-Host "A Mirror blocking Maven's access to HTTP servers must be removed." -ForegroundColor DarkYellow
    #    Write-Host "Please press Enter now, then type in your 03 account details. This only has to be done once." -ForegroundColor DarkYellow
    #    pause
    #    $UACProcess = Start-Process powershell -ArgumentList {-command "&{. C:\Users\hyn87611\Documents\WindowsPowerShell\STFC_UsersCompileDeploy.ps1; Grant-NonSecure-Maven-Mirrors}" -PassThru -Wait} -verb RunAs
    #    #$UACProcess.GetType().GetField('exitCode', 'NonPublic, Instance').GetValue($UACProcess)
    #    Write-Host "Done." -ForegroundColor Green
    #}
    & compileUsers
    & Start-Payara
    & Remove-Payara-WARs
    & Install-Payara-WARs
}