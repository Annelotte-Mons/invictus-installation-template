[CmdletBinding()]
param (
    [parameter(Mandatory)]
    [string]
    $OrganizationUrl,

    [Parameter(Mandatory)]
    [string]
    $RESOURCE_GROUP,

    [Parameter(Mandatory)]
    [string]
    $Company,

    [Parameter(Mandatory)]
    [string]
    $Environment,

    [Parameter(Mandatory)]
    [string]
    $PAT,

    [Parameter(Mandatory)]
    [string]
    $SubscriptionId,

    [Parameter(Mandatory)]
    [string]
    $vnetResourceGroup,

    [Parameter(Mandatory)]
    [string]
    $vnetName,

    [Parameter(Mandatory)]
    [string]
    $subnetName,

    [Parameter(Mandatory)]
    [string]
    $location
)

try {
    #az provider register --namespace Microsoft.App
    #az provider register --namespace Microsoft.OperationalInsights

    $PoolName="$($Environment)-aca-agent"
    $ACAENVIRONMENT="$(Company)-$($Environment)-azure-pipeline-agents"
    $PLACEHOLDER_JOB_NAME="placeholder-agent-job"
    $JOB_NAME="azure-pipelines-agent-job"
    $CONTAINER_IMAGE_NAME="azure-pipelines-agent:latest"
    $CONTAINER_REGISTRY_NAME="$(Company)$($Environment)acr"
    $LOG_WORKSPACE="$(Company)-mon-$($Environment)"

    $SUBNET_RESOURCEID = "/subscriptions/$($SubscriptionId)/resourceGroups/$($vnetResourceGroup)/providers/Microsoft.Network/virtualNetworks/$($vnetName)/subnets/$($subnetName)"
    

    # Ensure resource group
    #az group create --name "$RESOURCE_GROUP" --location "$location"

    Write-Host "Preparing to create Azure Container App environment for Azure DevOps agents"
    Write-Host "Subnet Resource ID: $SUBNET_RESOURCEID"

    # Create loganalytics workspace
    $workspace = az monitor log-analytics workspace create  `
    --resource-group "$RESOURCE_GROUP" `
    --workspace-name "$LOG_WORKSPACE"  `
    | ConvertFrom-Json

    $LogAnalyticsSharedKey = az monitor log-analytics workspace get-shared-keys --resource-group "$RESOURCE_GROUP" --workspace-name "$LOG_WORKSPACE" | ConvertFrom-Json

    # Create Container App environment
    az containerapp env create `
        --name "$ACAENVIRONMENT" `
        --resource-group "$RESOURCE_GROUP" `
        --location "$location" `
        --enable-workload-profiles `
        --infrastructure-subnet-resource-id "$SUBNET_RESOURCEID" `
        --logs-destination "log-analytics" `
        --logs-workspace-id $workspace.customerId `
        --logs-workspace-key $LogAnalyticsSharedKey.primarySharedKey `


    # Create Container Registry
    az acr create --name "$CONTAINER_REGISTRY_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION" --sku Basic --admin-enabled true

    # Build Agent image
    az acr build --registry "$CONTAINER_REGISTRY_NAME" --image "$CONTAINER_IMAGE_NAME" --file "$PSScriptRoot/files/Dockerfile.AcaAgent" "$PSScriptRoot/files"

    # Create placeholder agent once
    az containerapp job create -n "$PLACEHOLDER_JOB_NAME" -g "$RESOURCE_GROUP" --environment "$ACAENVIRONMENT" `
    --trigger-type Manual `
    --replica-timeout 300 `
    --replica-retry-limit 1 `
    --replica-completion-count 1 `
    --parallelism 1 `
    --image "$CONTAINER_REGISTRY_NAME.azurecr.io/$CONTAINER_IMAGE_NAME" `
    --cpu "2.0" `
    --memory "4Gi" `
    --secrets "personal-access-token=$PAT" "organization-url=$OrganizationUrl" `
    --env-vars "AZP_TOKEN=secretref:personal-access-token" "AZP_URL=secretref:organization-url" "AZP_POOL=$PoolName" "AZP_PLACEHOLDER=1" "AZP_AGENT_NAME=placeholder-agent" `
    --registry-server "$CONTAINER_REGISTRY_NAME.azurecr.io" `
    --workload-profile-name "Consumption"

    az containerapp job start -n "$PLACEHOLDER_JOB_NAME" -g "$RESOURCE_GROUP" --only-show-errors

    # Wait for execution to to be finnished
    $executions = az containerapp job execution list -n "$PLACEHOLDER_JOB_NAME" -g "$RESOURCE_GROUP" --only-show-errors | ConvertFrom-Json | Sort-Object {$_.properties.startTime}

    while ($executions[0].properties.status -eq "Running") {
        Start-Sleep -Seconds 5
        $executions = az containerapp job execution list -n "$PLACEHOLDER_JOB_NAME" -g "$RESOURCE_GROUP" --only-show-errors | ConvertFrom-Json | Sort-Object {$_.properties.startTime}
    }
	Write-Host "placeholder job executed $executions[0].name with status $executions[0].properties.status"

    # az containerapp job delete -n "$PLACEHOLDER_JOB_NAME" -g "$RESOURCE_GROUP" --yes --only-show-errors

    # Create Container App job
    az containerapp job create -n "$JOB_NAME" -g "$RESOURCE_GROUP" --environment "$ACAENVIRONMENT" `
    --trigger-type Event `
    --replica-timeout 1800 `
    --replica-retry-limit 0 `
    --replica-completion-count 1 `
    --parallelism 1 `
    --image "$CONTAINER_REGISTRY_NAME.azurecr.io/$CONTAINER_IMAGE_NAME" `
    --min-executions 0 `
    --max-executions 10 `
    --polling-interval 30 `
    --scale-rule-name "azure-pipelines" `
    --scale-rule-type "azure-pipelines" `
    --scale-rule-metadata "poolName=$PoolName" "targetPipelinesQueueLength=1" `
    --scale-rule-auth "personalAccessToken=personal-access-token" "organizationURL=organization-url" `
    --cpu "2.0" `
    --memory "4Gi" `
    --secrets "personal-access-token=$PAT" "organization-url=$OrganizationUrl" `
    --env-vars "AZP_TOKEN=secretref:personal-access-token" "AZP_URL=secretref:organization-url" "AZP_POOL=$PoolName" `
    --registry-server "$CONTAINER_REGISTRY_NAME.azurecr.io" `
    --workload-profile-name "Consumption"
}
catch {
    Write-Error -Message "$($_)"
}
