<#
.SYNOPSIS

.DESCRIPTION

#>

param(
    [Parameter(mandatory = $true)]
    [string]$TenantName,

    [Parameter(mandatory = $true)]
    [string]$NewHostPoolName,

    [Parameter(mandatory = $true)]
    [string]$WVDTenantAdminUN,

    [Parameter(mandatory = $true)]
    [securestring]$WVDTenantAdminPW,

    [Parameter(mandatory = $false)]
    [switch]$isServicePrincipal,

    [Parameter(Mandatory = $false)]
    [string]$AadTenantId
)

function Write-Log { 
    [CmdletBinding()] 
    param ( 
        [Parameter(Mandatory = $false)] 
        [string]$Message,
        [Parameter(Mandatory = $false)] 
        [string]$Error 
    ) 
     
    try { 
        $DateTime = Get-Date -Format 'MM-dd-yy HH:mm:ss'
        $Invocation = "$($MyInvocation.MyCommand.Source):$($MyInvocation.ScriptLineNumber)" 
        if ($Message) {
            Add-Content -Value "$DateTime - $Invocation - $Message" -Path "$WVDMigrateLogPath\ScriptLog.log" 
        }
        else {
            Add-Content -Value "$DateTime - $Invocation - $Error" -Path "$WVDMigrateLogPath\ScriptLog.log" 
        }
    } 
    catch { 
        Write-Error $_.Exception.Message 
    } 
}

function Install-AzModule {
    Install-PackageProvider NuGet -Force
    Set-PSRepository PSGallery -InstallationPolicy Trusted
    try {
        Install-Module -Name Az -AllowClobber -Scope CurrentUser
        Write-Log -Message "Installed Az PowerShell modules successfully"
    }
    catch {
        Write-Log -Message "Unable to install Az PowerShell modules successfully"
    }    
}

function Load-Module ($m) {

    # If module is imported say that and do nothing
    if (Get-Module | Where-Object { $_.Name -eq $m }) {
        Write-Log "Module $m is already imported."
    }
    else {
        # If module is not imported, but available on disk then import
        if (Get-Module -ListAvailable | Where-Object { $_.Name -eq $m }) {
            Import-Module $m -Verbose
        }
        else {

            # If module is not imported, not available on disk, but is in online gallery then install and import
            if (Find-Module -Name $m | Where-Object { $_.Name -eq $m }) {
                Install-Module -Name $m -Force -Verbose -Scope CurrentUser
                Import-Module $m -Verbose
            }
            else {

                # If module is not imported, not available and not in online gallery then abort
                write-host "Module $m not imported, not available and not in online gallery, exiting."
                EXIT 1
            }
        }
    }
}

# Get Start Time
$startDTM = (Get-Date)
Write-Log -Message "Starting WVD Migration on Host"

#Collect VM Info
$hostVMname = $env:computername
$hostVMdomain = $env:USERDNSDOMAIN

#Check for Prerequsites

$WVDMigrateBasePath = "c:\WVDMigrate\"
$WVDMigrateLogPath = "c:\WVDMigrate\logs"
$WVDMigrateInfraPath = "C:\WVDMigrate\Infra"
$infraURI = "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv"

#Creating Directory Structure and Downloading Assets
try {
    New-Item -Path $WVDMigrateLogPath -ItemType Directory -Force
    New-Item -Path $WVDMigrateInfraPath -ItemType Directory -Force
    Write-Log -Message "Created Directory Structure for Assets and Logging"
}
catch {
    Write-Log -Message "Unable to Create Directory Structure for Assets and Logging"
}


#Download Current Version of WVD Agent 
$AssetstartDTM = (Get-Date)
Invoke-WebRequest -Uri $infraURI -OutFile "$WVDMigrateInfraPath\Microsoft.RDInfra.RDAgent.Installer-x64.msi"
Write-Log -Message "Downloaded RDInfra Agent"
$AssetendDTM = (Get-Date)
Write-Log -Message "Asset Download Time: $(($AssetendDTM-$AssetstartDTM).totalseconds) seconds"

#Remove Installed versions of WVD Agent 
Write-Log -Message "Uninstalling any previous versions of RDInfra Agent on VM"
$legacy_agent_uninstall_status = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x {5389488F-551D-4965-9383-E91F27A9F217}", "/quiet", "/qn", "/norestart", "/passive", "/l* $WVDDeployLogPath\AgentUninstall.txt" -Wait -Passthru
$sts = $legacy_agent_uninstall_status.ExitCode
#Remove previous versions of RDInfraAgent DLLs
Write-Log -Message "Uninstalling any previous versions of RDInfra Agent DLL on VM"
$agent_uninstall_status = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x {CB1B8450-4A67-4628-93D3-907DE29BF78C}", "/quiet", "/qn", "/norestart", "/passive", "/l* $WVDDeployLogPath\AgentUninstall.txt" -Wait -Passthru
$sts = $agent_uninstall_status.ExitCode

#install New WVD Agent
$AgentInstaller = (dir $WVDMigrateInfraPath\ -Filter *.msi | Select-Object).FullName
Write-Log -Message "Starting install of $AgentInstaller"
$agent_deploy_status = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $AgentInstaller", "/quiet", "/qn", "/norestart", "/passive", "REGISTRATIONTOKEN=$RegistrationToken", "/l* $WVDDeployLogPath\AgentInstall.txt" -Wait -Passthru
$sts = $agent_deploy_status.ExitCode
Write-Log -Message "Installing RD Infra Agent on VM Complete. Exit code=$sts"

