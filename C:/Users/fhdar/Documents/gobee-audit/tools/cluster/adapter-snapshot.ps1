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

function Get-DeploymentImage {
  param(
    [string]$DeploymentName,
    [string]$Namespace
  )

  try {
    $json = kubectl get deployment $DeploymentName -n $Namespace -o json | ConvertFrom-Json
  } catch {
    throw "Unable to query deployment '$DeploymentName' in namespace '$Namespace'. $_"
  }

  if (-not $json.spec.template.spec.containers) {
    return $null
  }

  ($json.spec.template.spec.containers | Select-Object -First 1).image
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

    $image = Get-DeploymentImage -DeploymentName $definition.Name -Namespace $Namespace
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

return $snapshots
