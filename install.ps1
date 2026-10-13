<#
.SYNOPSIS
    Install the personal OpenCode agent configuration from this repository.

.DESCRIPTION
    Copies the OpenCode 2 configuration snapshot (agent-setup/snapshot/opencode-v2),
    the local handoff plugin and the two repository skills (agent-setup and
    personal-code-prompt) into an OpenCode config directory.

    The snapshot was validated on OpenCode 2.0.25, but it is not restricted to
    that version: only the plugin version is pinned, and fields may change
    between OpenCode versions. The evidence the install requires is:
      - the OpenCode version is read from the actual CLI and printed, but it is
        NOT a gate; any reported version continues. The script stops only when
        no version can be read at all (no evidence);
      - the plugin cache directory comes from the same CLI ('debug paths cache',
        which only reads local paths, no server and no database);
      - the oh-my-opencode-slim version is the pinned version declared in the
        target config and the package found in that cache for the greatest
        numeric generation.
    When any of that is missing or ambiguous the script stops before writing and
    points the user at the agent-setup skill, which adapts the configuration to
    the machine instead of copying old fields.

    What this script deliberately does NOT do:
      - install OpenCode or any dependency;
      - copy the machine-specific startup scripts under snapshot/machine-specific;
      - change launchers or shortcuts. For environment variables it only handles
        the ones referenced by the config: secrets use hidden input, *_BASE_URL
        gateway addresses use visible input, and values are never printed;
      - restart OpenCode or call any model (no paid requests, no availability check).

.PARAMETER ConfigDir
    OpenCode config directory to install into. This is the only trusted source;
    when it is omitted the default directories are only guesses and the user must
    confirm the real one (or type another absolute directory).

.PARAMETER CliPath
    OpenCode CLI used for the version and cache checks. Defaults to the CLI on PATH.

.NOTES
    Messages are ASCII-only on purpose: Windows PowerShell 5.1 reads BOM-less
    script files using the system ANSI codepage, which corrupts non-ASCII text.
#>
[CmdletBinding()]
param(
    [string]$ConfigDir,
    [string]$CliPath
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Settings
#
# The snapshot was validated on OpenCode 2.0.25, but the install does not
# restrict the OpenCode version; only the plugin version is pinned. Fields and
# plugin layout may change between OpenCode versions, so update these only
# together with agent-setup/snapshot/opencode-v2.
# ---------------------------------------------------------------------------
$RequiredPluginName      = 'oh-my-opencode-slim'
$RequiredPluginVersion   = '3.0.2'

$RepoRoot        = Split-Path -Parent $MyInvocation.MyCommand.Path
$SnapshotDir     = Join-Path $RepoRoot 'agent-setup\snapshot\opencode-v2'
$SkillsToInstall = @('agent-setup', 'personal-code-prompt')
$Utf8NoBom       = New-Object System.Text.UTF8Encoding($false)

function Stop-WithReport {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host ''
    Write-Host "STOP: $Message" -ForegroundColor Yellow
    Write-Host 'Nothing was written. Use the agent-setup skill to adapt the configuration to this machine.'
    exit 2
}

# Resolves the target config directory. Only -ConfigDir and OPENCODE_CONFIG_DIR
# are trusted directly; anything derived from default locations is a guess the
# user must confirm, because the CLI does not expose its config path to a script.
function Resolve-TargetConfigDir {
    param([string]$Explicit)

    if ($Explicit) {
        if (-not (Test-Path -LiteralPath $Explicit -PathType Container)) { Stop-WithReport "ConfigDir not found: $Explicit" }
        return @{ Path = (Resolve-Path -LiteralPath $Explicit).Path; Source = '-ConfigDir (explicit)' }
    }
    if ($env:OPENCODE_CONFIG_DIR) {
        if (-not (Test-Path -LiteralPath $env:OPENCODE_CONFIG_DIR -PathType Container)) { Stop-WithReport "OPENCODE_CONFIG_DIR not found: $env:OPENCODE_CONFIG_DIR" }
        return @{ Path = (Resolve-Path -LiteralPath $env:OPENCODE_CONFIG_DIR).Path; Source = 'OPENCODE_CONFIG_DIR (environment)' }
    }

    $candidates = @()
    if ($env:XDG_CONFIG_HOME) { $candidates += (Join-Path $env:XDG_CONFIG_HOME 'opencode') }
    $candidates += (Join-Path $env:USERPROFILE '.config\opencode')
    $candidates = @($candidates | Select-Object -Unique | Where-Object { Test-Path -LiteralPath $_ -PathType Container })

    Write-Host ''
    Write-Host 'No -ConfigDir and no OPENCODE_CONFIG_DIR was given.'
    Write-Host 'This script cannot read the config directory from the CLI, so the association below is your choice, not detection.'
    if ($candidates.Count -gt 0) {
        Write-Host 'Default candidates (guesses, not verified against the CLI):'
        for ($i = 0; $i -lt $candidates.Count; $i++) { Write-Host ('  [{0}] {1}' -f ($i + 1), $candidates[$i]) }
        Write-Host '  [p] type another absolute directory'
        $answer = Read-Host 'Choose the config directory the current CLI actually uses'
    }
    else {
        Write-Host 'No default candidate directories were found.'
        $answer = 'p'
    }

    if ($answer -match '^\s*\d+\s*$') {
        $index = [int]$answer
        if ($index -lt 1 -or $index -gt $candidates.Count) { Stop-WithReport 'Invalid choice.' }
        return @{ Path = (Resolve-Path -LiteralPath $candidates[$index - 1]).Path; Source = 'user-confirmed default candidate' }
    }

    $typed = Read-Host 'Enter the absolute OpenCode config directory'
    if (-not $typed -or -not (Test-Path -LiteralPath $typed -PathType Container)) { Stop-WithReport "Config directory not found: $typed" }
    return @{ Path = (Resolve-Path -LiteralPath $typed).Path; Source = 'user-entered absolute path' }
}

function Resolve-OpenCodeCli {
    param([string]$Explicit)

    if ($Explicit) {
        if (-not (Test-Path -LiteralPath $Explicit)) { Stop-WithReport "CliPath not found: $Explicit" }
        return $Explicit
    }
    if ($env:OPENCODE_BINARY -and (Test-Path -LiteralPath $env:OPENCODE_BINARY)) { return $env:OPENCODE_BINARY }

    $command = Get-Command -Name 'opencode' -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) { Stop-WithReport 'OpenCode CLI not found on PATH. OpenCode must already be installed.' }
    return $command.Source
}

function Get-OpenCodeVersion {
    param([Parameter(Mandatory)][string]$Cli)

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = $null
    try { $output = & $Cli --version 2>&1 } catch { $output = $null }
    $ErrorActionPreference = $previousPreference
    if ($output) {
        $text = ($output | Out-String)
        if ($text -match '(\d+\.\d+\.\d+)') { return $Matches[1] }
    }
    return $null
}

# Asks the selected CLI where its cache lives. Per the v2 docs, 'opencode debug
# paths cache' only prints a local path; it does not start a server or open a
# database. The output must be exactly one absolute, existing directory.
function Get-CliCacheDir {
    param([Parameter(Mandatory)][string]$Cli)

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = $null
    try { $output = & $Cli debug paths cache } catch { $output = $null }
    $ErrorActionPreference = $previousPreference

    $lines = @($output | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ -ne '' })
    if ($lines.Count -ne 1) { return $null }
    $candidate = $lines[0]
    if (-not [System.IO.Path]::IsPathRooted($candidate)) { return $null }
    if (-not (Test-Path -LiteralPath $candidate -PathType Container)) { return $null }
    return $candidate
}

# normalize.ts merges 'plugin' and 'plugins'; entries are plain strings or
# {package, options} objects. Collect the oh-my-opencode-slim declarations.
function Get-PluginDeclarations {
    param(
        [Parameter(Mandatory)]$Config,
        [Parameter(Mandatory)][string]$PluginName
    )

    $specs = @()
    foreach ($key in @('plugin', 'plugins')) {
        foreach ($entry in @($Config.$key)) {
            if ($null -eq $entry) { continue }
            $spec = $null
            if ($entry -is [string]) { $spec = $entry }
            elseif ($entry.PSObject.Properties['package']) { $spec = [string]$entry.package }
            if (-not $spec) { continue }
            if ($spec -eq $PluginName) { $specs += $spec }
            elseif ($spec -match ('^' + [regex]::Escape($PluginName) + '@(.+)$')) { $specs += $spec }
        }
    }
    return $specs
}

# Verifies the pinned declaration in the target config.
function Resolve-PluginDeclaration {
    param(
        [Parameter(Mandatory)][string]$TargetConfigDir,
        [Parameter(Mandatory)][string]$PluginName
    )

    $configPath = Join-Path $TargetConfigDir 'opencode.jsonc'
    if (-not (Test-Path -LiteralPath $configPath)) {
        $jsonPath = Join-Path $TargetConfigDir 'opencode.json'
        if (Test-Path -LiteralPath $jsonPath) { $configPath = $jsonPath }
        else { return @{ Status = 'NoConfig'; Detail = "No opencode.jsonc or opencode.json in $TargetConfigDir" } }
    }

    try { $config = ConvertFrom-Jsonc -Text ([System.IO.File]::ReadAllText($configPath, [System.Text.Encoding]::UTF8)) }
    catch { return @{ Status = 'ParseError'; Detail = "Cannot parse ${configPath}: $($_.Exception.Message)"; ConfigPath = $configPath } }

    $specs = @(Get-PluginDeclarations -Config $config -PluginName $PluginName)
    if ($specs.Count -eq 0) { return @{ Status = 'NotDeclared'; Detail = "$PluginName is not declared in $configPath"; ConfigPath = $configPath } }
    if ($specs.Count -gt 1) { return @{ Status = 'Ambiguous'; Detail = "Multiple $PluginName declarations in ${configPath}: $($specs -join ', ')"; ConfigPath = $configPath } }

    $spec = $specs[0]
    $result = @{ ConfigPath = $configPath; Spec = $spec }
    if ($spec -eq $PluginName) {
        $result.Status = 'Unpinned'
        $result.Detail = "$PluginName is declared without a version, so the loaded version cannot be proven statically."
        return $result
    }
    $declaredVersion = $spec.Substring($PluginName.Length + 1)
    if ($declaredVersion -notmatch '^\d+\.\d+\.\d+$') {
        $result.Status = 'Unpinned'
        $result.Detail = "Declared version '$declaredVersion' is not an exact x.y.z version."
        return $result
    }
    $result.Status = 'Pinned'
    $result.DeclaredVersion = $declaredVersion
    return $result
}

# Resolves the plugin package the config will load. The npm cache layout is
# <global.cache>/npm/<name>@<version>/<generation>/node_modules/<name>
# (packages/util/src/npm.ts, v2.0.23 and v2.0.25, unchanged); a pinned version reuses the greatest
# numeric generation, so the greatest generation must hold a valid package. Never
# fall back to an older generation.
function Resolve-InstalledPluginPackage {
    param(
        [Parameter(Mandatory)][string]$CacheDir,
        [Parameter(Mandatory)][string]$PluginName,
        [Parameter(Mandatory)][string]$DeclaredVersion
    )

    $versionRoot = Join-Path $CacheDir ('npm\' + $PluginName + '@' + $DeclaredVersion)
    if (-not (Test-Path -LiteralPath $versionRoot -PathType Container)) {
        return @{ Status = 'NotInstalled'; Detail = "No package directory at $versionRoot"; VersionRoot = $versionRoot }
    }

    $generations = @()
    foreach ($dir in (Get-ChildItem -LiteralPath $versionRoot -Directory -ErrorAction SilentlyContinue)) {
        $value = [long]0
        if ([long]::TryParse($dir.Name, [ref]$value)) { $generations += @{ Name = $dir.Name; Value = $value } }
    }
    if ($generations.Count -eq 0) {
        return @{ Status = 'NoGeneration'; Detail = "No numeric generation directory under $versionRoot"; VersionRoot = $versionRoot }
    }

    $greatest = $generations | Sort-Object { $_.Value } | Select-Object -Last 1
    $manifest = Join-Path $versionRoot ($greatest.Name + '\node_modules\' + $PluginName + '\package.json')
    if (-not (Test-Path -LiteralPath $manifest)) {
        return @{ Status = 'GenerationInvalid'; Detail = "Greatest generation '$($greatest.Name)' has no $PluginName package at $manifest"; VersionRoot = $versionRoot; Generation = $greatest.Name }
    }

    try { $meta = [System.IO.File]::ReadAllText($manifest, [System.Text.Encoding]::UTF8) | ConvertFrom-Json }
    catch { return @{ Status = 'GenerationInvalid'; Detail = "Cannot parse ${manifest}: $($_.Exception.Message)"; VersionRoot = $versionRoot; Generation = $greatest.Name } }

    if ($meta.name -ne $PluginName -or [string]$meta.version -ne $DeclaredVersion) {
        return @{ Status = 'GenerationInvalid'; Detail = "Greatest generation '$($greatest.Name)' package is name='$($meta.name)' version='$($meta.version)', expected $PluginName@$DeclaredVersion"; VersionRoot = $versionRoot; Generation = $greatest.Name; Manifest = $manifest }
    }

    return @{ Status = 'Resolved'; Manifest = $manifest; Version = [string]$meta.version; Generation = $greatest.Name; VersionRoot = $versionRoot }
}

# Builds the file-by-file install plan. machine-specific directories are never
# copied (they are launchers for one specific machine).
function New-InstallPlan {
    param(
        [Parameter(Mandatory)][string]$SnapshotPath,
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string[]]$Skills
    )

    $mappings = @(
        @{ Source = (Join-Path $SnapshotPath 'opencode.jsonc');           Rel = 'opencode.jsonc' },
        @{ Source = (Join-Path $SnapshotPath 'AGENTS.md');                 Rel = 'AGENTS.md' },
        @{ Source = (Join-Path $SnapshotPath 'oh-my-opencode-slim.json');  Rel = 'oh-my-opencode-slim.json' },
        @{ Source = (Join-Path $SnapshotPath 'oh-my-opencode-slim');       Rel = 'oh-my-opencode-slim' },
        @{ Source = (Join-Path $SnapshotPath 'plugins');                   Rel = 'plugins' }
    )
    foreach ($skill in $Skills) {
        $mappings += @{ Source = (Join-Path $RepositoryRoot $skill); Rel = ('skills\' + $skill) }
    }

    $plan = @()
    foreach ($mapping in $mappings) {
        if (-not (Test-Path -LiteralPath $mapping.Source)) { Stop-WithReport "Missing install source: $($mapping.Source)" }
        if (Test-Path -LiteralPath $mapping.Source -PathType Container) {
            Get-ChildItem -LiteralPath $mapping.Source -Recurse -File -Force | ForEach-Object {
                $relative = $_.FullName.Substring($mapping.Source.Length).TrimStart('\')
                if ($relative -match '(^|\\)machine-specific(\\|$)') { return }
                $plan += @{ Source = $_.FullName; Rel = ($mapping.Rel + '\' + $relative) }
            }
        }
        else {
            $plan += @{ Source = $mapping.Source; Rel = $mapping.Rel }
        }
    }
    return $plan
}

# Finds absolute machine paths in the files to be installed. Only paths under a
# user profile (X:\Users\<name>) can be safely remapped to the current profile;
# anything else makes the script stop rather than guess.
function Get-MachinePathInfo {
    param([Parameter(Mandatory)][string[]]$Files)

    $anchors   = New-Object System.Collections.Generic.List[string]
    $unsafe    = New-Object System.Collections.Generic.List[string]
    $pathFiles = New-Object 'System.Collections.Generic.HashSet[string]'

    foreach ($file in $Files) {
        $bytes = [System.IO.File]::ReadAllBytes($file)
        if ($bytes -contains 0) { continue }
        $text = [System.Text.Encoding]::UTF8.GetString($bytes)
        # JSON escapes backslashes, so collapse doubled backslashes before scanning.
        $scan = $text.Replace('\\', '\')
        $found = $false
        foreach ($match in [regex]::Matches($scan, '[A-Za-z]:\\[A-Za-z0-9\\._\-]*')) {
            $found = $true
            $value = $match.Value
            if ($value -match '^([A-Za-z]:\\Users\\[^\\]+)') {
                if (-not $anchors.Contains($Matches[1])) { [void]$anchors.Add($Matches[1]) }
            }
            else {
                if (-not $unsafe.Contains($value)) { [void]$unsafe.Add($value) }
            }
        }
        if ($found) { [void]$pathFiles.Add($file) }
    }

    return @{ Anchors = $anchors; Unsafe = $unsafe; PathFiles = $pathFiles }
}

# Parses JSONC (JSON with comments and trailing commas) without external modules.
function ConvertFrom-Jsonc {
    param([Parameter(Mandatory)][string]$Text)

    $builder = New-Object System.Text.StringBuilder
    $inString = $false
    $escaped = $false
    $i = 0
    while ($i -lt $Text.Length) {
        $char = $Text[$i]
        if ($inString) {
            [void]$builder.Append($char)
            if ($escaped) { $escaped = $false }
            elseif ($char -eq '\') { $escaped = $true }
            elseif ($char -eq '"') { $inString = $false }
            $i++
            continue
        }
        if ($char -eq '"') { $inString = $true; [void]$builder.Append($char); $i++; continue }
        if ($char -eq '/' -and $i + 1 -lt $Text.Length -and $Text[$i + 1] -eq '/') {
            while ($i -lt $Text.Length -and $Text[$i] -ne "`n") { $i++ }
            continue
        }
        if ($char -eq '/' -and $i + 1 -lt $Text.Length -and $Text[$i + 1] -eq '*') {
            $i += 2
            while ($i + 1 -lt $Text.Length -and -not ($Text[$i] -eq '*' -and $Text[$i + 1] -eq '/')) { $i++ }
            $i += 2
            continue
        }
        [void]$builder.Append($char)
        $i++
    }
    $json = $builder.ToString()
    $json = [regex]::Replace($json, ',\s*([}\]])', '$1')
    return ($json | ConvertFrom-Json)
}

function Read-SecretText {
    param([Parameter(Mandatory)][string]$Prompt)
    $secure = Read-Host -Prompt $Prompt -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}

# ---------------------------------------------------------------------------
# 1. Resolve the target config directory and the CLI.
# ---------------------------------------------------------------------------
$configSelection = Resolve-TargetConfigDir -Explicit $ConfigDir
$targetConfig = $configSelection.Path
$cli = Resolve-OpenCodeCli -Explicit $CliPath

# ---------------------------------------------------------------------------
# 2. Read the CLI version first, before asking it for anything else. The
#    snapshot was validated on OpenCode 2.0.25, but the version is not a gate:
#    any reported version continues. Only an unreadable version stops, because
#    then there is no evidence at all.
# ---------------------------------------------------------------------------
$openCodeVersion = Get-OpenCodeVersion -Cli $cli
if (-not $openCodeVersion) {
    Stop-WithReport 'Cannot read an OpenCode version from the CLI; there is not enough evidence to continue.'
}

# ---------------------------------------------------------------------------
# 3. Read the pinned plugin declaration from the target config.
# ---------------------------------------------------------------------------
$declaration = Resolve-PluginDeclaration -TargetConfigDir $targetConfig -PluginName $RequiredPluginName
if ($declaration.Status -ne 'Pinned') {
    Stop-WithReport "Cannot read one pinned $RequiredPluginName declaration ($($declaration.Status)): $($declaration.Detail)"
}
if ($declaration.DeclaredVersion -ne $RequiredPluginVersion) {
    Stop-WithReport ("Version mismatch. This snapshot is for {0} {1}; the target config declares {0}@{2}." -f $RequiredPluginName, $RequiredPluginVersion, $declaration.DeclaredVersion)
}

# ---------------------------------------------------------------------------
# 4. Ask the same CLI for its cache dir, then verify the package there.
# ---------------------------------------------------------------------------
$cacheDir = Get-CliCacheDir -Cli $cli
if (-not $cacheDir) {
    Stop-WithReport "The CLI did not print exactly one valid absolute cache directory for 'debug paths cache'."
}

$package = Resolve-InstalledPluginPackage -CacheDir $cacheDir -PluginName $RequiredPluginName -DeclaredVersion $declaration.DeclaredVersion
if ($package.Status -ne 'Resolved') {
    Stop-WithReport "Cannot prove which $RequiredPluginName package the config will load ($($package.Status)): $($package.Detail)"
}
if ($package.Version -ne $RequiredPluginVersion) {
    Stop-WithReport ("Version mismatch. This snapshot is for {0} {1}; the resolved package is {0} {2}." -f $RequiredPluginName, $RequiredPluginVersion, $package.Version)
}

# ---------------------------------------------------------------------------
# 5. Show the runtime association and its limits.
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host 'Runtime association:'
Write-Host ('  config dir        : {0}' -f $targetConfig)
Write-Host ('  config dir source : {0}' -f $configSelection.Source)
Write-Host ('  CLI               : {0}' -f $cli)
Write-Host ('  OpenCode version  : {0}' -f $openCodeVersion)
Write-Host ('  cache dir (CLI)   : {0}' -f $cacheDir)
Write-Host ('  plugin declared   : {0}  (in {1})' -f $declaration.Spec, $declaration.ConfigPath)
Write-Host ('  plugin generation : {0}' -f $package.Generation)
Write-Host ('  plugin package    : {0}  (version {1})' -f $package.Manifest, $package.Version)
Write-Host ''
Write-Host 'This is the plugin package the config resolves when OpenCode starts through the selected CLI with this cache'
Write-Host 'environment. It does NOT prove the plugin version of a service that is already running: a separately started'
Write-Host 'service can use different environment variables.'

# ---------------------------------------------------------------------------
# 6. Build the plan and adapt machine absolute paths (or stop).
# ---------------------------------------------------------------------------
$plan = @(New-InstallPlan -SnapshotPath $SnapshotDir -RepositoryRoot $RepoRoot -Skills $SkillsToInstall)
$pathInfo = Get-MachinePathInfo -Files @($plan | Select-Object -ExpandProperty Source)

if ($pathInfo.Unsafe.Count -gt 0) {
    Write-Host 'Absolute paths that are not under a user profile were found:' -ForegroundColor Yellow
    foreach ($unsafePath in $pathInfo.Unsafe) { Write-Host ('  ' + $unsafePath) }
    Stop-WithReport 'These paths cannot be remapped safely. Use the agent-setup skill to adapt them by hand.'
}

$remappedAnchors = @($pathInfo.Anchors | Where-Object { $_ -ine $env:USERPROFILE })
foreach ($entry in $plan) {
    $bytes = [System.IO.File]::ReadAllBytes($entry.Source)
    if ($pathInfo.PathFiles.Contains($entry.Source)) {
        $text = [System.Text.Encoding]::UTF8.GetString($bytes)
        foreach ($anchor in $remappedAnchors) {
            $text = $text.Replace($anchor.Replace('\', '\\'), $env:USERPROFILE.Replace('\', '\\'))
            $text = $text.Replace($anchor, $env:USERPROFILE)
        }
        $entry.OutputBytes = $Utf8NoBom.GetBytes($text)
    }
    else {
        $entry.OutputBytes = $bytes
    }
}

# ---------------------------------------------------------------------------
# 7. Show scope, confirm, back up, then write.
# ---------------------------------------------------------------------------
$overwrite = @($plan | Where-Object { Test-Path -LiteralPath (Join-Path $targetConfig $_.Rel) })
$conflicts = @($overwrite | Where-Object {
    $existing = [System.IO.File]::ReadAllBytes((Join-Path $targetConfig $_.Rel))
    $incoming = $_.OutputBytes
    if ($existing.Length -ne $incoming.Length) { return $true }
    for ($i = 0; $i -lt $existing.Length; $i++) { if ($existing[$i] -ne $incoming[$i]) { return $true } }
    return $false
})

Write-Host ''
Write-Host ('Target  : {0}' -f $targetConfig)
Write-Host ('Files   : {0} total, {1} new, {2} to overwrite' -f $plan.Count, ($plan.Count - $overwrite.Count), $overwrite.Count)
Write-Host ('Remaps  : {0}' -f ($(if ($remappedAnchors.Count) { ($remappedAnchors -join ', ') + ' -> ' + $env:USERPROFILE } else { 'none' })))
if ($overwrite.Count -gt 0) {
    Write-Host 'Overwrite scope:'
    foreach ($entry in $overwrite) { Write-Host ('  ~ ' + $entry.Rel) }
}

if ($conflicts.Count -gt 0) {
    Write-Host ''
    Write-Host 'These existing files differ from the snapshot (local changes):' -ForegroundColor Yellow
    foreach ($entry in $conflicts) { Write-Host ('  ! ' + $entry.Rel) }
    $answer = Read-Host 'Overwrite all of them? [y/N]'
    if ($answer -notmatch '^[Yy]') { Stop-WithReport 'Declined at the conflict confirmation.' }
}

Write-Host ''
Write-Host 'Confirm the launch environment before anything is written:'
Write-Host ('  CLI       : {0}' -f $cli)
Write-Host ('  config    : {0}' -f $targetConfig)
Write-Host ('  cache     : {0}' -f $cacheDir)
Write-Host '  You must confirm you will start or restart OpenCode through this CLI with this config and cache'
Write-Host '  environment. Otherwise the resolved plugin version above does not apply.'
$answer = Read-Host 'Confirm and continue (backup + install)? [y/N]'
if ($answer -notmatch '^[Yy]') { Stop-WithReport 'Launch environment not confirmed.' }

$backupDir = Join-Path (Split-Path -Parent $targetConfig) ('opencode-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
foreach ($entry in $overwrite) {
    $backupPath = Join-Path $backupDir $entry.Rel
    $backupParent = Split-Path -Parent $backupPath
    if ($backupParent) { New-Item -ItemType Directory -Force -Path $backupParent | Out-Null }
    Copy-Item -LiteralPath (Join-Path $targetConfig $entry.Rel) -Destination $backupPath -Force
}
Write-Host ('Backup : {0}' -f $backupDir)

foreach ($entry in $plan) {
    $destination = Join-Path $targetConfig $entry.Rel
    $destinationParent = Split-Path -Parent $destination
    if ($destinationParent) { New-Item -ItemType Directory -Force -Path $destinationParent | Out-Null }
    [System.IO.File]::WriteAllBytes($destination, $entry.OutputBytes)
}
Write-Host ('Installed {0} files.' -f $plan.Count)

# ---------------------------------------------------------------------------
# 8. Static parse check (no model calls).
# ---------------------------------------------------------------------------
$parseFailed = $false
try {
    $null = ConvertFrom-Jsonc -Text ([System.IO.File]::ReadAllText((Join-Path $targetConfig 'opencode.jsonc'), [System.Text.Encoding]::UTF8))
    $null = [System.IO.File]::ReadAllText((Join-Path $targetConfig 'oh-my-opencode-slim.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    Write-Host 'Static parse: OK (opencode.jsonc, oh-my-opencode-slim.json)'
}
catch {
    $parseFailed = $true
    Write-Host ('Static parse FAILED: {0}' -f $_.Exception.Message) -ForegroundColor Red
}

# ---------------------------------------------------------------------------
# 9. Environment variables: set the ones the config references. Secrets use
#    hidden input; gateway base URLs (*_BASE_URL) use visible input because an
#    address is not a secret. Values are never printed.
# ---------------------------------------------------------------------------
$configText = [System.IO.File]::ReadAllText((Join-Path $targetConfig 'opencode.jsonc'), [System.Text.Encoding]::UTF8)
$envNames = @([regex]::Matches($configText, '\{env:([^}]+)\}') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)

Write-Host ''
Write-Host 'Environment variables referenced by the config:'
foreach ($name in $envNames) {
    $existing = [Environment]::GetEnvironmentVariable($name, 'User')
    if ($existing) {
        $answer = Read-Host ('  {0} already set in User scope. Update it? [y/N]' -f $name)
        if ($answer -notmatch '^[Yy]') { Write-Host ('  kept {0}' -f $name); continue }
    }
    if ($name -match '_BASE_URL$') {
        $value = Read-Host ('  enter {0} (visible, empty to skip)' -f $name)
    }
    else {
        $value = Read-SecretText -Prompt ('  enter {0} (hidden, empty to skip)' -f $name)
    }
    if ([string]::IsNullOrEmpty($value)) { Write-Host ('  skipped {0}' -f $name); continue }
    [Environment]::SetEnvironmentVariable($name, $value, 'User')
    Write-Host ('  set {0} for the current user' -f $name)
}

# ---------------------------------------------------------------------------
# 10. Report. No auto-restart, no model call, no availability claim.
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host 'Done. Restart OpenCode for the configuration to take effect.'
Write-Host 'Model availability was NOT checked: this script only compared versions and parsed the config statically.'
Write-Host 'Confirm that each provider and model actually works on this machine after restart.'
if ($parseFailed) { exit 1 }
