<#
.SYNOPSIS
    Downloads the JSON schemas from the Configuration-as-Code-Lab repository
    to a local workstation directory.

.DESCRIPTION
    Lists the files in the repository's "schemas" folder through the GitHub
    API and downloads every *.json file over HTTPS. The destination directory
    is created if it does not exist. Existing files are overwritten.
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
