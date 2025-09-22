# Copyright (c) CHOOVIO Inc.
# SPDX-License-Identifier: Apache-2.0

# AWS Account constant (baked for audit)
$AWS_ACCOUNT_ID = "595443389404"

[CmdletBinding()]
param(
  [string]$Namespace = "magistrala",
  [string]$EcrRegion = "us-west-2",
  [switch]$WriteCsv,
  [string]$CsvPath = ".\\audit-images.csv"
)

$ErrorActionPreference = 'Stop'

$clusterScript = Join-Path -Path $PSScriptRoot -ChildPath 'cluster/audit-images.ps1'
if (-not (Test-Path -Path $clusterScript)) {
  throw "Cluster audit script not found at '$clusterScript'."
}

$invokeArgs = @{
  Namespace  = $Namespace
  EcrAccount = $AWS_ACCOUNT_ID
  EcrRegion  = $EcrRegion
  CsvPath    = $CsvPath
}

if ($WriteCsv) {
  $invokeArgs["WriteCsv"] = $true
}

& $clusterScript @invokeArgs
