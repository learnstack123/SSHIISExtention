# Ensure the script stops on any error
$ErrorActionPreference = "Stop"

# Function to write logs with timestamp
function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message"
}

Write-Log "Starting Azure subscription cleanup..."

# Ensure we have the latest Az PowerShell modules
Write-Log "Checking Az PowerShell modules..."
Import-Module Az

# Get all resource groups in the subscription
$resourceGroups = Get-AzResourceGroup
Write-Log "Found $($resourceGroups.Count) resource groups"

foreach ($rg in $resourceGroups) {
    Write-Log "Processing resource group: $($rg.ResourceGroupName)"
    
    # Get all resources in the resource group
    $resources = Get-AzResource -ResourceGroupName $rg.ResourceGroupName

    # 1. Delete Web Apps and Functions first
    $webApps = $resources | Where-Object { $_.ResourceType -in @("Microsoft.Web/sites") }
    foreach ($web in $webApps) {
        Write-Log "Deleting Web App: $($web.Name)"
        Remove-AzResource -ResourceId $web.ResourceId -Force
    }

    # 2. Delete Virtual Machines and their dependencies
    $vms = $resources | Where-Object { $_.ResourceType -eq "Microsoft.Compute/virtualMachines" }
    foreach ($vm in $vms) {
        Write-Log "Deleting VM: $($vm.Name)"
        
        # Get the VM status including the power state
        $vmStatus = (Get-AzVM -ResourceGroupName $rg.ResourceGroupName -Name $vm.Name -Status).Statuses | Where-Object { $_.Code -eq "PowerState/running" }

        if ($vmStatus) {
            # If the VM is running, stop it first before removing extensions
            Write-Log "VM $($vm.Name) is running. Stopping the VM..."
            Stop-AzVM -ResourceGroupName $rg.ResourceGroupName -Name $vm.Name -Force

            # Now, remove extensions after stopping the VM
            $extensions = Get-AzVMExtension -ResourceGroupName $rg.ResourceGroupName -VMName $vm.Name
            foreach ($ext in $extensions) {
                Write-Log "Deleting VM Extension: $($ext.Name)"
                Remove-AzVMExtension -ResourceGroupName $rg.ResourceGroupName -VMName $vm.Name -Name $ext.Name -Force
            }
        } else {
            Write-Log "VM $($vm.Name) is not running. Skipping VM extension removal."
        }
        
        # Now delete the VM
        Write-Log "Deleting VM: $($vm.Name)"
        Remove-AzVM -ResourceGroupName $rg.ResourceGroupName -Name $vm.Name -Force
    }

    # 3. Delete Load Balancer backend pools first
    $lbs = $resources | Where-Object { $_.ResourceType -eq "Microsoft.Network/loadBalancers" }
    foreach ($lb in $lbs) {
        Write-Log "Processing Load Balancer: $($lb.Name)"
        $loadBalancer = Get-AzLoadBalancer -ResourceGroupName $rg.ResourceGroupName -Name $lb.Name
        
        # Remove backend pool associations
        foreach ($backendPool in $loadBalancer.BackendAddressPools) {
            $backendPool.BackendIpConfigurations = $null
            Set-AzLoadBalancer -LoadBalancer $loadBalancer | Out-Null
        }
        
        # Delete the load balancer
        Write-Log "Deleting Load Balancer: $($lb.Name)"
        Remove-AzLoadBalancer -ResourceGroupName $rg.ResourceGroupName -Name $lb.Name -Force
    }

    # 4. Delete Application Gateways
    $appGateways = $resources | Where-Object { $_.ResourceType -eq "Microsoft.Network/applicationGateways" }
    foreach ($appGw in $appGateways) {
        Write-Log "Deleting Application Gateway: $($appGw.Name)"
        Remove-AzApplicationGateway -ResourceGroupName $rg.ResourceGroupName -Name $appGw.Name -Force
    }

    # 5. Delete Disks
    $disks = $resources | Where-Object { $_.ResourceType -eq "Microsoft.Compute/disks" }
    foreach ($disk in $disks) {
        Write-Log "Deleting Disk: $($disk.Name)"
        Remove-AzDisk -ResourceGroupName $rg.ResourceGroupName -DiskName $disk.Name -Force
    }

    # 6. Delete Network Interfaces
    $nics = $resources | Where-Object { $_.ResourceType -eq "Microsoft.Network/networkInterfaces" }
    foreach ($nic in $nics) {
        Write-Log "Deleting NIC: $($nic.Name)"
        Remove-AzNetworkInterface -ResourceGroupName $rg.ResourceGroupName -Name $nic.Name -Force
    }

    # 7. Delete Public IPs
    $pips = $resources | Where-Object { $_.ResourceType -eq "Microsoft.Network/publicIPAddresses" }
    foreach ($pip in $pips) {
        Write-Log "Deleting Public IP: $($pip.Name)"
        Remove-AzPublicIpAddress -ResourceGroupName $rg.ResourceGroupName -Name $pip.Name -Force
    }

    # 8. Delete NSGs
    $nsgs = $resources | Where-Object { $_.ResourceType -eq "Microsoft.Network/networkSecurityGroups" }
    foreach ($nsg in $nsgs) {
        Write-Log "Deleting NSG: $($nsg.Name)"
        Remove-AzNetworkSecurityGroup -ResourceGroupName $rg.ResourceGroupName -Name $nsg.Name -Force
    }

    # 9. Delete Virtual Networks
    $vnets = $resources | Where-Object { $_.ResourceType -eq "Microsoft.Network/virtualNetworks" }
    foreach ($vnet in $vnets) {
        Write-Log "Deleting VNet: $($vnet.Name)"
        Remove-AzVirtualNetwork -ResourceGroupName $rg.ResourceGroupName -Name $vnet.Name -Force
    }

    # 10. Delete Storage Accounts
    $storageAccounts = $resources | Where-Object { $_.ResourceType -eq "Microsoft.Storage/storageAccounts" }
    foreach ($sa in $storageAccounts) {
        Write-Log "Deleting Storage Account: $($sa.Name)"
        Remove-AzStorageAccount -ResourceGroupName $rg.ResourceGroupName -Name $sa.Name -Force
    }

    # 11. Delete Key Vaults
    $keyVaults = $resources | Where-Object { $_.ResourceType -eq "Microsoft.KeyVault/vaults" }
    foreach ($kv in $keyVaults) {
        Write-Log "Deleting Key Vault: $($kv.Name)"
        Remove-AzKeyVault -ResourceGroupName $rg.ResourceGroupName -VaultName $kv.Name -Force
    }

    # 12. Delete any remaining resources
    $remainingResources = Get-AzResource -ResourceGroupName $rg.ResourceGroupName
    foreach ($resource in $remainingResources) {
        Write-Log "Deleting remaining resource: $($resource.Name) of type $($resource.ResourceType)"
        Remove-AzResource -ResourceId $resource.ResourceId -Force
    }

    # Finally, delete the resource group itself
    Write-Log "Deleting Resource Group: $($rg.ResourceGroupName)"
    Remove-AzResourceGroup -Name $rg.ResourceGroupName -Force
}

Write-Log "Cleanup completed. All resources have been deleted."
