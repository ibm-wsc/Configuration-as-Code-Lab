<#
.SYNOPSIS
    Downloads the JSON schemas from the Configuration-as-Code-Lab repository
    to a local workstation directory.

.DESCRIPTION
    Lists the files in the repository's "schemas" folder through the GitHub
    API and downloads every *.json file over HTTPS. The destination directory
    is created if it does not exist. Existing files are overwritten.
    It then downloads the .vsix from the repository's "vscodeplugin" folder and
    installs it with the VS Code "code" command (VS Code must be installed).
    Works with Windows PowerShell 5.1 and PowerShell 7+. No git required.
    Git setup and cloning live in clone_student_repo.ps1.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\download_schemas.ps1

.EXAMPLE
    .\download_schemas.ps1 -Destination "D:\my-schemas" -Branch main
#>
[CmdletBinding()]
param(
    [string]$Destination = "C:\Users\itzuser\Documents\schemas",
    [string]$Owner       = "ibm-wsc",
    [string]$Repo        = "Configuration-as-Code-Lab",
    [string]$Branch      = "main",
    [string]$SchemaPath  = "schemas",
    [string]$ExtensionPath = "vscodeplugin"
)

$ErrorActionPreference = "Stop"

# Windows PowerShell 5.1 does not enable TLS 1.2 by default
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = "SilentlyContinue"   # much faster Invoke-WebRequest on 5.1

# Create the destination directory if needed
if (-not (Test-Path -LiteralPath $Destination -PathType Container)) {
    Write-Host "Creating directory: $Destination"
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
}

$apiUrl = "https://api.github.com/repos/$Owner/$Repo/contents/${SchemaPath}?ref=$Branch"
Write-Host "Fetching schema list from $Owner/$Repo ($Branch)..."

try {
    $items = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "schema-downloader" } -TimeoutSec 30
}
catch {
    Write-Error "Unable to list schemas from GitHub: $($_.Exception.Message)"
    exit 1
}

$files = @($items | Where-Object { $_.type -eq "file" -and $_.name -like "*.json" })
if ($files.Count -eq 0) {
    Write-Error "No .json schema files found at '$SchemaPath' on branch '$Branch'."
    exit 1
}

$count = 0
foreach ($file in $files) {
    $target = Join-Path -Path $Destination -ChildPath $file.name
    Write-Host "Downloading: $($file.name)"
    try {
        Invoke-WebRequest -Uri $file.download_url -OutFile $target -UseBasicParsing -TimeoutSec 60
        $count++
    }
    catch {
        Write-Error "Failed to download $($file.name): $($_.Exception.Message)"
        exit 1
    }
}

Write-Host "Done. Downloaded $count schema file(s) to $Destination"

# Download and install the VS Code extension (.vsix)
Write-Host "Fetching VS Code extension from $Owner/$Repo ($Branch)..."
try {
    $pluginItems = Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo/contents/${ExtensionPath}?ref=$Branch" -Headers @{ "User-Agent" = "schema-downloader" } -TimeoutSec 30
}
catch {
    Write-Error "Unable to list the extension from GitHub: $($_.Exception.Message)"
    exit 1
}

$vsix = @($pluginItems | Where-Object { $_.type -eq "file" -and $_.name -like "*.vsix" } | Sort-Object name) | Select-Object -Last 1
if (-not $vsix) {
    Write-Error "No .vsix file found at '$ExtensionPath' on branch '$Branch'."
    exit 1
}

$vsixTarget = Join-Path -Path $env:TEMP -ChildPath $vsix.name
Write-Host "Downloading: $($vsix.name)"
try {
    Invoke-WebRequest -Uri $vsix.download_url -OutFile $vsixTarget -UseBasicParsing -TimeoutSec 120
}
catch {
    Write-Error "Failed to download $($vsix.name): $($_.Exception.Message)"
    exit 1
}

# Locate the VS Code command-line launcher
$codeCmd = Get-Command code -ErrorAction SilentlyContinue
if ($codeCmd) {
    $code = $codeCmd.Source
}
else {
    $code = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $code) {
    Write-Error "VS Code 'code' command not found. Install VS Code, or install manually: $vsixTarget"
    exit 1
}

Write-Host "Installing extension $($vsix.name)..."
& $code --install-extension $vsixTarget --force
if ($LASTEXITCODE -ne 0) {
    Write-Error "Extension install failed (exit code $LASTEXITCODE)."
    exit 1
}

Write-Host "Done. Installed $($vsix.name). Restart VS Code if it is open."
