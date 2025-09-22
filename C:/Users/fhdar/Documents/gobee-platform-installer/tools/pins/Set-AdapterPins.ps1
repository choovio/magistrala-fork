# Copyright (c) CHOOVIO Inc.
# SPDX-License-Identifier: Apache-2.0
# Purpose: Pin http-adapter and ws-adapter images to ECR digests in installer manifests and emit an orange RESULTS block.

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$HttpImage,     # e.g. 595443389404.dkr.ecr.us-west-2.amazonaws.com/http-adapter@sha256:abcdef...
  [Parameter(Mandatory=$true)]
  [string]$WsImage,       # e.g. 595443389404.dkr.ecr.us-west-2.amazonaws.com/ws-adapter@sha256:123456...
  [string]$Root = (Get-Location).Path
)

# --- Guardrails --------------------------------------------------------------
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) {
  Write-Host "ERROR: PowerShell 7+ required. Launch pwsh and rerun." -ForegroundColor Red
  exit 1
}

function Require-Digest {
  param([string]$Image,[string]$Name)
  if ($Image -notmatch "@sha256:[0-9a-fA-F]{16,}") {
    throw "$Name must include @sha256:digest"
  }
  if ($Image -notmatch "595443389404\.dkr\.ecr\.us-west-2\.amazonaws\.com") {
    throw "$Name must be an ECR image in account 595443389404 (us-west-2)."
  }
}

Require-Digest -Image $HttpImage -Name "HttpImage"
Require-Digest -Image $WsImage  -Name "WsImage"

# --- Git repo checks ---------------------------------------------------------
function Get-GitMeta {
  try {
    $top = git rev-parse --show-toplevel 2>$null
    if (-not $top) { throw "not a git repo" }
    $repo   = Split-Path -Leaf $top
    $branch = git rev-parse --abbrev-ref HEAD
    return [pscustomobject]@{ Top=$top; Repo=$repo; Branch=$branch }
  } catch {
    throw "Run this inside gobee-platform-installer (git repo)."
  }
}

$git = Get-GitMeta
if ($git.Repo -ne "gobee-platform-installer") {
  throw "This script must be run in gobee-platform-installer. Current repo: $($git.Repo)"
}

# Ensure clean working tree
$changes = git status --porcelain
if ($changes) {
  throw "Working tree not clean. Commit/stash first, then rerun."
}

# --- Locate candidate manifests ----------------------------------------------
Set-Location -LiteralPath $git.Top
$yamlFiles = Get-ChildItem -Recurse -Include *.yml,*.yaml -File

# Choose files that clearly belong to adapters (by content match)
function Select-FilesFor {
  param([string]$Token)
  return $yamlFiles | Where-Object {
    try { Select-String -Path $_.FullName -Pattern $Token -SimpleMatch -Quiet } catch { $false }
  }
}

$httpFiles = Select-FilesFor -Token "http-adapter"
$wsFiles   = Select-FilesFor -Token "ws-adapter"

if (-not $httpFiles -or -not $wsFiles) {
  throw "Could not find both adapter manifests (http=$($httpFiles.Count), ws=$($wsFiles.Count))."
}

# --- Safe replace of image: lines --------------------------------------------
# Strategy: In each selected file, update the first container image line under that adapter occurrence.
# Textual regex (YAML parsing avoided by policy—no external modules).
$backup = @()
$httpTouched = 0
$wsTouched   = 0

function Update-ImageLines {
  param([System.IO.FileInfo[]]$Files,[string]$NewImage,[string]$Label)
  $count = 0
  foreach ($f in $Files) {
    $content = Get-Content -Raw -LiteralPath $f.FullName
    $orig = $content

    # narrow to vicinity of adapter token to avoid accidental hits
    $blocks = ($content -split "(?ms)^---\s*$") # handle multi-doc files too
    for ($i=0; $i -lt $blocks.Count; $i++) {
      if ($blocks[$i] -match [regex]::Escape($Label)) {
        # Replace first 'image:' occurrence in this block
        $replaced = $false
        $blocks[$i] = [regex]::Replace($blocks[$i],
          "(?m)^(?<indent>\s*)image\s*:\s*\S+",
          { param($m) $replaced = $true; "$($m.Groups['indent'].Value)image: $NewImage" },
          1 # count = 1
        )
        if ($replaced) { $count++ }
      }
    }
    $newContent = ($blocks -join "`n---`n")
    if ($newContent -ne $orig) {
      $bak = "$($f.FullName).bak"
      Copy-Item -LiteralPath $f.FullName -Destination $bak -Force
      Set-Content -LiteralPath $f.FullName -Value $newContent -NoNewline
      $backup += $bak
    }
  }
  return $count
}

$httpTouched = Update-ImageLines -Files $httpFiles -NewImage $HttpImage -Label "http-adapter"
$wsTouched   = Update-ImageLines -Files $wsFiles   -NewImage $WsImage   -Label "ws-adapter"

if ($httpTouched -eq 0 -and $wsTouched -eq 0) {
  throw "No image lines were updated. Check manifests and try again."
}

# --- Commit changes -----------------------------------------------------------
git add --all
$shortHttp = ($HttpImage -replace '^.*@sha256:','') .Substring(0,12)
$shortWs   = ($WsImage   -replace '^.*@sha256:','') .Substring(0,12)

$commitMsg = @"
chore(installer): pin adapters to ECR digests

- http-adapter: $HttpImage
- ws-adapter:   $WsImage

Backups: *.bak adjacent to edited files.
"@
git commit -m $commitMsg | Out-Null

# --- Emit orange RESULTS ------------------------------------------------------
$esc = [char]27; $orange="${esc}[38;5;214m"; $reset="${esc}[0m"
$ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")

Write-Host $orange
Write-Host "RESULTS"
Write-Host "Repo: $($git.Repo)"
Write-Host "Branch: $($git.Branch)"
Write-Host "Action: PinAdapters"
Write-Host "FilesUpdated: http=$httpTouched ws=$wsTouched"
Write-Host "HttpDigest12: $shortHttp"
Write-Host "WsDigest12: $shortWs"
Write-Host "Next: git push origin $($git.Branch) ; then deploy and verify /health"
Write-Host "TIMESTAMP: $ts"
Write-Host $reset
