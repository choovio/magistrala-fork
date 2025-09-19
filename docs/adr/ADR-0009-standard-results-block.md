# ADR-0009: Standard RESULTS block for PowerShell scripts

## Status
Accepted

## Decision
Every diagnostic/ops PowerShell script MUST end with the exact orange block:



==== RESULTS ====
<fields>
==== END RESULTS ====


Printed in orange (`\e[38;5;208m`). Only include any of these fields when present:
`KubeContext`, `Namespace`, `Deployments`, `Services`, `Ingresses`, `Pods`, `Health checks`, `Samples`.

No extra text after the block. The canonical emitter is `tools/cluster/results-template.ps1`.

## Rationale
Consistent, parseable output; aligns with ADR-0006.
