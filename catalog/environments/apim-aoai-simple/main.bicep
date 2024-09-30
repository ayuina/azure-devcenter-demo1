param region string
param modelSku string = 'Standard'
param modelName string = 'gpt-4o'
param modelVersion string = '2024-05-13'
param modelCapacity int = 10

var postfix = toLower(uniqueString(subscription().id, region, resourceGroup().name))
var logAnalyticsName = 'laws-${postfix}'
var appInsightsName = 'ai-${postfix}'
var apimName = 'apim-${postfix}'
var apimPublisher = 'contoso'
var apimPublisherEmail = 'contoso@example.com'
var aoaiSpecUrl = 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/refs/heads/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/preview/2024-08-01-preview/inference.json'
var aoaiPolicy = loadTextContent('./aoai-policy.xml')

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
    WorkspaceResourceId: logAnalytics.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource apiman 'Microsoft.ApiManagement/service@2023-09-01-preview' = {
  name: apimName
  location: region
  sku: {
    name: 'Consumption'
    capacity: 0
  }
  properties: {
    publisherName: apimPublisher
    publisherEmail: apimPublisherEmail
  }
  identity: { type: 'SystemAssigned' }

  resource ailogger 'loggers' = {
    name: '${appInsightsName}-logger'
    properties: {
      loggerType: 'applicationInsights'
      resourceId: appinsights.id
      credentials: {
        instrumentationKey: appinsights.properties.InstrumentationKey
      }
    }
  }
}

resource apimDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${apiman.name}-diag'
  scope: apiman
  properties: {
    workspaceId: logAnalytics.id
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        category: 'GatewayLogs'
        enabled: true
      }
      {
        category: 'WebSocketConnectionLogs'
        enabled: true
      }
    ]
    metrics: [
      {
         category: 'AllMetrics'
         enabled: true
      }
    ]
  }
}

module aoai 'aoai.bicep' = {
  name: 'aoai-${postfix}-${region}'
  scope: resourceGroup()
  params: {
    postfix: postfix
    region: region
    deployName: modelName
    modelName: modelName
    modelSku: modelSku
    modelVersion: modelVersion
    modelCapacity: modelCapacity
    logAnalyticsName: logAnalytics.name
    apimName: apiman.name
  }
}

resource backend 'Microsoft.ApiManagement/service/backends@2023-09-01-preview' = {
  parent: apiman
  name: 'aoai-backend'
  properties: {
    title: 'aoai-backend'
    type: 'Single'
    protocol: 'http'
    url: 'https://aoai-${postfix}-${region}.openai.azure.com/openai'
  }
}

resource aoaiApi 'Microsoft.ApiManagement/service/apis@2023-09-01-preview' = {
  parent: apiman
  name: 'openai'
  properties: {
    path: 'openai'
    format: 'openapi+json-link'
    value: aoaiSpecUrl
    subscriptionRequired: true
    type:'http'
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'api-key'
    }
  }

  resource policy 'policies' = {
    name: 'policy'
    properties: {
      format: 'rawxml'
      value: aoaiPolicy
    }
  }

  resource aidiag 'diagnostics' = {
    name: 'applicationinsights'
    properties: {
      loggerId: apiman::ailogger.id
      alwaysLog: 'allErrors'
      sampling: {
        samplingType: 'fixed'
        percentage: 100
      }
      logClientIp: true
      metrics: true
      verbosity: 'information'
    }
  }
}
