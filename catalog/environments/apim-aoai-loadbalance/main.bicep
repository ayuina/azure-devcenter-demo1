param apimRegion string
param aoaiRegion1 string
param aoaiRegion2 string
param modelSku string
param modelName string
param modelVersion string
param modelCapacity int

var postfix = toLower(uniqueString(subscription().id, apimRegion, resourceGroup().name))
var logAnalyticsName = 'laws-${postfix}'
var appInsightsName = 'ai-${postfix}'
var apimName = 'apim-${postfix}'
var apimPublisher = 'contoso'
var apimPublisherEmail = 'contoso@example.com'
var aoaiSpec = loadTextContent('./aoai-spec.json')
var aoaiPolicy = loadTextContent('./aoai-policy.xml')
var aoaiRegions = [aoaiRegion1, aoaiRegion2]

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: apimRegion
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
  location: apimRegion
  kind: 'web'
  properties:{
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource apiman 'Microsoft.ApiManagement/service@2023-03-01-preview' = {
  name: apimName
  location: apimRegion
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

module backendAoais 'aoai.bicep' = [for (region, index) in aoaiRegions: {
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
}]

resource apimBackends 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = [for (region, index) in aoaiRegions: {
  dependsOn: [ backendAoais[index] ]
  parent: apiman
  name: 'backend-aoai-${region}'
  properties: {
    title: 'backend-aoai-${region}'
    type: 'Single'
    protocol: 'http'
    url: 'https://aoai-${postfix}-${region}.openai.azure.com/openai'
  }
}]

resource apimBackendPool 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' =  {
  dependsOn: apimBackends
  parent: apiman
  name: 'backend-aoai-pool'
  properties: {
    title: 'backend-aoai-pool'
    type: 'Pool'
    pool: {
      services: [for (region, index) in aoaiRegions: {
        id: resourceId('Microsoft.ApiManagement/service/backends', apiman.name, 'backend-aoai-${region}')
      }]
    }
  }
}

resource aoaiApi 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = {
  parent: apiman
  dependsOn: [apimBackendPool]
  name: 'openai'
  properties: {
    path: 'openai'
    subscriptionRequired: true
    protocols: [
      'https'
    ]
    type:'http'
    format: 'openapi'
    serviceUrl: json(aoaiSpec).servers[0].url
    subscriptionKeyParameterNames: {
      header: 'api-key'
    }
    value: aoaiSpec
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
