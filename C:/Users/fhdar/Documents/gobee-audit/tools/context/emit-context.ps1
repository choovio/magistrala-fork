# Copyright (c) CHOOVIO Inc.
# SPDX-License-Identifier: Apache-2.0
param(
  [string[]] $RepoRoots = @(
    "C:\Users\fhdar\Documents\magistrala-fork",
    "C:\Users\fhdar\Documents\gobee-platform-installer",
    "C:\Users\fhdar\Documents\gobee-platform-console",
    "C:\Users\fhdar\Documents\gobee-audit"
  ),
  [int] $StatusTail = 12
)

# Rules in this repo
$ruleFiles = @(
  "ADR-0006-results-format.md",
  "ADR-0007-license-header-policy.md",
  "ADR-0008-powershell-policy.md",
  "docs\PRIMER.md",
  "docs\runbooks\*.md",
  "tools\cluster\adapter-snapshot.ps1",
  "tools\cluster\audit-images.ps1",
  "STATUS.md"
)
$rules = @()
foreach($pat in $ruleFiles){ $rules += Get-ChildItem -Path $pat -ErrorAction SilentlyContinue | Select-Object -Expand FullName }

# Find SBX manifests (canonical first, then legacy)
$targets = @("ops\sbx\http.yaml","ops\sbx\ws.yaml","ops\sbx\http-adapter.yaml","ops\sbx\ws-adapter.yaml")
$hits = @()
foreach($root in $RepoRoots){
  foreach($t in $targets){
    $p = Join-Path $root $t
    if(Test-Path $p){ $hits += [pscustomobject]@{ repo=(Split-Path $root -Leaf); path=$p; file=(Split-Path $p -Leaf) } }
  }
}
$canonical = $hits | Where-Object { $_.file -in @('http.yaml','ws.yaml') }
if(-not $canonical){ $canonical = $hits | Where-Object { $_.file -in @('http-adapter.yaml','ws-adapter.yaml') } }

# Emit paste-ready snapshot
$branch = (git rev-parse --abbrev-ref HEAD)
"========== CONTEXT SNAPSHOT =========="
"Repo: gobee-audit  (branch: $branch)"
"Rules:"
if($rules){ $rules | ForEach-Object { " - $_" } } else { " - (none found)" }
""
"Canonical SBX manifests (pin here):"
if($canonical){ $canonical | ForEach-Object { " - [$($_.repo)] $($_.path)" } } else { " - (none found; use legacy *-adapter.yaml if present)" }
""
"All manifest hits:"
if($hits){ $hits | ForEach-Object { " - [$($_.repo)] $($_.path)" } } else { " - (none found)" }
""
"Workflows (by convention):"
@(
  ".github/workflows/build-push-pin-adapters-sbx.yml",
  ".github/workflows/deploy-adapters-sbx.yaml",
  ".github/workflows/SBX-manifest-guard.yaml",
  ".github/workflows/sbx-manifest-guard.yaml",
  ".github/workflows/env-guard.yaml"
) | ForEach-Object { " - $_" }
""
"STATUS tail:"
if(Test-Path "STATUS.md"){ (Get-Content -Tail $StatusTail "STATUS.md") }
"========== CONTEXT SNAPSHOT =========="
