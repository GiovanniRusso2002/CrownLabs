# =============================================================================
# CrownLabs - Stop Sviluppo Locale
# =============================================================================
# Ferma tutti i servizi senza spegnere k3s
# =============================================================================

$ErrorActionPreference = "Continue"

Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  CrownLabs - Stop Servizi Locale                      ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Stop processi Windows
Write-Host "[1/2] Fermo processi Windows..." -ForegroundColor Yellow
$killed = 0

# Node processes (qlkube + frontend)
$nodeProcs = Get-Process node -ErrorAction SilentlyContinue
if ($nodeProcs) {
    $nodeProcs | Stop-Process -Force -ErrorAction SilentlyContinue
    $killed += $nodeProcs.Count
}

# Operator processes
$opProcs = Get-Process operator -ErrorAction SilentlyContinue
if ($opProcs) {
    $opProcs | Stop-Process -Force -ErrorAction SilentlyContinue
    $killed += $opProcs.Count
}

Write-Host "  ✓ Fermati $killed processi Windows" -ForegroundColor Green

# Stop processi WSL
Write-Host "`n[2/2] Fermo processi WSL..." -ForegroundColor Yellow
wsl bash -c @"
sudo pkill -f 'kubectl proxy' 2>/dev/null
pkill -f 'go run.*operator' 2>/dev/null
pkill -f '/tmp/operator' 2>/dev/null
pkill -f 'node.*qlkube' 2>/dev/null
"@

Start-Sleep -Seconds 2
Write-Host "  ✓ Processi WSL fermati" -ForegroundColor Green

# Verifica
Write-Host "`nVerifica processi:" -ForegroundColor Cyan
$nodeStillRunning = Get-Process node -ErrorAction SilentlyContinue
$proxyStillRunning = wsl bash -c "ps aux | grep 'kubectl proxy' | grep -v grep"

if ($nodeStillRunning -or $proxyStillRunning) {
    Write-Host "  ! Alcuni processi potrebbero essere ancora attivi" -ForegroundColor Yellow
} else {
    Write-Host "  ✓ Tutti i servizi fermati" -ForegroundColor Green
}

Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  ✓ Servizi fermati                                    ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

Write-Host "Note:" -ForegroundColor Cyan
Write-Host "  • k3s è ancora attivo in WSL" -ForegroundColor Gray
Write-Host "  • Per riavviare: .\start-local-dev.ps1" -ForegroundColor Gray
Write-Host "  • Per fermare k3s: wsl bash -c 'sudo systemctl stop k3s'" -ForegroundColor Gray
Write-Host ""
