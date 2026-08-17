param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$ErrorActionPreference = 'Stop'
$resolved = (Resolve-Path -LiteralPath $Path).Path
$lines = Get-Content -LiteralPath $resolved -Encoding UTF8
$errors = [System.Collections.Generic.List[string]]::new()
$tables = [System.Collections.Generic.List[object]]::new()

function Get-MarkdownCells([string]$Row) {
    $value = $Row.Trim()
    if ($value.StartsWith('|')) { $value = $value.Substring(1) }
    if ($value.EndsWith('|')) { $value = $value.Substring(0, $value.Length - 1) }
    return @($value -split '(?<!\\)\|' | ForEach-Object { $_.Trim() })
}

$index = 0
while ($index -lt $lines.Count) {
    if ($lines[$index] -notmatch '^\|') {
        $index++
        continue
    }

    $start = $index
    $rows = [System.Collections.Generic.List[string]]::new()
    while ($index -lt $lines.Count -and $lines[$index] -match '^\|') {
        $rows.Add($lines[$index])
        $index++
    }

    $heading = ''
    for ($h = $start - 1; $h -ge 0; $h--) {
        if ($lines[$h] -match '^##\s+') {
            $heading = $lines[$h]
            break
        }
    }

    $columnCounts = @($rows | ForEach-Object { (($_ -split '(?<!\\)\|').Count - 2) })
    $expected = $columnCounts[0]
    for ($r = 0; $r -lt $columnCounts.Count; $r++) {
        if ($columnCounts[$r] -ne $expected) {
            $errors.Add("Table [$heading] row $($r + 1) has $($columnCounts[$r]) columns; expected $expected.")
        }
    }

    if ($rows.Count -lt 3) {
        $errors.Add("Table [$heading] has no data rows.")
    }
    if ($rows.Count -ge 2 -and $rows[1] -notmatch '^\|\s*:?-{3,}') {
        $errors.Add("Table [$heading] has an invalid Markdown separator row.")
    }

    $dataRows = [Math]::Max(0, $rows.Count - 2)
    if ($heading -match '(\d+)') {
        $declared = [int]$Matches[1]
        if ($declared -ne $dataRows) {
            $errors.Add("Table [$heading] declares $declared rows; found $dataRows.")
        }
    }

    for ($r = 2; $r -lt $rows.Count; $r++) {
        if ($rows[$r] -notmatch '\[[^\]]+\]\(https?://[^)]+\)') {
            $errors.Add("Table [$heading] data row $($r - 1) has no HTTP(S) source link.")
        }
    }

    $headerCells = Get-MarkdownCells $rows[0]
    $scoreIndex = -1
    for ($cellIndex = 0; $cellIndex -lt $headerCells.Count; $cellIndex++) {
        if ($headerCells[$cellIndex] -in @('评分', '素材评分')) {
            $scoreIndex = $cellIndex
            break
        }
    }
    if ($scoreIndex -lt 0) {
        $errors.Add("Table [$heading] has no score column.")
    } else {
        for ($r = 2; $r -lt $rows.Count; $r++) {
            $cells = Get-MarkdownCells $rows[$r]
            $score = $cells[$scoreIndex]
            if ($score -notmatch '^\d{1,3}$' -or [int]$score -lt 55 -or [int]$score -gt 100) {
                $errors.Add("Table [$heading] data row $($r - 1) has invalid user-facing score [$score]; expected integer 55-100.")
            }
        }
    }

    $tables.Add([PSCustomObject]@{
        Heading = $heading
        Columns = $expected
        DataRows = $dataRows
    })
}

if ($tables.Count -ne 2) {
    $errors.Add("Delivery must contain exactly 2 tables; found $($tables.Count).")
}
if ($lines -match '^##\s*[SABC]') {
    $errors.Add('Delivery still contains S/A/B/C section headings.')
}
if ($lines -match '待核|待确认|待补') {
    $errors.Add('Delivery contains unfinished verification wording.')
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "Validation passed: $resolved"
$tables | Format-Table Heading, Columns, DataRows -AutoSize
