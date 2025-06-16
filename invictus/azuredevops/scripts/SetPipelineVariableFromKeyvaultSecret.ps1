param(
    [Parameter(Mandatory = $true)]
    [string]$keyvaultName,

    [Parameter(Mandatory = $true)]
    [string]$secretName,

    [Parameter(Mandatory = $true)]
    [string]$pipelineVariableName
)

# Get the secret value from Azure Key Vault
$secret = az keyvault secret show --vault-name $keyvaultName --name $secretName --query value -o tsv

if (-not $secret) {
    Write-Error "Failed to retrieve secret '$secretName' from Key Vault '$keyvaultName'."
    exit 1
}

# Set the Azure DevOps pipeline variable
Write-Host "##vso[task.setvariable variable=$pipelineVariableName;issecret=true]$secret"