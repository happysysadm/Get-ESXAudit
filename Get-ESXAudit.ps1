Function Get-ESXAudit

{

<#
.Synopsis
The Get-ESXAudit retrieves complete information about the configuration, licensing and load of one or more VMWARE ESX servers.
.EXAMPLE
Get-ESXAudit -vCenter vcenter.myserverfarm.com -ESX '*'
.EXAMPLE
Get-ESXAudit -vCenter vcenter.myserverfarm.com -ESX 'esx1.myserverfarm.com','esx2.myserverfarm.com'
.EXAMPLE
$auditinfo = Get-ESXAudit -vCenter vcenter.myserverfarm.com -ESX 'esx1.myserverfarm.com','esx2.myserverfarm.com'
$auditinfo | select -skip 1 | ft * -auto
.EXAMPLE
'vcenter1.myserverfarm.com','vcenter2.myserverfarm.com' | Get-ESXAudit -ESX 'esx1.myserverfarm.com','esx2.myserverfarm.com'
.EXAMPLE
Get-ESXAudit -vCenter vcenter.myserverfarm.com -ESX '*' | Select-Object -Skip 1  | ConvertTo-Csv -NoTypeInformation | Out-File "audit-vmware.csv" -Force
.NOTES
happysysadm.com
@sysadm2010
#>


param(
    [parameter(mandatory=$true,valuefrompipeline=$true)]
    [string[]]$vCenter,

    [string[]]$ESX = '*'
    )
        
    Write-Verbose "Adding snapin"
    Add-PSSnapin vmware.vimautomation.core

    Write-Verbose "Cleaning up connections to vcenters"
    Disconnect-VIServer -Server $vCenter -Confirm:$false -ErrorAction SilentlyContinue

    Write-Verbose "Connecting to vcenters"
    Connect-VIServer -Server $vCenter

    Write-Verbose "Connecting to license manager"
    $ServiceInstance = Get-View ServiceInstance
    $LicenseManager = Get-View $ServiceInstance.Content.LicenseManager
    $LicenseManagerAssign = Get-View $LicenseManager.LicenseAssignmentManager

    Write-Verbose "Retrieving the hosts"
    $VMhosts=Get-VMHost $ESX

    $VMhostsTotal=@()

    Foreach($VMhost in $VMHosts)

        {
        $i++

        Write-Progress -activity "Retrieving $($VMHosts.count) ESX information" `            -status "Doing $i on $($VMHosts.count)" -PercentComplete (($i / $VMHosts.count)  * 100)

        Write-Verbose "Retrieving general hardware information on $VMhost"
        $VMHostHW = Get-VMHost -Name $VMHost.name

        Write-Verbose "Retrieving a view on the .NET object"
        $VMHostView = $VMHostHW | Get-View

        Write-Verbose "Retrieving the ID"
        $VMhostID = $VMHostView.Config.Host.Value

        Write-Verbose "Retrieving the licence information"
        $VMHostLicInfo = $LicenseManagerAssign.QueryAssignedLicenses($VMhostID)

        Write-Verbose "Creating object"
        $vmhostobject = [PSCustomObject]@{

            Name = $VMHostView.Name

            Manufacturer = $VMHostHW.Manufacturer

            Model = $VMHostHW.Model

            Product = $VMHostView.Config.Product.Name

            Version = $VMHostView.Config.Product.Version

            Sockets = $VMHostView.Hardware.CpuInfo.NumCpuPackages

            CPUCores = $VMHostView.Hardware.CpuInfo.NumCpuCores

            LicenseVersion = $VMHostLicInfo.AssignedLicense.Name | Select -Unique

            LicenseKey = $VMHostLicInfo.AssignedLicense.LicenseKey | Select -Unique

            TotalLicense = $VMHostLicInfo.AssignedLicense.Total | Select -Unique

            UsedLicense = $VMHostLicInfo.AssignedLicense.Used | Select -Unique

            CostUnit = $VMHostLicInfo.AssignedLicense.CostUnit | Select -Unique

            WindowsLicense = ($VMHostHW | Get-Annotation | where name -eq 'Windows-License').value

            Project = ($VMHostHW | Get-Annotation | where name -eq 'Project').value

            VMs = ($VMHostHW | Get-VM).count

            Memory = [math]::round(($VMHostHW.MemoryTotalMB/1KB),0)
        
            Memoryused = [math]::round(($VMHostHW.MemoryUsageMB/1KB),0)

            Percentusedmem = [int]((100/$VMHostHW.MemoryTotalMB ) * $VMHostHW.MemoryUsageMB)

            CpuTotalMhz = $VMHostHW.CpuTotalMhz
                                    
            CpuUsageMhz = $VMHostHW.CpuUsageMhz
                                    
            Percentusedcpu = [int]((100/$VMHostHW.CpuTotalMhz)*$VMHostHW.CpuUsageMhz)

            Parent = $VMHostHW.Parent

            Serial = ($VMHostView.Hardware.SystemInfo.OtherIdentifyingInfo | where {$_.IdentifierType.Key -eq “ServiceTag”}).IdentifierValue

            EVCMode = ((($VMHostHW).parent | Get-View).summary).CurrentEVCModeKey

            MaxEVCMode = ($VMHostView | select -ExpandProperty summary).maxevcmodekey

            Cluster = $VMHostHW.parent.name

            CPU = $VMHostHW.ProcessorType
        
            }

            Write-Verbose "Object created"

            $VMhostsTotal += $vmhostobject

        }

    Write-Verbose "Cleaning up connections to vcenters"
    Disconnect-VIServer -Server $vCenter -Confirm:$False -Force

    write-verbose "Returning all the objects"
    return $VMhostsTotal

} # End Function