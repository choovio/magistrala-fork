# Copyright (c) CHOOVIO Inc.
# SPDX-License-Identifier: Apache-2.0

# AWS Account constant (baked for audit)
$AWS_ACCOUNT_ID = "595443389404"

[CmdletBinding()]
param(
  [string]$Namespace = "magistrala",
  [string[]]$Adapters = @("http-adapter", "ws-adapter")
)

# --- Require PS7 ---
if ($PSVersionTable.PSVersion.Major -lt 7) {
  Write-Host "ERROR: PowerShell 7+ required. Launch pwsh and rerun." -ForegroundColor Red
  exit 1
}

$ErrorActionPreference = 'Stop'

function Get-GitMeta {
  try {
    $top = git rev-parse --show-toplevel 2>$null
    $repo = Split-Path -Leaf $top
    $branch = git rev-parse --abbrev-ref HEAD
    [pscustomobject]@{ Top=$top; Repo=$repo; Branch=$branch }
  } catch {
    [pscustomobject]@{ Top=""; Repo="(unknown)"; Branch="(unknown)" }
  }
}

function Get-KubeMeta {
  param([string]$Ns)
  $ctx = ""
  try { $ctx = (kubectl config current-context).Trim() } catch { $ctx = "(unknown)" }
  $nsExists = $false
  try { $nsExists = (kubectl get ns $Ns --no-headers 2>$null) -ne $null } catch { }
  [pscustomobject]@{ Context=$ctx; NamespaceExists=$nsExists }
}

function Invoke-KubectlJson {
  param([string[]]$Args)
  $filtered = @()
  foreach ($arg in $Args) {
    if ($null -ne $arg -and $arg.ToString().Length -gt 0) {
      $filtered += $arg
    }
  }
  $filtered += '-o'
  $filtered += 'json'
  try {
    $raw = kubectl @filtered 2>$null
    if (-not $raw) { return $null }
    return $raw | ConvertFrom-Json
  } catch {
    return $null
  }
}

function Get-SelectorString {
  param($Selector)
  if (-not $Selector) { return "" }
  $labels = $Selector.matchLabels
  if (-not $labels) { return "" }
  $pairs = @()
  foreach ($prop in $labels.PSObject.Properties) {
    if ($null -ne $prop.Value -and $prop.Value.ToString().Length -gt 0) {
      $pairs += "$($prop.Name)=$($prop.Value)"
    }
  }
  return ($pairs -join ',')
}

function Get-PodSummaries {
  param(
    [string]$Namespace,
    [string]$Selector
  )
  $args = @('get', 'pods', '-n', $Namespace)
  if ($Selector) {
    $args += @('-l', $Selector)
  }
  $json = Invoke-KubectlJson -Args $args
  if (-not $json) { return @() }
  $items = @()
  if ($json.items) {
    $items = @($json.items)
  } else {
    $items = @($json)
  }

  $rows = @()
  foreach ($item in $items) {
    if (-not $item.metadata) { continue }
    $podName = [string]$item.metadata.name
    $phase   = [string]$item.status.phase

    $ready = $true
    $reasons = New-Object System.Collections.Generic.List[string]

    if ($item.status -and $item.status.containerStatuses) {
      foreach ($cs in $item.status.containerStatuses) {
        if (-not $cs.ready) {
          $ready = $false
          if ($cs.state.waiting) {
            if ($cs.state.waiting.reason) {
              $reasons.Add([string]$cs.state.waiting.reason)
            }
            if ($cs.state.waiting.message) {
              $reasons.Add([string]$cs.state.waiting.message)
            }
          } elseif ($cs.state.terminated) {
            if ($cs.state.terminated.reason) {
              $reasons.Add([string]$cs.state.terminated.reason)
            }
            if ($cs.state.terminated.message) {
              $reasons.Add([string]$cs.state.terminated.message)
            }
          } else {
            $reasons.Add('NotReady')
          }
        }
      }
    }

    if ($item.status -and $item.status.conditions) {
      foreach ($condition in $item.status.conditions) {
        if ($condition.type -eq 'Ready' -and $condition.status -ne 'True' -and $condition.reason) {
          $reasons.Add([string]$condition.reason)
        }
      }
    }

    $rows += [pscustomobject]@{
      Name    = $podName
      Phase   = $phase
      Ready   = $ready
      Reasons = $reasons.ToArray() | Sort-Object -Unique
    }
  }
  return $rows
}

function Get-AdapterSnapshot {
  param(
    [string]$Namespace,
    [string]$Adapter
  )
  $deploy = Invoke-KubectlJson -Args @('get', 'deployment', $Adapter, '-n', $Namespace)
  if (-not $deploy) {
    return [pscustomobject]@{
      Name              = $Adapter
      Exists            = $false
      Images            = @()
      TagViolations     = @()
      AccountViolations = @()
      Pods              = @()
      Pending           = @()
    }
  }

  $containers = @()
  if ($deploy.spec -and $deploy.spec.template -and $deploy.spec.template.spec -and $deploy.spec.template.spec.containers) {
    $containers = @($deploy.spec.template.spec.containers)
  }

  $images = @()
  $tagViolations = New-Object System.Collections.Generic.List[string]
  $accountViolations = New-Object System.Collections.Generic.List[string]

  foreach ($container in $containers) {
    if (-not $container.image) { continue }
    $image = [string]$container.image
    $images += $image
    if ($image -notmatch '@sha256:') {
      $tagViolations.Add($image)
    }
    if ($image -notmatch "^$AWS_ACCOUNT_ID\.dkr\.ecr\.") {
      $accountViolations.Add($image)
    }
  }

  $selector = Get-SelectorString -Selector $deploy.spec.selector
  $pods = Get-PodSummaries -Namespace $Namespace -Selector $selector
  $pending = @()
  foreach ($pod in $pods) {
    if ($pod.Phase -ne 'Running' -or -not $pod.Ready) {
      $pending += $pod
    }
  }

  [pscustomobject]@{
    Name              = $Adapter
    Exists            = $true
    Images            = $images
    TagViolations     = $tagViolations.ToArray()
    AccountViolations = $accountViolations.ToArray()
    Pods              = $pods
    Pending           = $pending
  }
}

function Get-IngressPaths {
  param([string]$Namespace)
  $json = Invoke-KubectlJson -Args @('get', 'ingress', '-n', $Namespace)
  if (-not $json) { return @() }
  $items = @()
  if ($json.items) {
    $items = @($json.items)
  } else {
    $items = @($json)
  }

  $paths = @()
  foreach ($ing in $items) {
    if (-not $ing.spec -or -not $ing.spec.rules) { continue }
    foreach ($rule in @($ing.spec.rules)) {
      if (-not $rule.http -or -not $rule.http.paths) { continue }
      foreach ($path in @($rule.http.paths)) {
        if ($path.path) {
          $paths += [string]$path.path
        }
      }
    }
  }
  return $paths
}

# --- Main ---
$git  = Get-GitMeta
$kube = Get-KubeMeta -Ns $Namespace
if (-not $kube.NamespaceExists) {
  Write-Host "ERROR: Namespace '$Namespace' does not exist in current context." -ForegroundColor Red
  exit 2
}

$adapterSnapshots = @()
foreach ($adapter in $Adapters) {
  $adapterSnapshots += Get-AdapterSnapshot -Namespace $Namespace -Adapter $adapter
}

$ingressPaths = Get-IngressPaths -Namespace $Namespace
$allowedIngress = @('/api/http', '/api/ws')
$forbiddenIngress = @()
foreach ($path in $ingressPaths) {
  if ($path -match '^/api/(http|ws)-adapter$') {
    $forbiddenIngress += $path
  }
}
$extraIngress = $ingressPaths | Where-Object { $_ -notin $allowedIngress }
$extraIngress = $extraIngress | Sort-Object -Unique

$missingAdapters = ($adapterSnapshots | Where-Object { -not $_.Exists }).Name
$checkedAdapters = ($adapterSnapshots | Where-Object { $_.Exists }).Name

$tagViolations = @($adapterSnapshots | ForEach-Object { $_.TagViolations } | Where-Object { $_ })
$tagViolations = $tagViolations | Sort-Object -Unique

$accountViolations = @($adapterSnapshots | ForEach-Object { $_.AccountViolations } | Where-Object { $_ })
$accountViolations = $accountViolations | Sort-Object -Unique

$pendingPods = @($adapterSnapshots | ForEach-Object { $_.Pending } | Where-Object { $_ })

$pendingSummary = if ($pendingPods.Count -gt 0) {
  ($pendingPods | ForEach-Object {
      $reason = if ($_.Reasons -and $_.Reasons.Count -gt 0) { ($_.Reasons -join '|') } else { $_.Phase }
      "$($_.Name)[$reason]"
    }) -join ', '
} else {
  'none'
}

$esc = [char]27; $orange="${esc}[38;5;214m"; $reset="${esc}[0m"
$ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")

$checkedList = if ($checkedAdapters) { ($checkedAdapters -join ', ') } else { 'none' }
$missingList = if ($missingAdapters) { ($missingAdapters -join ', ') } else { 'none' }
$tagList = if ($tagViolations) { ($tagViolations -join ', ') } else { 'none' }
$accountList = if ($accountViolations) { ($accountViolations -join ', ') } else { 'none' }
$forbiddenList = if ($forbiddenIngress) { ($forbiddenIngress -join ', ') } else { 'none' }
$allIngressList = if ($ingressPaths) { ($ingressPaths -join ', ') } else { 'none' }
$extraIngressList = if ($extraIngress) { ($extraIngress -join ', ') } else { 'none' }

Write-Host $orange
Write-Host "RESULTS"
Write-Host "Repo: $($git.Repo)"
Write-Host "Branch: $($git.Branch)"
Write-Host "ClusterContext: $($kube.Context)"
Write-Host "Namespace: $Namespace"
Write-Host "AuditAccountId: $AWS_ACCOUNT_ID"
Write-Host "AdaptersChecked: $checkedList"
Write-Host "MissingAdapters: $missingList"
Write-Host "TagBasedImages: $tagList"
Write-Host "AccountMismatchedImages: $accountList"
Write-Host "PendingPods: $pendingSummary"
Write-Host "IngressPaths: $allIngressList"
Write-Host "ForbiddenIngressPaths: $forbiddenList"
Write-Host "ExtraIngressPaths: $extraIngressList"
Write-Host "TIMESTAMP: $ts"
Write-Host $reset
