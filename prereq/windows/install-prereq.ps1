# ─────────────────────────────────────────────────────────────
# prereq/windows/install-prereq.ps1
# Install prerequisites on Windows via Chocolatey (run as Administrator)
# Order: Chocolatey → Git Bash + make → Java (JAVA_REQUIRED, default 21) → Docker Desktop → mkcert
# nginx runs in a container — no host install needed.
# After install, run `make` from Git Bash (as Administrator for hosts file).
# ─────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"

function Ask-Install($name) {
    $ans = Read-Host "  Install $name? (y/n)"
    return ($ans -eq "y")
}

function Check-Command($cmd) {
    return [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
}

function Java-Major {
    if (-not (Check-Command java)) { return 0 }
    $line = (cmd /c "java -version 2>&1" | Select-Object -First 1)
    if ($line -match '"(\d+)(\.(\d+))?') {
        if ($Matches[1] -eq "1") { return [int]$Matches[3] } else { return [int]$Matches[1] }
    }
    return 0
}

Write-Host ""
Write-Host "  Windows Prerequisite Installer" -ForegroundColor White
Write-Host ""

# ── 1. Chocolatey ─────────────────────────────────────────────
Write-Host "  [1/5] Chocolatey" -ForegroundColor White
& "$PSScriptRoot\install-choco.ps1"

# ── 2. Git Bash + make (the Makefile and scripts are bash) ───
Write-Host ""
Write-Host "  [2/5] Git Bash + make" -ForegroundColor White
if (Check-Command git) { Write-Host "  -> Git already installed." -ForegroundColor Yellow }
elseif (Ask-Install "Git (includes Git Bash, curl, unzip, openssl)") { choco install git -y }
if (Check-Command make) { Write-Host "  -> make already installed." -ForegroundColor Yellow }
elseif (Ask-Install "make") { choco install make -y }

# ── 3. Java (JAVA_REQUIRED from .env, default 21) ─────────────
$jreq = 21
$envFile = Join-Path $PSScriptRoot "..\..\.env"
if (Test-Path $envFile) {
    $m = Select-String -Path $envFile -Pattern '^JAVA_REQUIRED="?(\d+)' | Select-Object -Last 1
    if ($m) { $jreq = [int]$m.Matches[0].Groups[1].Value }
}
Write-Host ""
Write-Host "  [3/5] Java $jreq+" -ForegroundColor White
$jv = Java-Major
if ($jv -ge $jreq) {
    Write-Host "  -> Java $jv already installed." -ForegroundColor Yellow
} else {
    if ($jv -gt 0) { Write-Host "  ! Java $jv found — $jreq+ required." -ForegroundColor Yellow }
    if (Ask-Install "Java $jreq (Eclipse Temurin)") {
        choco install "temurin$jreq" -y
        Write-Host "  [OK] Java $jreq installed." -ForegroundColor Green
    }
}

# ── 4. Docker Desktop ─────────────────────────────────────────
Write-Host ""
Write-Host "  [4/5] Docker Desktop" -ForegroundColor White
if (Check-Command docker) {
    Write-Host "  -> Docker already installed: $(docker --version)" -ForegroundColor Yellow
} elseif (Ask-Install "Docker Desktop") {
    choco install docker-desktop -y
    Write-Host "  [OK] Docker Desktop installed. Start it and finish setup (WSL2 backend)." -ForegroundColor Green
    Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
}

# ── 5. mkcert (optional) ─────────────────────────────────────
Write-Host ""
Write-Host "  [5/5] mkcert (optional — browser-trusted certs)" -ForegroundColor White
if (Check-Command mkcert) {
    Write-Host "  -> mkcert already installed — installing root CA..." -ForegroundColor Yellow
    mkcert -install
} elseif (Ask-Install "mkcert") {
    choco install mkcert -y
    mkcert -install
    Write-Host "  [OK] mkcert installed and root CA registered." -ForegroundColor Green
}

Write-Host ""
Write-Host "  Done. Open a NEW Git Bash (Run as Administrator) in the project and run: make" -ForegroundColor Green
Write-Host ""
