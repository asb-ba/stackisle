# ─────────────────────────────────────────────────────────────
# prereq/windows/install-choco.ps1
# Install Chocolatey on Windows if not already installed
# Run as Administrator in PowerShell
# ─────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "  Checking Chocolatey..." -ForegroundColor White

if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "  -> Chocolatey already installed: $(choco --version)" -ForegroundColor Yellow
    exit 0
}

Write-Host "  ! Chocolatey not found." -ForegroundColor Yellow
$answer = Read-Host "  Install Chocolatey now? (y/n)"
if ($answer -ne "y") {
    Write-Host "  Skipped. Chocolatey is required to continue." -ForegroundColor Red
    exit 1
}

Write-Host "  Installing Chocolatey..." -ForegroundColor Cyan

Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = `
    [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString(
    'https://community.chocolatey.org/install.ps1'))

Write-Host "  Chocolatey installed successfully." -ForegroundColor Green
