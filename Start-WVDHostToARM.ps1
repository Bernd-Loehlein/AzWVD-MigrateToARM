<#
.SYNOPSIS

.DESCRIPTION

#>

param(
    [Parameter(mandatory = $true)]
    [string]$TenantName,

    [Parameter(mandatory = $true)]
    [string]$WVDHostPoolName,

    [Parameter(mandatory = $true)]
    [string]$WVDHostPoolRGName,

    [Parameter(mandatory = $true)]
    [string]$HostVMRG,

    [Parameter(mandatory = $false)]
    [string]$HostVMName,

    [Parameter(mandatory = $false)]
    [switch]$PreStageOnly,

    [Parameter(mandatory = $false)]
    [switch]$UpdateOnly
)

$LoadScriptPath = ".\VMScripts\Load-WVDAgents.ps1"
$UpdateScriptPath = ".\VMScripts\Update-WVDAgents.ps1"

function Run-PSonVM {
    param (
        [Parameter(Mandatory = $true)] 
        [string]$HVMName,
        [Parameter(Mandatory = $false)] 
        [string]$HRGName,
        [Parameter(Mandatory = $true)] 
        [string]$ScriptPath
    )
    Invoke-AzVMRunCommand -ResourceGroupName $HRGName -VMName $HVMName -CommandId 'RunPowerShellScript' -ScriptPath 'sample.ps1' -Parameter @{param1 = "var1"; param2 = "var2" }
}

#Get VMs that are to be updated 
if (($HostVMName.Length -eq 0)) {
    $HVM = Get-AzVM -ResourceGroupName $HostVMRG
    Write-Host "The following VMs will be updated"
    foreach ($H in $HVM) {
        $H.Name
    }
}
elseif (($HostVMName.Length -ne 0)) {
    $HVM = Get-AzVM -ResourceGroupName $HostVMRG -Name $HostVMName
    Write-Host "The VM" $HVM.Name "will be updated"
}

#Get the Host Pool Access Token 
<#
$HPRegInfo = $null
Write-Host "Collecting WVD Registration Info for Host Pool" $WVDHostPoolName 
try {
    $HPRegInfo = Get-AzWvdRegistrationInfo -ResourceGroupName $WVDHostPoolRGName -HostPoolName $WVDHostPoolName
    if (($HPRegInfo.Token.Length) -lt 5) {
        $HPRegInfo = New-AzWvdRegistrationInfo -ResourceGroupName $WVDHostPoolRGName -HostPoolName $WVDHostPoolName -ExpirationTime $((get-date).ToUniversalTime().AddDays(1).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))
        Write-Host "Created new WVD Host Pool Access Token" 
    }
    else {
        Write-Host "Exported WVD Host Pool Access Token"    
    }
}
catch {
    $HPRegInfo = New-AzWvdRegistrationInfo -ResourceGroupName $WVDHostPoolRGName -HostPoolName $WVDHostPoolName -ExpirationTime $((get-date).ToUniversalTime().AddDays(1).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))
    Write-Host "Created new WVD Host Pool Access Token"
}

if ($PreStageOnly) {
    foreach ($H in $HVM) {
        Write-Host "Downloading Current WVD Agent to" + $H.Name + "agent will not be installed" 
        Invoke-AzVMRunCommand -ResourceGroupName $H.ResourceGroupName -VMName $H.Name-CommandId 'RunPowerShellScript' -ScriptPath $LoadScriptPath
    }
}
elseif ($UpdateOnly) {
    foreach ($H in $HVM) {
        Write-Host "Updating WVD Host" + $H.Name + "to host pool" + $WVDHostPoolName 
        Invoke-AzVMRunCommand -ResourceGroupName $H.ResourceGroupName -VMName $H.Name-CommandId 'RunPowerShellScript' -ScriptPath $UpdateScriptPath -Parameter @{HostPoolToken = $HPRegInfo.Token}
    }
}
else {
    foreach ($H in $HVM) {
        Write-Host "Downloading Current WVD Agent to" + $H.Name 
        Invoke-AzVMRunCommand -ResourceGroupName $H.ResourceGroupName -VMName $H.Name-CommandId 'RunPowerShellScript' -ScriptPath $LoadScriptPath
    }
    foreach ($H in $HVM) {
        Write-Host "Updating WVD Host" + $H.Name + "to host pool" + $WVDHostPoolName 
        Invoke-AzVMRunCommand -ResourceGroupName $H.ResourceGroupName -VMName $H.Name-CommandId 'RunPowerShellScript' -ScriptPath $UpdateScriptPath -Parameter @{HostPoolToken = $HPRegInfo.Token}
    }
}
