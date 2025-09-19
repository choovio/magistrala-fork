# Copyright (c) CHOOVIO Inc.
# SPDX-License-Identifier: Apache-2.0
Set-StrictMode -Version Latest

function Emit-Results {
    param([Parameter(Mandatory)][hashtable]$Data)
    $esc    = [char]27
    $orange = "$esc[38;5;208m"
    $reset  = "$esc[0m"
    $allowed = @('KubeContext','Namespace','Deployments','Services','Ingresses','Pods','Health checks','Samples')

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('==== RESULTS ====')
    foreach ($k in $allowed) {
        if ($Data.ContainsKey($k) -and $null -ne $Data[$k] -and "$($Data[$k])".Trim()) {
            $v = $Data[$k]
            if ($v -is [System.Collections.IEnumerable] -and -not ($v -is [string])) {
                $v = ($v | ForEach-Object { "$_" }) -join ', '
            }
            $lines.Add("$k: $v")
        }
    }
    $lines.Add('==== END RESULTS ====')
    Write-Host ($orange + ($lines -join [Environment]::NewLine) + $reset)
}
