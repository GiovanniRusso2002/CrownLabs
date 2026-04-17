# =============================================================================
# CrownLabs - Setup Iniziale k3s + CRD
# =============================================================================
# Esegui questo script SOLO LA PRIMA VOLTA per configurare k3s con le CRD
# =============================================================================

$ErrorActionPreference = "Stop"

Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  CrownLabs - Setup k3s Locale                         ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Verifica WSL
Write-Host "[1/5] Verifico WSL..." -ForegroundColor Yellow
try {
    $wslVersion = wsl --version 2>&1
    Write-Host "  ✓ WSL disponibile" -ForegroundColor Green
} catch {
    Write-Host "  ✗ WSL non disponibile. Installa WSL2 prima di continuare." -ForegroundColor Red
    exit 1
}

# Installa/Avvia k3s
Write-Host "`n[2/5] Setup k3s..." -ForegroundColor Yellow
Write-Host "  (Chiederà la password sudo)" -ForegroundColor Gray

$k3sCheck = wsl bash -c "which k3s 2>/dev/null"
if (-not $k3sCheck) {
    Write-Host "  Installo k3s (può richiedere qualche minuto)..." -ForegroundColor Yellow
    wsl bash -c "curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 --disable traefik"
    Start-Sleep -Seconds 10
} else {
    Write-Host "  k3s già installato" -ForegroundColor Gray
}

# Avvia k3s se non attivo
$k3sStatus = wsl bash -c "systemctl is-active k3s 2>&1"
if ($k3sStatus -ne "active") {
    Write-Host "  Avvio k3s..." -ForegroundColor Yellow
    wsl bash -c "sudo systemctl start k3s"
    Start-Sleep -Seconds 8
}

$k3sStatus = wsl bash -c "systemctl is-active k3s 2>&1"
if ($k3sStatus -ne "active") {
    Write-Host "  ✗ k3s non si è avviato correttamente" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ k3s attivo e funzionante" -ForegroundColor Green

# Installa CRD
Write-Host "`n[3/5] Installo CRD di CrownLabs..." -ForegroundColor Yellow
$crdPath = "/mnt/c/Users/giovi/Desktop/EURECOM/CrownLabs/operators/deploy/crds"
wsl bash -c "sudo k3s kubectl apply -f $crdPath --wait" 2>&1 | Out-Null
Start-Sleep -Seconds 3

$crds = wsl bash -c "sudo k3s kubectl get crds | grep crownlabs | wc -l"
Write-Host "  ✓ Installate $crds CRD CrownLabs" -ForegroundColor Green

# Applica risorse di esempio
Write-Host "`n[4/5] Creo risorse di esempio..." -ForegroundColor Yellow
$samplePath = "/mnt/c/Users/giovi/Desktop/EURECOM/CrownLabs/provisioning/local-dev/sample-resources.yaml"
wsl bash -c "sudo k3s kubectl apply -f $samplePath" 2>&1 | Out-Null
Start-Sleep -Seconds 2
Write-Host "  ✓ Risorse create (Tenant + Workspaces)" -ForegroundColor Green

# Verifica risorse
Write-Host "`n[5/5] Verifico installazione..." -ForegroundColor Yellow
$workspaces = wsl bash -c "sudo k3s kubectl get workspaces --no-headers 2>/dev/null | wc -l"
$tenants = wsl bash -c "sudo k3s kubectl get tenants --no-headers 2>/dev/null | wc -l"

Write-Host "  ✓ Workspaces: $workspaces" -ForegroundColor Green
Write-Host "  ✓ Tenants: $tenants" -ForegroundColor Green

Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  ✓ Setup completato con successo!                     ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

Write-Host "Prossimo passo:" -ForegroundColor Cyan
Write-Host "  .\start-local-dev.ps1" -ForegroundColor White
Write-Host ""
