param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$ErrorActionPreference = 'Stop'
$resolved = (Resolve-Path -LiteralPath $Path).Path
$lines = Get-Content -LiteralPath $resolved -Encoding UTF8
$errors = [System.Collections.Generic.List[string]]::new()

function Get-MarkdownCells([string]$Row) {
    $value = $Row.Trim()
    if ($value.StartsWith('|')) { $value = $value.Substring(1) }
    if ($value.EndsWith('|')) { $value = $value.Substring(0, $value.Length - 1) }
    return @($value -split '(?<!\\)\|' | ForEach-Object { $_.Trim() })
}

$tableStart = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\|' -and $lines[$i] -match '正式评分') {
        $tableStart = $i
        break
    }
}
if ($tableStart -lt 0) {
    Write-Error 'Audit ledger has no table with a 正式评分 column.'
    exit 1
}

$rows = [System.Collections.Generic.List[string]]::new()
$cursor = $tableStart
while ($cursor -lt $lines.Count -and $lines[$cursor] -match '^\|') {
    $rows.Add($lines[$cursor])
    $cursor++
}
if ($rows.Count -lt 3) {
    $errors.Add('Audit ledger table has no data rows.')
}

$header = Get-MarkdownCells $rows[0]
$scoreIndex = [Array]::IndexOf($header, '正式评分')
$reasonIndex = [Array]::IndexOf($header, '终态原因')
if ($reasonIndex -lt 0) { $reasonIndex = [Array]::IndexOf($header, '推荐理由') }
if ($scoreIndex -lt 0) { $errors.Add('Missing 正式评分 column.') }
if ($reasonIndex -lt 0) { $errors.Add('Missing 终态原因 or 推荐理由 column.') }

$expectedColumns = $header.Count
$highCount = 0
$lowCount = 0
$notScoredCount = 0

for ($r = 2; $r -lt $rows.Count; $r++) {
    $cells = Get-MarkdownCells $rows[$r]
    if ($cells.Count -ne $expectedColumns) {
        $errors.Add("Data row $($r - 1) has $($cells.Count) columns; expected $expectedColumns.")
        continue
    }
    $score = $cells[$scoreIndex]
    $reason = $cells[$reasonIndex]
    $isNotScored = $reason -match '核验硬排除|not_scored|未评分'

    if ($score -match '^\d{1,3}$') {
        $number = [int]$score
        if ($number -eq 0) {
            $errors.Add("Data row $($r - 1) uses forbidden zero-score placeholder.")
        } elseif ($number -gt 100) {
            $errors.Add("Data row $($r - 1) has score over 100.")
        } elseif ($isNotScored) {
            $errors.Add("Data row $($r - 1) is not scorable but still has numeric score [$number].")
        } elseif ($number -ge 55) {
            $highCount++
        } else {
            $lowCount++
        }
    } elseif ($score -in @('—', '-', '—（未评分）')) {
        $notScoredCount++
        if (-not $isNotScored) {
            $errors.Add("Data row $($r - 1) is unscored but lacks an explicit terminal reason.")
        }
    } else {
        $errors.Add("Data row $($r - 1) has invalid 正式评分 value [$score].")
    }
}

$dataCount = [Math]::Max(0, $rows.Count - 2)
$heading = ($lines | Where-Object { $_ -match '^##.*全量.*｜\d+条' } | Select-Object -First 1)
if ($heading -match '｜(\d+)条') {
    $declaredTotal = [int]$Matches[1]
    if ($declaredTotal -ne $dataCount) {
        $errors.Add("Heading declares $declaredTotal rows; found $dataCount.")
    }
}

$body = $lines -join "`n"
if ($body -match '正式评分大于等于55分：\s*(\d+)条') {
    if ([int]$Matches[1] -ne $highCount) { $errors.Add("Summary >=55 count does not match table count $highCount.") }
} else { $errors.Add('Missing >=55 summary count.') }
if ($body -match '正式评分低于55分：\s*(\d+)条') {
    if ([int]$Matches[1] -ne $lowCount) { $errors.Add("Summary <55 count does not match table count $lowCount.") }
} else { $errors.Add('Missing <55 summary count.') }
if ($body -match '核验硬排除：\s*(\d+)条') {
    if ([int]$Matches[1] -ne $notScoredCount) { $errors.Add("Summary not-scored count does not match table count $notScoredCount.") }
} else { $errors.Add('Missing not-scored summary count.') }
if (($highCount + $lowCount + $notScoredCount) -ne $dataCount) {
    $errors.Add("Nested reconciliation failed: $dataCount != $highCount + $lowCount + $notScoredCount.")
}
if ($lines -match '待核|待确认|待补') {
    $errors.Add('Audit ledger contains unfinished verification wording.')
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "Audit validation passed: $resolved"
Write-Output "Total=$dataCount; Scored>=55=$highCount; Scored<55=$lowCount; NotScored=$notScoredCount"
