$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$manifest = Get-Content -LiteralPath (Join-Path $root 'docs\source-manifest.json') -Raw | ConvertFrom-Json
$seen = @{}
foreach ($entry in $manifest) {
    if ($seen.ContainsKey($entry.SanitizedReference)) { throw 'Duplicate reference path.' }
    $seen[$entry.SanitizedReference] = $true
    $file = Join-Path $root $entry.SanitizedReference
    if (-not $file.EndsWith('.ps1.txt')) { throw 'Historical references must be inert text.' }
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $entry.SanitizedSHA256) { throw "Reference hash mismatch: $($entry.SanitizedReference)" }
    $text = [IO.File]::ReadAllText($file)
    if (-not $text.StartsWith('# Historical source reference - inert text')) { throw 'Missing reference header.' }
    if ($text -match '\bTC\d{3}\b|\b(?:10\.(?:\d{1,3}\.){2}\d{1,3}|172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3})\b') { throw 'Unexpected operational binding in reference.' }
}
$actual = @(Get-ChildItem -LiteralPath (Join-Path $root 'historical') -Recurse -File)
if ($actual.Count -ne $seen.Count) { throw 'Unmanifested historical files exist.' }
if (@($actual | Where-Object { $_.Name -notlike '*.ps1.txt' }).Count) { throw 'Historical tree includes non-reference artifacts.' }
Write-Output "PASS: $($seen.Count) inert source references match their hashes; no source was executed."
