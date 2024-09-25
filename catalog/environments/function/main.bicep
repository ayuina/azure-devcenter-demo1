param prefix string
param region string

var logAnalyticsName = '${prefix}-laws'
var appInsightsName = '${prefix}-ai'
var funcStrName = '${prefix}funcstr'
var dataStrName = '${prefix}datastr'
var funcAppName = '${prefix}-func'
var funcPlanName = '${prefix}-func-plan'
var funcFilesName = '${funcAppName}-files'

var queueTriggerQueueEnvName = 'queue-trigger-queue'
var queueTriggerQueueName = 'queue01'

var blobTriggerContainerEnvName = 'blob-trigger-container'
var blobTriggerContainerName = 'blobs01'

var loggingContainerEnvName = 'function-logging-container'
var loggingContainerName = 'logging'

var diagRetention = {
  days: 0
  enabled: false
}

resource funcStr 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: funcStrName
  location: region
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }

  resource fileSvc 'fileServices' existing = {
    name: 'default'

    resource funcFilesShare 'shares' = {
      name: funcFilesName
    }
  }
}

resource dataStr 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: dataStrName
  location: region
  kind: 'StorageV2'
  sku:{
    name: 'Standard_LRS'
  }

  resource queueSvc 'queueServices' = {
    name: 'default'

    resource queueTriggerQueue 'queues' = {
      name: queueTriggerQueueName
    }
  }

  resource blobSvc 'blobServices' = {
    name: 'default'

    resource blobTriggerContainer 'containers' = {
      name: blobTriggerContainerName
    }

    resource loggingContainer 'containers' = {
      name: loggingContainerName
    }
  }
}


resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: region
  properties:{
    sku:{
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: -1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource appinsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: region
  kind: 'web'
  properties:{
    Application_Type: 'web'
    Request_Source: 'IbizaWebAppExtensionCreate'
    WorkspaceResourceId: logAnalytics.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource funcPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: funcPlanName
  location: region
  kind: 'elastic'
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
    family: 'EP'
  }
  properties: {
    maximumElasticWorkerCount: 1
  }
}

resource funcApp 'Microsoft.Web/sites@2022-03-01' = {
  name: funcAppName
  location: region
  kind: 'functionapp'
  properties:{
    serverFarmId: funcPlan.id
    clientAffinityEnabled: false
    siteConfig:{
      appSettings:[
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appinsights.properties.ConnectionString
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${funcStrName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${funcStr.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${funcStrName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${funcStr.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: funcFilesName
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name: 'AzureWebJobsDataStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${dataStrName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${dataStr.listKeys().keys[0].value}'
        }
        {
          name : queueTriggerQueueEnvName
          value : queueTriggerQueueName
        }
        {
          name: blobTriggerContainerEnvName
          value: blobTriggerContainerName
        }
        {
          name : loggingContainerEnvName
          value : loggingContainerName
        }
      ]
    }
  }
}

resource funcdiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${funcAppName}-diag'
  scope: funcApp
  properties: {
    storageAccountId: funcStr.id
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'FunctionAppLogs'
        enabled: true
        retentionPolicy: diagRetention
      }
    ]
    metrics: [
      {
        timeGrain: null
        enabled: true
        retentionPolicy: diagRetention
      }
    ]
  }
}
