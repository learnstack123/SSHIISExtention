# Import the Active Directory module
Import-Module ActiveDirectory

# Define the path to the CSV file
$csvPath = "C:\Users\Administrator\Desktop\newcsv.csv"

# Import the CSV file
$users = Import-Csv -Path $csvPath

# Loop through each user in the CSV file and create them in Active Directory
foreach ($user in $users) {
    # Extract values from the CSV file
    $displayName = $user.DisplayName
    $userPrincipalName = $user.UserPrincipalName
    $password = $user.Password
    $firstName = $user.FirstName
    $lastName = $user.LastName
    $enabled = if ($user.Enabled -eq 'Yes') { $true } else { $false }

    # Check if any required fields are missing
    if (-not $displayName -or -not $userPrincipalName -or -not $password) {
        Write-Host "Missing required field for user: $displayName"
        continue
    }

    # Create the user in Active Directory
    try {
        New-ADUser `
            -SamAccountName ($userPrincipalName.Split('@')[0]) `
            -UserPrincipalName $userPrincipalName `
            -GivenName $firstName `
            -Surname $lastName `
            -DisplayName $displayName `
            -Name $displayName `
            -AccountPassword (ConvertTo-SecureString -AsPlainText $password -Force) `
            -Enabled $enabled `
            -PassThru

        Write-Host "Created user: $displayName"
    } catch {
        Write-Host "Failed to create user: $displayName. Error: $_"
    }
}
