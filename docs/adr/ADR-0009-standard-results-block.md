# ADR-0009 — Standard RESULTS Block

## Decision
All verification and audit scripts must emit a standardized RESULTS block at the end of execution.

## Format

```
==== RESULTS ====
<Action + key/value pairs>
TIMESTAMP: yyyy-MM-dd HH:mm:ss zzz
==== END RESULTS ====
```

- **Header/footer:** Always `==== RESULTS ==== / ==== END RESULTS ====`.
- **Color:** Entire block must be printed in ANSI orange (`ESC[38;5;214m`) and reset to default at the end (`ESC[0m`).
- **Single block:** Emit once; do not print each line separately with `Write-Host`.

## PowerShell Implementation
```powershell
# Require PS7
$PSStyle.OutputRendering = 'Ansi'
[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8

$esc    = [char]27
$orange = "$esc[38;5;214m"
$reset  = "$esc[0m"

$results = @"
==== RESULTS ====
Action: <YourAction>
Key: Value
TIMESTAMP: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')
==== END RESULTS ====
"@

Write-Host ($orange + $results + $reset)
```

## Rationale

This ensures:

- Consistent format across all repos.
- Machine-parseable block for scripts.
- Human-readable orange highlight in PS7/ANSI-capable terminals.
