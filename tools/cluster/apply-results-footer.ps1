# Copyright (c) CHOOVIO Inc.
# SPDX-License-Identifier: Apache-2.0

Set-StrictMode -Version Latest

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter(Mandatory)]
    [hashtable]$Fields
)

$ErrorActionPreference = 'Stop'

$modulePath = Join-Path -Path $PSScriptRoot -ChildPath 'results-template.ps1'
$module = Import-Module -Name $modulePath -Force -PassThru

try {
    $existingContent = ''
    if (Test-Path -Path $Path) {
        $existingContent = Get-Content -Path $Path -Raw -ErrorAction SilentlyContinue
        if ($null -eq $existingContent) {
            $existingContent = ''
        }
    }
    else {
        $parent = Split-Path -Path $Path -Parent
        if ($parent -and -not (Test-Path -Path $parent)) {
            New-Item -Path $parent -ItemType Directory -Force | Out-Null
        }
        New-Item -Path $Path -ItemType File -Force | Out-Null
    }

    $esc = [char]27
    $headerPattern = [regex]::Escape("$esc[38;5;208m==== RESULTS ====$esc[0m")
    $footerPattern = [regex]::Escape("$esc[38;5;208m==== END RESULTS ====$esc[0m")
    $resultsRegex = "(?s)$headerPattern.*?$footerPattern"

    if ($existingContent -match $resultsRegex) {
        Write-Verbose "RESULTS footer already present in '$Path'; skipping append."
        return
    }

    $infoRecords = & { Emit-Results -Fields $Fields } 6>&1

    $lines = @()
    foreach ($record in $infoRecords) {
        if ($record -is [System.Management.Automation.InformationRecord]) {
            $lines += [string]$record.MessageData
        }
        elseif ($record) {
            $lines += [string]$record
        }
    }

    if (-not $lines -or $lines.Count -eq 0) {
        return
    }

    foreach ($line in $lines) {
        Write-Host $line
    }

    $newline = [Environment]::NewLine
    $blockText = [string]::Join($newline, $lines) + $newline

    if ($existingContent.Length -gt 0 -and -not $existingContent.EndsWith("`n") -and -not $existingContent.EndsWith("`r`n")) {
        $blockText = $newline + $blockText
    }

    [System.IO.File]::AppendAllText($Path, $blockText, [System.Text.Encoding]::UTF8)
}
finally {
    if ($module) {
        Remove-Module -ModuleInfo $module -Force
    }
}
