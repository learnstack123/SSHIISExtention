# Log in to Azure
Connect-AzAccount

# Get all the resource groups in the subscription
$resourceGroups = Get-AzResourceGroup

# Loop through each resource group
foreach ($resourceGroup in $resourceGroups) {
    Write-Host "Checking resource group: $($resourceGroup.ResourceGroupName)"

    # Get all virtual machines in the resource group
    $vms = Get-AzVM -ResourceGroupName $resourceGroup.ResourceGroupName

    # Loop through each VM in the resource group
    foreach ($vm in $vms) {
        Write-Host "Checking VM: $($vm.Name)"

        # Get the VM's current power state
        $vmStatus = (Get-AzVM -ResourceGroupName $resourceGroup.ResourceGroupName -Name $vm.Name -Status).Statuses[1].Code

        # Check if the VM is in 'VM running' state
        if ($vmStatus -eq "PowerState/running") {
            Write-Host "Stopping VM: $($vm.Name) in resource group $($resourceGroup.ResourceGroupName)"

            # Stop the VM (without deallocating, change to -Deallocate if you want to deallocate)
            Stop-AzVM -ResourceGroupName $resourceGroup.ResourceGroupName -Name $vm.Name -Force

            Write-Host "VM $($vm.Name) stopped successfully."
        }
        else {
            Write-Host "VM $($vm.Name) is in state $vmStatus. Skipping."
        }
    }
}
