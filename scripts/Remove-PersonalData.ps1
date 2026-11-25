<#
    Remove-PersonalData.ps1

    Scrubs personal data (see scripts\lib\PersonalData.ps1) from every JSON file under data\ and
    checks the published page too. The fetch script already scrubs as it saves; this cleans older
    files and is the guard the weekly workflow runs before it commits anything.

        .\scripts\Remove-PersonalData.ps1           # clean data\ in place
        .\scripts\Remove-PersonalData.ps1 -Check    # change nothing; fail if any file still holds personal data
#>
[CmdletBinding()]
param([switch]$Check)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'lib\PersonalData.ps1')

$files = @(Get-ChildItem (Join-Path $root 'data') -Recurse -File -Filter '*.json')
$page = Join-Path $root 'docs\index.html'
if ($Check -and (Test-Path $page)) { $files += Get-Item $page }

$dirty = 0
foreach ($f in $files) {
    $bytes = [IO.File]::ReadAllBytes($f.FullName)
    $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $enc = New-Object Text.UTF8Encoding($bom)
    $skip = if ($bom) { 3 } else { 0 }
    $text = $enc.GetString($bytes, $skip, $bytes.Length - $skip)
    $clean = Protect-LeagueJson $text
    if ($clean -ceq $text) { continue }
    $dirty++
    if ($Check) { Write-Warning "personal data in $($f.FullName.Substring($root.Length + 1))"; continue }
    $null = $clean | ConvertFrom-Json      # never write a file the scrub has broken
    [IO.File]::WriteAllText($f.FullName, $clean, $enc)
}
if ($Check) {
    if ($dirty) { throw "$dirty file(s) still contain personal data - run .\scripts\Remove-PersonalData.ps1" }
    Write-Host "personal-data check: clean ($($files.Count) files)"
} else {
    Write-Host "scrubbed $dirty of $($files.Count) files"
}
