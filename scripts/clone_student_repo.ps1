<#
.SYNOPSIS
    Sets the lab git identity and clones the student branch of the
    Configuration-as-Code-Lab repository.

.DESCRIPTION
    - Sets the global git user.name and user.email (git must be installed).
    - Removes the existing clone directory if present.
    - Clones branch "student-<StudentNumber>" using a GitHub PAT.

    The student number and PAT are saved the first time you supply them (in
    %LOCALAPPDATA%\ConfigAsCodeLab) and reused on later runs, so after the
    first run the script needs no arguments. The PAT is stored encrypted
    (Windows DPAPI, current user and machine only). Pass -StudentNumber or
    -Pat again to replace a saved value, or -Reset to delete both. The PAT is
    sent as an HTTP auth header, so it is never part of the clone URL or the
    cloned repository's remote.

.PARAMETER StudentNumber
    Two-digit student number (for example 07). Optional once saved. If none is
    saved and this is omitted, the script prompts for it.

.PARAMETER Pat
    GitHub PAT as a SecureString. Optional once saved. If none is saved and
    this is omitted, PowerShell prompts with masked input.

.PARAMETER Reset
    Deletes the saved student number and PAT, then exits.

.EXAMPLE
    .\clone_student_repo.ps1
    (first run prompts for anything missing and saves it; later runs need nothing)

.EXAMPLE
    .\clone_student_repo.ps1 -StudentNumber 07 -Pat (Read-Host "PAT" -AsSecureString)
    (replaces the saved values)

.EXAMPLE
    .\clone_student_repo.ps1 -Reset
#>
[CmdletBinding(DefaultParameterSetName = "Clone")]
param(
    [Parameter(ParameterSetName = "Clone")]
    [ValidatePattern('^\d{2}$')]
    [string]$StudentNumber,

    [Parameter(ParameterSetName = "Clone")]
    [securestring]$Pat,

    [Parameter(Mandatory = $true, ParameterSetName = "Reset")]
    [switch]$Reset,

    [Parameter(ParameterSetName = "Clone")]
    [string]$CloneDirectory = "C:\Users\itzuser\Configuration-as-Code-Lab",

    [Parameter(ParameterSetName = "Clone")]
    [string]$Owner = "ibm-wsc",

    [Parameter(ParameterSetName = "Clone")]
    [string]$Repo = "Configuration-as-Code-Lab"
)

$ErrorActionPreference = "Stop"

$configDir   = Join-Path -Path $env:LOCALAPPDATA -ChildPath "ConfigAsCodeLab"
$patFile     = Join-Path -Path $configDir -ChildPath "pat.txt"
$studentFile = Join-Path -Path $configDir -ChildPath "student.txt"

if ($Reset) {
    Remove-Item -LiteralPath $patFile, $studentFile -Force -ErrorAction SilentlyContinue
    Write-Host "Saved student number and PAT removed."
    exit 0
}

if (-not (Test-Path -LiteralPath $configDir -PathType Container)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

# Resolve the student number: parameter (and save it) > saved file > prompt (and save it)
if (-not $StudentNumber -and (Test-Path -LiteralPath $studentFile)) {
    $StudentNumber = (Get-Content -LiteralPath $studentFile -Raw).Trim()
    Write-Host "Using saved student number: $StudentNumber"
}
else {
    while ($StudentNumber -notmatch '^\d{2}$') {
        $StudentNumber = Read-Host "Student number (two digits, e.g. 07)"
    }
    Set-Content -LiteralPath $studentFile -Value $StudentNumber -NoNewline
    Write-Host "Student number saved."
}

# Resolve the PAT: parameter (and save it) > saved file > prompt (and save it)
if (-not $Pat -and (Test-Path -LiteralPath $patFile)) {
    $Pat = Get-Content -LiteralPath $patFile -Raw | ConvertTo-SecureString
    Write-Host "Using saved PAT."
}
else {
    if (-not $Pat) {
        $Pat = Read-Host "GitHub PAT" -AsSecureString
    }
    $Pat | ConvertFrom-SecureString | Set-Content -LiteralPath $patFile -NoNewline
    Write-Host "PAT saved (encrypted) in $patFile"
}

# Configure the global git identity for the lab
git config --global user.name "Lab Student"
git config --global user.email "noone@deadzone.com"

# Remove any existing clone of the lab repository
if (Test-Path -LiteralPath $CloneDirectory) {
    Write-Host "Removing existing directory: $CloneDirectory"
    Remove-Item -LiteralPath $CloneDirectory -Recurse -Force
}

# Clone the student branch. The PAT is sent as an HTTP auth header so it does
# not appear in the clone URL or in the saved git remote.
$studentBranch = "student-$StudentNumber"
$plainPat = [System.Net.NetworkCredential]::new("", $Pat).Password
$pair     = "x-access-token:$plainPat"
$basic    = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
Write-Host "Cloning branch $studentBranch into $CloneDirectory..."
git -c "http.extraHeader=Authorization: Basic $basic" clone -b $studentBranch "https://github.com/$Owner/$Repo.git" $CloneDirectory
if ($LASTEXITCODE -ne 0) {
    Write-Error "git clone failed. If the student number or PAT is wrong, re-run with -StudentNumber / -Pat to replace it."
    exit 1
}

Write-Host "Done. Cloned $studentBranch to $CloneDirectory"
