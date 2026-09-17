<#
.SYNOPSIS
    Sync skills between this repository and the opencode runtime skills directory.

.DESCRIPTION
    Compares every skill folder in this repository against its runtime copy and
    reports drift. Push copies repository -> runtime, Pull copies runtime -> repository.
    Status is the default and changes nothing.

    The two locations are maintained independently, so this script is the only
    thing that keeps them consistent.

.PARAMETER Direction
    Status (default), Push, or Pull.

.PARAMETER Target
    Runtime skills directory. Defaults to ~/.config/opencode/skills

.PARAMETER Skill
    Limit the operation to a single skill folder name.

.PARAMETER Repo
    Repository root. Defaults to the folder containing this script.

.NOTES
    The repository root is resolved inside the script body rather than as a
    param() default, because Windows PowerShell 5.1 does not populate
    $PSScriptRoot at param-binding time when the script is launched with
    'powershell.exe -File'.

.EXAMPLE
    .\sync.ps1
    .\sync.ps1 -Direction Push
    .\sync.ps1 -Direction Pull -Skill prompt-engineering

.NOTES
    Messages are ASCII-only on purpose: Windows PowerShell 5.1 reads script files
    that have no BOM using the system ANSI codepage, which corrupts non-ASCII text.
#>
[CmdletBinding()]
param(
    [ValidateSet('Status', 'Push', 'Pull')]
    [string]$Direction = 'Status',

    [string]$Target = (Join-Path $env:USERPROFILE '.config\opencode\skills'),

    [string]$Skill,

    [string]$Repo
)

$ErrorActionPreference = 'Stop'

function Get-ContentHash {
    param([Parameter(Mandatory)][string]$FilePath)

    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        if ($bytes -contains 0) {
            # Binary file: hash raw bytes.
            $hash = $sha.ComputeHash($bytes)
        }
        else {
            # Text file: normalise line endings so CRLF vs LF is not reported as drift.
            $text = [System.Text.Encoding]::UTF8.GetString($bytes)
            $text = $text.Replace("`r`n", "`n").Replace("`r", "`n")
            $hash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($text))
        }
    }
    finally {
        $sha.Dispose()
    }
    return (-join ($hash | ForEach-Object { $_.ToString('x2') }))
}

function Get-FileHashMap {
    param([Parameter(Mandatory)][string]$Root)

    $map = @{}
    if (-not (Test-Path -LiteralPath $Root)) { return $map }

    $prefixLength = $Root.TrimEnd('\', '/').Length
    foreach ($file in (Get-ChildItem -LiteralPath $Root -Recurse -File -Force)) {
        $rel = $file.FullName.Substring($prefixLength).TrimStart('\', '/')
        if ($rel -like '.git\*' -or $rel -like '.git/*') { continue }
        $map[$rel] = Get-ContentHash -FilePath $file.FullName
    }
    return $map
}

function Get-SkillFolders {
    param([Parameter(Mandatory)][string]$Root)

    if (-not (Test-Path -LiteralPath $Root)) { return @() }
    return @(
        Get-ChildItem -LiteralPath $Root -Directory -Force |
            Where-Object {
                $_.Name -notlike '.*' -and
                (Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md'))
            } |
            Sort-Object Name
    )
}

if (-not $Repo) {
    # Resolve the repository root without relying on $PSScriptRoot in param() defaults.
    $scriptFile = $MyInvocation.MyCommand.Path
    if ($scriptFile) {
        $Repo = Split-Path -Parent $scriptFile
    }
    elseif ($PSScriptRoot) {
        $Repo = $PSScriptRoot
    }
    else {
        $Repo = (Get-Location).Path
    }
}

if (-not (Test-Path -LiteralPath $Repo)) {
    throw "Repository root not found: $Repo"
}
$repoRoot = (Resolve-Path -LiteralPath $Repo).Path

$repoSkills = Get-SkillFolders -Root $repoRoot
if ($Skill) {
    $repoSkills = @($repoSkills | Where-Object { $_.Name -eq $Skill })
    if ($repoSkills.Count -eq 0) {
        throw "Skill folder not found in repository: $Skill"
    }
}

Write-Output "Repo:    $repoRoot"
Write-Output "Runtime: $Target"
Write-Output "Mode:    $Direction"
Write-Output ""

$runtimeSkillNames = @((Get-SkillFolders -Root $Target) | Select-Object -ExpandProperty Name)
$orphans = @($runtimeSkillNames | Where-Object { $_ -notin @($repoSkills | Select-Object -ExpandProperty Name) })

$driftCount = 0
$pushCount = 0
$pullCount = 0

foreach ($folder in $repoSkills) {
    $name = $folder.Name
    $runtimePath = Join-Path $Target $name

    if (-not (Test-Path -LiteralPath $runtimePath)) {
        $driftCount++
        Write-Output "[MISSING] $name  - runtime copy does not exist"
        if ($Direction -eq 'Push') {
            New-Item -ItemType Directory -Path $runtimePath -Force | Out-Null
            Copy-Item -Path (Join-Path $folder.FullName '*') -Destination $runtimePath -Recurse -Force
            Write-Output "          pushed -> $runtimePath"
            $pushCount++
        }
        elseif ($Direction -eq 'Pull') {
            Write-Output "          nothing to pull"
        }
        continue
    }

    $repoFiles = Get-FileHashMap -Root $folder.FullName
    $runtimeFiles = Get-FileHashMap -Root $runtimePath

    $onlyRepo = @()
    $onlyRuntime = @()
    $different = @()
    foreach ($key in @($repoFiles.Keys + $runtimeFiles.Keys | Sort-Object -Unique)) {
        $inRepo = $repoFiles.ContainsKey($key)
        $inRuntime = $runtimeFiles.ContainsKey($key)
        if ($inRepo -and -not $inRuntime) { $onlyRepo += $key }
        elseif ($inRuntime -and -not $inRepo) { $onlyRuntime += $key }
        elseif ($repoFiles[$key] -ne $runtimeFiles[$key]) { $different += $key }
    }

    $inSync = ($onlyRepo.Count -eq 0 -and $onlyRuntime.Count -eq 0 -and $different.Count -eq 0)

    if ($inSync) {
        Write-Output "[OK]      $name  ($($repoFiles.Count) files in sync)"
        continue
    }

    $driftCount++
    $parts = @()
    if ($different.Count) { $parts += "differs: $($different.Count)" }
    if ($onlyRepo.Count) { $parts += "repo only: $($onlyRepo.Count)" }
    if ($onlyRuntime.Count) { $parts += "runtime only: $($onlyRuntime.Count)" }
    Write-Output "[DRIFT]   $name  ($($parts -join ', '))"
    foreach ($f in $different) { Write-Output "            ~ $f" }
    foreach ($f in $onlyRepo) { Write-Output "            + $f  (repository only)" }
    foreach ($f in $onlyRuntime) { Write-Output "            - $f  (runtime only, left untouched)" }

    if ($Direction -eq 'Push') {
        Copy-Item -Path (Join-Path $folder.FullName '*') -Destination $runtimePath -Recurse -Force
        Write-Output "          pushed -> $runtimePath"
        $pushCount++
    }
    elseif ($Direction -eq 'Pull') {
        Copy-Item -Path (Join-Path $runtimePath '*') -Destination $folder.FullName -Recurse -Force
        Write-Output "          pulled -> $($folder.FullName)"
        $pullCount++
    }
}

foreach ($name in $orphans) {
    Write-Output "[ORPHAN]  $name  - runtime copy has no repository counterpart (not synced)"
}

Write-Output ""
if ($Direction -eq 'Status') {
    if ($driftCount -eq 0 -and $orphans.Count -eq 0) {
        Write-Output "All skills in sync."
    }
    else {
        Write-Output "$driftCount skill(s) drifted, $($orphans.Count) orphan(s) in runtime."
        Write-Output "Run '.\sync.ps1 -Direction Push' (repo -> runtime) or '.\sync.ps1 -Direction Pull' (runtime -> repo)."
    }
}
else {
    Write-Output "Repositories synced: $pushCount pushed, $pullCount pulled."
}
