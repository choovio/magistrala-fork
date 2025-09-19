# Copyright (c) CHOOVIO Inc.
# SPDX-License-Identifier: Apache-2.0

Set-StrictMode -Version Latest

function Emit-Results {
    param([Parameter(Mandatory)][hashtable]$Data)
    $esc    = [char]27
    $allowed = @('KubeContext','Namespace','Deployments','Services','Ingresses','Pods','Health checks','Samples')

    $header = "$esc[38;5;208m==== RESULTS ====$esc[0m"
    $footer = "$esc[38;5;208m==== END RESULTS ====$esc[0m"

    Write-Host $header
    foreach ($k in $allowed) {
        if ($Data.ContainsKey($k) -and $null -ne $Data[$k] -and "$($Data[$k])".Trim()) {
            $v = $Data[$k]
            if ($v -is [System.Collections.IEnumerable] -and -not ($v -is [string])) {
                $v = ($v | ForEach-Object { "$_" }) -join ', '
            }
            Write-Host "$k: $v"
        }
    }
    Write-Host $footer
}
