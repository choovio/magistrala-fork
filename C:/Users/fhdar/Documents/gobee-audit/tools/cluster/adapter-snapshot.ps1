#!/usr/bin/env pwsh
# Copyright (c) CHOOVIO Inc.
# SPDX-License-Identifier: Apache-2.0
# Purpose: Capture the currently deployed adapter container images and emit
#          ECR metadata helpers that simplify verification of the running
#          workloads.

[CmdletBinding()]
param(
  [Parameter()]
  [string]$Namespace = "magistrala",

  [Parameter()]
  [string[]]$Adapters = @("http-adapter", "ws-adapter"),

  [Parameter()]
  [string]$Region = "us-west-2",

  [Parameter()]
  [string]$OutputPath,

  [switch]$Quiet
)

# AWS Account constant (baked for audit)
$AWS_ACCOUNT_ID = "595443389404"
$EcrHost = "$AWS_ACCOUNT_ID.dkr.ecr.us-west-2.amazonaws.com"
$HttpAdapterRepo = "$EcrHost/choovio/magistrala/http-adapter"
$WsAdapterRepo   = "$EcrHost/choovio/magistrala/ws-adapter"

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-EcrRegistryUri {
  param([string]$Region)
  $EcrHost
}

function Get-AdapterCatalog {
  $registryUri = Get-EcrRegistryUri -Region $Region
  [ordered]@{
    "http-adapter" = [pscustomobject]@{
      Name         = "http-adapter"
      Description  = "HTTP protocol adapter"
      Repository   = "choovio/magistrala/http-adapter"
      RegistryUri  = $registryUri
      ExpectedUri  = $HttpAdapterRepo
    }
    "ws-adapter" = [pscustomobject]@{
      Name         = "ws-adapter"
      Description  = "WebSocket protocol adapter"
      Repository   = "choovio/magistrala/ws-adapter"
      RegistryUri  = $registryUri
      ExpectedUri  = $WsAdapterRepo
    }
  }
}

function Ensure-Kubectl {
  if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    throw "kubectl CLI not found on PATH. Install kubectl before running this script."
  }
}

function Get-DeploymentDetails {
  param(
    [string]$DeploymentName,
    [string]$Namespace
  )

  try {
    $json = kubectl get deployment $DeploymentName -n $Namespace -o json | ConvertFrom-Json
  } catch {
    throw "Unable to query deployment '$DeploymentName' in namespace '$Namespace'. $_"
  }

  $image = ""
  if ($json.spec.template.spec.containers) {
    $image = ($json.spec.template.spec.containers | Select-Object -First 1).image
  }

  $status = $json.status
  $replicas = if ($status -and $null -ne $status.replicas) { [int]$status.replicas } else { 0 }
  $readyReplicas = if ($status -and $null -ne $status.readyReplicas) { [int]$status.readyReplicas } else { 0 }
  $availableReplicas = if ($status -and $null -ne $status.availableReplicas) { [int]$status.availableReplicas } else { 0 }

  [pscustomobject]@{
    Image             = $image
    Replicas          = $replicas
    ReadyReplicas     = $readyReplicas
    AvailableReplicas = $availableReplicas
  }
}

function Split-ImageReference {
  param([string]$Image)

  if (-not $Image) {
    return [pscustomobject]@{
      Image          = ""
      Registry       = ""
      RepositoryPath = ""
      Tag            = ""
      Digest         = ""
    }
  }

  $full = $Image
  $digest = ""
  $reference = $full

  if ($full -match "@") {
    $parts = $full -split "@", 2
    $reference = $parts[0]
    $digest = $parts[1]
  }

  $tag = ""
  $referencePart = $reference
  $tagSplit = $referencePart -split ':(?=[^/:]+$)'
  if ($tagSplit.Count -gt 1) {
    $referencePart = $tagSplit[0]
    $tag = $tagSplit[1]
  }

  $registry = ""
  $repositoryPath = $referencePart
  $slashSplit = $referencePart -split '/', 2
  if ($slashSplit.Count -eq 2 -and ($slashSplit[0] -like "*.*" -or $slashSplit[0] -like "*:*" -or $slashSplit[0] -eq "localhost")) {
    $registry = $slashSplit[0]
    $repositoryPath = $slashSplit[1]
  }

  [pscustomobject]@{
    Image          = $full
    Registry       = $registry
    RepositoryPath = $repositoryPath
    Tag            = $tag
    Digest         = $digest
  }
}

function Try-GetKubeResourceJson {
  param(
    [string]$Kind,
    [string]$Namespace
  )

  try {
    kubectl get $Kind -n $Namespace -o json | ConvertFrom-Json
  } catch {
    $null
  }
}

function Test-PodMatchesAdapter {
  param(
    [pscustomobject]$Pod,
    [string]$Adapter
  )

  if (-not $Pod) {
    return $false
  }

  $name = $Pod.metadata.name
  if ($name -and $name.StartsWith($Adapter, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $true
  }

  $labels = $Pod.metadata.labels
  if ($labels) {
    $labelNames = $labels.PSObject.Properties.Name
    foreach ($candidate in @('app', 'app.kubernetes.io/name', 'app.kubernetes.io/component')) {
      if ($labelNames -contains $candidate) {
        $value = $labels.$candidate
        if ($value -and $value.Equals($Adapter, [System.StringComparison]::OrdinalIgnoreCase)) {
          return $true
        }
      }
    }
  }

  if ($Pod.spec -and $Pod.spec.containers) {
    foreach ($container in $Pod.spec.containers) {
      $containerName = $container.name
      if ($containerName -and $containerName.StartsWith($Adapter, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
      }
    }
  }

  $false
}

function Get-AdapterPodMap {
  param(
    [pscustomobject]$PodsJson,
    [string[]]$Adapters
  )

  $map = @{}
  foreach ($adapter in $Adapters) {
    $map[$adapter] = @()
  }

  if ($PodsJson -and $PodsJson.items) {
    foreach ($pod in $PodsJson.items) {
      foreach ($adapter in $Adapters) {
        if (Test-PodMatchesAdapter -Pod $pod -Adapter $adapter) {
          $map[$adapter] += $pod
          break
        }
      }
    }
  }

  $map
}

function Format-LimitedList {
  param(
    [object[]]$Items,
    [int]$Limit = 3
  )

  if (-not $Items -or $Items.Count -eq 0) {
    return ""
  }

  if ($Items.Count -le $Limit) {
    return ($Items -join '; ')
  }

  $rangeEnd = $Limit - 1
  $shown = $Items[0..$rangeEnd]
  $extra = $Items.Count - $Limit
  ($shown -join '; ') + "; ... +$extra"
}

function Format-ServiceSample {
  param(
    [pscustomobject]$ServicesJson,
    [string[]]$Adapters
  )

  if (-not $ServicesJson -or -not $ServicesJson.items) {
    return ""
  }

  $entries = @()
  foreach ($svc in ($ServicesJson.items | Sort-Object { $_.metadata.name })) {
    $name = $svc.metadata.name
    if (-not $name -or ($Adapters -notcontains $name)) {
      continue
    }

    $type = if ($svc.spec -and $svc.spec.type) { $svc.spec.type } else { 'ClusterIP' }
    $portSegments = @()
    if ($svc.spec -and $svc.spec.ports) {
      foreach ($port in $svc.spec.ports) {
        $portNumber = if ($null -ne $port.port) { $port.port } else { '' }
        $target = $port.targetPort
        if ($target -is [System.Management.Automation.PSObject]) {
          if ($null -ne $target.number) {
            $target = $target.number
          } elseif ($null -ne $target.name) {
            $target = $target.name
          }
        }
        if ($null -eq $target -and $port.name) {
          $target = $port.name
        }
        $targetText = if ($null -ne $target -and "$target".Length -gt 0) { [string]$target } else { '' }
        $segment = if ($targetText) { "${portNumber}->$targetText" } else { [string]$portNumber }
        if ($port.nodePort -and $type -eq 'NodePort') {
          $segment = "$segment(node:$($port.nodePort))"
        }
        $portSegments += $segment
      }
    }

    if (-not $portSegments) {
      $portSegments = @('no-ports')
    }

    $entries += "$name $type $($portSegments -join ',')"
  }

  Format-LimitedList -Items $entries -Limit 4
}

function Format-IngressSample {
  param([pscustomobject]$IngressJson)

  if (-not $IngressJson -or -not $IngressJson.items) {
    return ""
  }

  $entries = @()
  foreach ($ing in ($IngressJson.items | Sort-Object { $_.metadata.name })) {
    $name = $ing.metadata.name
    if (-not $name) {
      continue
    }

    if ($ing.spec -and $ing.spec.rules) {
      foreach ($rule in $ing.spec.rules) {
        $host = $rule.host
        if ($rule.http -and $rule.http.paths) {
          foreach ($path in $rule.http.paths) {
            $pathValue = if ($null -ne $path.path -and "$($path.path)".Length -gt 0) { $path.path } else { '/' }
            $backend = $path.backend
            $serviceName = ''
            $servicePort = ''
            if ($backend -and $backend.service) {
              $serviceName = $backend.service.name
              if ($backend.service.port) {
                if ($null -ne $backend.service.port.number) {
                  $servicePort = $backend.service.port.number
                } elseif ($null -ne $backend.service.port.name) {
                  $servicePort = $backend.service.port.name
                }
              }
            }

            $target = $serviceName
            if ($servicePort) {
              $target = "$serviceName:$servicePort"
            }
            $source = if ($host) { "$host$pathValue" } else { $pathValue }
            $entries += "$name $source -> $target"
          }
        }
      }
    }

    if ($ing.spec -and $ing.spec.defaultBackend -and $ing.spec.defaultBackend.service) {
      $serviceName = $ing.spec.defaultBackend.service.name
      $servicePort = ''
      if ($ing.spec.defaultBackend.service.port) {
        if ($null -ne $ing.spec.defaultBackend.service.port.number) {
          $servicePort = $ing.spec.defaultBackend.service.port.number
        } elseif ($null -ne $ing.spec.defaultBackend.service.port.name) {
          $servicePort = $ing.spec.defaultBackend.service.port.name
        }
      }
      $target = $serviceName
      if ($servicePort) {
        $target = "$serviceName:$servicePort"
      }
      $entries += "$name <default> -> $target"
    }
  }

  Format-LimitedList -Items $entries -Limit 4
}

function Get-ContainerReadyCounts {
  param([pscustomobject]$Pod)

  $ready = 0
  $total = 0

  if ($Pod.status -and $Pod.status.containerStatuses) {
    foreach ($cs in $Pod.status.containerStatuses) {
      $total++
      if ($cs.ready) {
        $ready++
      }
    }
  }

  if ($total -eq 0 -and $Pod.spec -and $Pod.spec.containers) {
    $total = $Pod.spec.containers.Count
  }

  [pscustomobject]@{ Ready = $ready; Total = $total }
}

function Format-PodEntry {
  param([pscustomobject]$Pod)

  $name = $Pod.metadata.name
  $status = $Pod.status
  $phase = if ($status -and $status.phase) { $status.phase } else { '(unknown)' }
  $counts = Get-ContainerReadyCounts -Pod $Pod
  $ready = $counts.Ready
  $total = $counts.Total
  $segment = "$name $ready/$total $phase"

  $restarts = 0
  if ($status -and $status.containerStatuses) {
    foreach ($cs in $status.containerStatuses) {
      if ($null -ne $cs.restartCount) {
        $restarts += [int]$cs.restartCount
      }
    }
  }

  if ($restarts -gt 0) {
    $segment += " (restarts:$restarts)"
  }

  $segment
}

function Format-PodSample {
  param([hashtable]$AdapterPods)

  if (-not $AdapterPods) {
    return ""
  }

  $entries = @()
  foreach ($adapter in ($AdapterPods.Keys | Sort-Object)) {
    foreach ($pod in $AdapterPods[$adapter]) {
      $entries += Format-PodEntry -Pod $pod
    }
  }

  Format-LimitedList -Items $entries -Limit 4
}

function Format-ImageReference {
  param(
    [pscustomobject]$Snapshot,
    [string]$Repository
  )

  if (-not $Snapshot) {
    return "$Repository:(unknown)"
  }

  if ($Snapshot.Tag) {
    return "$Repository:$($Snapshot.Tag)"
  }

  if ($Snapshot.Digest) {
    return "$Repository@$($Snapshot.Digest)"
  }

  if ($Snapshot.Image) {
    return $Snapshot.Image
  }

  "$Repository:(unknown)"
}

function Get-PodIssueSummary {
  param(
    [pscustomobject[]]$Pods,
    [string]$Adapter
  )

  foreach ($pod in $Pods) {
    if ($pod.status -and $pod.status.containerStatuses) {
      foreach ($cs in $pod.status.containerStatuses) {
        if ($cs.state -and $cs.state.waiting -and $cs.state.waiting.reason) {
          return "$Adapter $($cs.state.waiting.reason)"
        }
        if ($cs.lastState -and $cs.lastState.terminated -and $cs.lastState.terminated.reason) {
          return "$Adapter $($cs.lastState.terminated.reason)"
        }
      }
    }
  }

  $null
}

function Determine-LikelyCause {
  param(
    [int]$HttpPending,
    [pscustomobject[]]$HttpPods,
    [bool]$WsDeploymentPresent,
    [pscustomobject[]]$WsPods
  )

  if (-not $WsDeploymentPresent) {
    return 'ws adapter deployment missing'
  }

  if ($HttpPending -gt 0) {
    return 'http adapter pods pending'
  }

  $httpIssue = Get-PodIssueSummary -Pods $HttpPods -Adapter 'http-adapter'
  if ($httpIssue) {
    return $httpIssue
  }

  $wsIssue = Get-PodIssueSummary -Pods $WsPods -Adapter 'ws-adapter'
  if ($wsIssue) {
    return $wsIssue
  }

  'n/a'
}

function Get-AdapterSnapshots {
  param(
    [pscustomobject]$Catalog,
    [string[]]$Names,
    [string]$Namespace
  )

  $results = @()
  foreach ($name in $Names) {
    $definition = $Catalog[$name]
    if (-not $definition) {
      throw "Unknown adapter '$name'. Supported adapters: $(@($Catalog.Keys) -join ', ')"
    }

    $details = Get-DeploymentDetails -DeploymentName $definition.Name -Namespace $Namespace
    $image = $details.Image
    $parsed = Split-ImageReference -Image $image
    $matches = $false
    if ($parsed.Registry) {
      $matches = $parsed.Registry.Equals($definition.RegistryUri, [System.StringComparison]::OrdinalIgnoreCase)
    } elseif ($image) {
      $matches = $image.ToLowerInvariant().StartsWith($definition.ExpectedUri.ToLowerInvariant())
    }

    $results += [pscustomobject]@{
      Adapter            = $definition.Name
      Description        = $definition.Description
      Image              = $image
      RegistryMatches    = $matches
      ExpectedEcrUri     = $definition.ExpectedUri
      Replicas           = $details.Replicas
      ReadyReplicas      = $details.ReadyReplicas
      AvailableReplicas  = $details.AvailableReplicas
      Tag                = $parsed.Tag
      Digest             = $parsed.Digest
      AwsDescribeCommand = "aws ecr describe-images --registry-id $AWS_ACCOUNT_ID --repository-name $($definition.Repository) --region $Region"
    }
  }

  $results
}

Ensure-Kubectl

$catalog = Get-AdapterCatalog
$uniqueAdapters = @()
foreach ($name in $Adapters) {
  if ($uniqueAdapters -notcontains $name) {
    $uniqueAdapters += $name
  }
}

$snapshots = Get-AdapterSnapshots -Catalog $catalog -Names $uniqueAdapters -Namespace $Namespace

if (-not $Quiet) {
  if ($snapshots.Count -eq 0) {
    Write-Host "No adapter deployments found in namespace '$Namespace'."
  } else {
    $snapshots | Format-Table Adapter, RegistryMatches, Tag, Digest, Image -AutoSize
  }
}

if ($OutputPath) {
  $snapshots | ConvertTo-Json -Depth 3 | Set-Content -Path $OutputPath -Encoding utf8
}

$KubeContext = "(unknown)"
try {
  $ctx = kubectl config current-context
  if ($ctx) {
    $KubeContext = $ctx.Trim()
  }
} catch {}

$deploymentsJson = Try-GetKubeResourceJson -Kind 'deployments' -Namespace $Namespace
$servicesJson = Try-GetKubeResourceJson -Kind 'svc' -Namespace $Namespace
$ingressJson = Try-GetKubeResourceJson -Kind 'ingress' -Namespace $Namespace
$podsJson = Try-GetKubeResourceJson -Kind 'pods' -Namespace $Namespace

$DeploymentCount = if ($deploymentsJson -and $deploymentsJson.items) { $deploymentsJson.items.Count } else { 0 }
$ServiceCount = if ($servicesJson -and $servicesJson.items) { $servicesJson.items.Count } else { 0 }
$IngressCount = if ($ingressJson -and $ingressJson.items) { $ingressJson.items.Count } else { 0 }

$adapterPodsMap = Get-AdapterPodMap -PodsJson $podsJson -Adapters $uniqueAdapters
$allAdapterPods = @()
foreach ($adapter in $adapterPodsMap.Keys) {
  $allAdapterPods += $adapterPodsMap[$adapter]
}
$AdapterPodCount = $allAdapterPods.Count

$httpPods = if ($adapterPodsMap.ContainsKey('http-adapter')) { $adapterPodsMap['http-adapter'] } else { @() }
$wsPods = if ($adapterPodsMap.ContainsKey('ws-adapter')) { $adapterPodsMap['ws-adapter'] } else { @() }

$HttpPending = ($httpPods | Where-Object { $_.status -and $_.status.phase -eq 'Pending' } | Measure-Object).Count

$httpSnapshot = $snapshots | Where-Object { $_.Adapter -eq 'http-adapter' } | Select-Object -First 1
$wsSnapshot = $snapshots | Where-Object { $_.Adapter -eq 'ws-adapter' } | Select-Object -First 1

$WsDeployPresent = $false
if ($wsSnapshot -and $wsSnapshot.Image) {
  $WsDeployPresent = $true
}

$HttpReplicas = if ($httpSnapshot) { $httpSnapshot.Replicas } else { 0 }
$HttpReady = if ($httpSnapshot) { $httpSnapshot.ReadyReplicas } else { 0 }
$WsReplicas = if ($wsSnapshot) { $wsSnapshot.Replicas } else { 0 }
$WsReady = if ($wsSnapshot) { $wsSnapshot.ReadyReplicas } else { 0 }

$HttpTag = '(unknown)'
if ($httpSnapshot) {
  if ($httpSnapshot.Tag) {
    $HttpTag = $httpSnapshot.Tag
  } elseif ($httpSnapshot.Digest) {
    $HttpTag = "@$($httpSnapshot.Digest)"
  }
}

$WsTag = '(unknown)'
if ($wsSnapshot) {
  if ($wsSnapshot.Tag) {
    $WsTag = $wsSnapshot.Tag
  } elseif ($wsSnapshot.Digest) {
    $WsTag = "@$($wsSnapshot.Digest)"
  }
}

$deploySample = "http-adapter $($HttpReady)/$($HttpReplicas) img=$HttpAdapterRepo:$HttpTag; ws-adapter $($WsReady)/$($WsReplicas) img=$WsAdapterRepo:$WsTag"

$svcSample = Format-ServiceSample -ServicesJson $servicesJson -Adapters $uniqueAdapters
if (-not $svcSample) { $svcSample = '(none)' }

$ingSample = Format-IngressSample -IngressJson $ingressJson
if (-not $ingSample) { $ingSample = '(none)' }

$podSample = Format-PodSample -AdapterPods $adapterPodsMap
if (-not $podSample) { $podSample = '(none)' }

$LikelyCause = Determine-LikelyCause -HttpPending $HttpPending -HttpPods $httpPods -WsDeploymentPresent $WsDeployPresent -WsPods $wsPods

Write-Host "==== RESULTS ===="
Write-Host "KubeContext: $KubeContext"
Write-Host "Namespace: $Namespace"
Write-Host "Deployments: $DeploymentCount"
Write-Host "Services: $ServiceCount"
Write-Host "Ingresses: $IngressCount"
Write-Host "Pods(Adapter): $AdapterPodCount"
Write-Host "HTTP_PendingCount: $HttpPending"
Write-Host "WS_DeploymentsPresent: $WsDeployPresent"
Write-Host "LikelyCause: $LikelyCause"
Write-Host "DeploySample: $deploySample"
Write-Host "SvcSample: $svcSample"
Write-Host "IngSample: $ingSample"
Write-Host "PodSample: $podSample"
Write-Host "==== END RESULTS ===="

return $snapshots
