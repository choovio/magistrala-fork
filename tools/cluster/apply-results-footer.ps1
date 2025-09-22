[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/results-template.ps1"

function Get-StandardResultsBlock {
    $builder = [System.Text.StringBuilder]::new()
    $existingFunction = Get-Item Function:\Write-Host -ErrorAction SilentlyContinue
    $restoreScriptBlock = if ($existingFunction) { $existingFunction.ScriptBlock } else { $null }

    $script:__resultsBuilder = $builder
    $capture = {
        param(
            [Parameter(ValueFromRemainingArguments = $true)]
            [object[]]$Object,
            [switch]$NoNewline,
            [System.ConsoleColor]$ForegroundColor,
            [System.ConsoleColor]$BackgroundColor,
            [string]$Separator
        )

        $segments = if ($null -ne $Object) { $Object } else { @() }
        if ($PSBoundParameters.ContainsKey('Separator')) {
            $text = ($segments | ForEach-Object { if ($_ -eq $null) { '' } else { $_.ToString() } }) -join $Separator
        }
        else {
            $text = ($segments | ForEach-Object { if ($_ -eq $null) { '' } else { $_.ToString() } }) -join ' '
        }

        $script:__resultsBuilder.Append($text) | Out-Null
        if (-not $NoNewline) {
            $script:__resultsBuilder.Append([Environment]::NewLine) | Out-Null
        }
    }

    Set-Item -Path Function:\Write-Host -Value $capture
    try {
        Emit-Results @{}
    }
    finally {
        if ($restoreScriptBlock) {
            Set-Item -Path Function:\Write-Host -Value $restoreScriptBlock
        }
        else {
            Remove-Item Function:\Write-Host -ErrorAction SilentlyContinue
        }
        Remove-Variable -Name __resultsBuilder -Scope Script -ErrorAction SilentlyContinue
    }

    return $builder.ToString().TrimEnd("`r", "`n")
}

$resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction Stop | Select-Object -ExpandProperty ProviderPath
$content = Get-Content -LiteralPath $resolvedPath -Raw

$block = Get-StandardResultsBlock

$esc = [char]27
$colorStarts = @(
    "$esc[38;5;208m",
    '\e[38;5;208m',
    '`e[38;5;208m'
)
$colorResets = @(
    "$esc[0m",
    '\e[0m',
    '`e[0m'
)

$hasBlock = $false
foreach ($start in $colorStarts) {
    foreach ($finish in $colorResets) {
        $pattern = [System.Text.RegularExpressions.Regex]::Escape($start) + '==== RESULTS ====.*?==== END RESULTS ====' + [System.Text.RegularExpressions.Regex]::Escape($finish)
        if ([System.Text.RegularExpressions.Regex]::IsMatch($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
            $hasBlock = $true
            break
        }
    }
    if ($hasBlock) {
        break
    }
}

if (-not $hasBlock) {
    $builder = [System.Text.StringBuilder]::new()
    $newLine = [Environment]::NewLine
    if ($content.Length -gt 0 -and -not $content.EndsWith($newLine)) {
        $builder.Append($newLine) | Out-Null
    }
    $builder.Append($block) | Out-Null
    $builder.Append($newLine) | Out-Null
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::AppendAllText($resolvedPath, $builder.ToString(), $encoding)
}
