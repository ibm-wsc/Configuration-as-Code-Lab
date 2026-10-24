<#
.SYNOPSIS
    Downloads the JSON schemas from the Configuration-as-Code-Lab repository
    to a local workstation directory.

.DESCRIPTION
    Lists the files in the repository's "schemas" folder through the GitHub
    API and downloads every *.json file over HTTPS. The destination directory
    is created if it does not exist. Existing files are overwritten.
    Works with Windows PowerShell 5.1 and PowerShell 7+. After downloading, it
    sets the global git user.name and user.email (git must be installed).

.PARAMETER StudentNumber
    Two-digit student number (for example 07). The script clones branch
    "student-<StudentNumber>".

.PARAMETER Pat
    GitHub personal access token, as a SecureString. If omitted, PowerShell
    prompts for it with masked input.

.EXAMPLE
    .\download_schemas.ps1 -StudentNumber 07
    (prompts for the PAT)

.EXAMPLE
    $pat = Read-Host "GitHub PAT" -AsSecureString
    .\download_schemas.ps1 -StudentNumber 07 -Pat $pat -Destination "D:\my-schemas"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d{2}$')]
    [string]$StudentNumber,

    [Parameter(Mandatory = $true)]
    [securestring]$Pat,

    [string]$Destination = "C:\Users\itzuser\Documents\schemas",
    [string]$CloneDirectory = "C:\Users\itzuser\Configuration-as-Code-Lab",
    [string]$Owner       = "ibm-wsc",
    [string]$Repo        = "Configuration-as-Code-Lab",
    [string]$Branch      = "main",
    [string]$SchemaPath  = "schemas"
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
$StudentBranch = "student-$StudentNumber"
$plainPat = [System.Net.NetworkCredential]::new("", $Pat).Password
$pair     = "x-access-token:$plainPat"
$basic    = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
Write-Host "Cloning branch $StudentBranch into $CloneDirectory..."
git -c "http.extraHeader=Authorization: Basic $basic" clone -b $StudentBranch "https://github.com/$Owner/$Repo.git" $CloneDirectory
if ($LASTEXITCODE -ne 0) {
    Write-Error "git clone failed."
    exit 1
}
