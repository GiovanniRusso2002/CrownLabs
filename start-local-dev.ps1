# =============================================================================
# CrownLabs - Avvio Sviluppo Locale
# =============================================================================
# k3s + tenant-controller + kubectl proxy + qlkube + frontend
# =============================================================================

$ErrorActionPreference = "Continue"
$ROOT = $PSScriptRoot

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "  CrownLabs - Avvio Locale (k3s + Tenant Controller)" -ForegroundColor Cyan
Write-Host "================================================================`n" -ForegroundColor Cyan

# ============================================================================
# [1/6] Verifica k3s
# ============================================================================
Write-Host "[1/6] Verifico k3s..." -ForegroundColor Yellow
$k3sStatus = wsl bash -c "systemctl is-active k3s"

if ($k3sStatus -ne "active") {
    Write-Host "  k3s non attivo. Avvio..." -ForegroundColor Yellow
    wsl bash -c "sudo systemctl start k3s"
    Start-Sleep -Seconds 8
    
    $k3sStatus = wsl bash -c "systemctl is-active k3s"
    if ($k3sStatus -ne "active") {
        Write-Host "  [X] k3s non si avvia. Esegui prima: .\setup-local-k3s.ps1" -ForegroundColor Red
        exit 1
    }
}
Write-Host "  [OK] k3s attivo" -ForegroundColor Green

# ============================================================================
# [2/6] Verifica CRD
# ============================================================================
Write-Host "`n[2/6] Verifico CRD..." -ForegroundColor Yellow
$crds = wsl bash -c "sudo k3s kubectl get crds | grep crownlabs | wc -l"
if ([int]$crds -lt 5) {
    Write-Host "  [X] CRD mancanti. Esegui prima: .\setup-local-k3s.ps1" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] CRD presenti: $crds" -ForegroundColor Green

# ============================================================================
# [3/6] Cleanup processi vecchi
# ============================================================================
Write-Host "`n[3/6] Pulizia processi precedenti..." -ForegroundColor Yellow
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process operator -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
wsl bash -c "sudo pkill -f 'kubectl proxy'; pkill -f 'go run.*operator'; pkill -f '/tmp/operator'" 2>$null
Start-Sleep -Seconds 2
Write-Host "  [OK] Processi puliti" -ForegroundColor Green

# ============================================================================
# [4/6] Avvio kubectl proxy
# ============================================================================
Write-Host "`n[4/6] Avvio kubectl proxy..." -ForegroundColor Yellow
$proxyCmd = "nohup sudo k3s kubectl proxy --port=8001 --address=0.0.0.0 --accept-hosts='.*' --request-timeout=120s > /tmp/kubectl-proxy.log 2>&1 &"
wsl bash -c $proxyCmd
Start-Sleep -Seconds 4

# Test proxy
$proxyOk = $false
for ($i = 1; $i -le 5; $i++) {
    try {
        $resp = Invoke-WebRequest -Uri 'http://localhost:8001/version' -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
        if ($resp.StatusCode -eq 200) {
            $proxyOk = $true
            break
        }
    } catch {
        Start-Sleep -Seconds 1
    }
}

if (-not $proxyOk) {
    Write-Host "  [X] kubectl proxy non risponde" -ForegroundColor Red
    Write-Host "  Log: " -ForegroundColor Yellow
    wsl bash -c "cat /tmp/kubectl-proxy.log"
    exit 1
}
Write-Host "  [OK] kubectl proxy attivo (porta 8001)" -ForegroundColor Green

# ============================================================================
# [5/6] Compila e avvia tenant-operator
# ============================================================================
Write-Host "`n[5/6] Avvio tenant-operator..." -ForegroundColor Yellow
Write-Host "  Compilazione operator..." -ForegroundColor Gray

# Compila operator
$buildCmd = "cd /mnt/c/Users/giovi/Desktop/EURECOM/CrownLabs/operators; go build -o /tmp/operator cmd/operator/main.go"
wsl bash -c $buildCmd

# Avvia operator
$operatorCmd = "cd /mnt/c/Users/giovi/Desktop/EURECOM/CrownLabs/operators; nohup /tmp/operator --enable-tenant=true --enable-workspace=false --enable-instance=false --enable-keycloak=false --enable-webhooks=false --target-label=crownlabs.polito.it/operator-selector=local > /tmp/tenant-operator.log 2>&1 &"
wsl bash -c $operatorCmd
Start-Sleep -Seconds 5

# Verifica operator
$operatorRunning = wsl bash -c "ps aux | grep '/tmp/operator' | grep -v grep"
if ($operatorRunning) {
    Write-Host "  [OK] Tenant operator attivo" -ForegroundColor Green
    Write-Host "    Log: wsl bash -c 'tail -f /tmp/tenant-operator.log'" -ForegroundColor Gray
} else {
    Write-Host "  [!] Operator potrebbe non essere attivo. Verifica i log:" -ForegroundColor Yellow
    Write-Host "    wsl bash -c 'tail /tmp/tenant-operator.log'" -ForegroundColor Gray
}

# ============================================================================
# [6/6] Avvio qlkube e frontend
# ============================================================================
Write-Host "`n[6/6] Avvio qlkube e frontend..." -ForegroundColor Yellow

# Avvia qlkube
Write-Host "  Avvio qlkube..." -ForegroundColor Gray
$env:IN_CLUSTER = 'false'
$env:KUBECONFIG = "$ROOT\qlkube\kubeconfig-proxy.yaml"

Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "cd '$ROOT\qlkube'; `$env:IN_CLUSTER='false'; `$env:KUBECONFIG='$ROOT\qlkube\kubeconfig-proxy.yaml'; Write-Host '=== qlkube ===' -ForegroundColor Cyan; node src/index.js"
) -WindowStyle Normal

Start-Sleep -Seconds 6

# Test qlkube
$qlkubeOk = $false
for ($i = 1; $i -le 8; $i++) {
    try {
        $resp = Invoke-WebRequest -Uri 'http://localhost:8080' -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
        if ($resp.StatusCode -eq 200) {
            $qlkubeOk = $true
            break
        }
    } catch {
        Start-Sleep -Seconds 1
    }
}

if ($qlkubeOk) {
    Write-Host "  [OK] qlkube attivo (porta 8080)" -ForegroundColor Green
} else {
    Write-Host "  [!] qlkube potrebbe essere ancora in avvio..." -ForegroundColor Yellow
}

# Avvia frontend
Write-Host "  Avvio frontend..." -ForegroundColor Gray
Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "cd '$ROOT\frontend'; Write-Host '=== Frontend ===' -ForegroundColor Cyan; npm start"
) -WindowStyle Normal

Start-Sleep -Seconds 5
Write-Host "  [OK] Frontend in avvio (porta 3000)" -ForegroundColor Green

# ============================================================================
# Riepilogo
# ============================================================================
Write-Host "`n================================================================" -ForegroundColor Green
Write-Host "  [OK] Tutti i servizi avviati!" -ForegroundColor Green
Write-Host "================================================================`n" -ForegroundColor Green

Write-Host "Servizi attivi:" -ForegroundColor Cyan
Write-Host "  [*] k3s cluster                  " -ForegroundColor White -NoNewline
Write-Host "(WSL)" -ForegroundColor Gray
Write-Host "  [*] kubectl proxy                " -ForegroundColor White -NoNewline
Write-Host "http://localhost:8001" -ForegroundColor Gray
Write-Host "  [*] tenant-operator              " -ForegroundColor White -NoNewline
Write-Host "(solo tenant controller)" -ForegroundColor Gray
Write-Host "  [*] qlkube                       " -ForegroundColor White -NoNewline
Write-Host "http://localhost:8080" -ForegroundColor Gray
Write-Host "  [*] frontend                     " -ForegroundColor White -NoNewline
Write-Host "http://localhost:3000" -ForegroundColor Yellow

Write-Host "`nUtente di test:" -ForegroundColor Cyan
Write-Host "  - ID: s343424" -ForegroundColor Gray
Write-Host "  - Nome: Giovanni Russo" -ForegroundColor Gray
Write-Host "  - Workspaces: my-workspace, shared-workspace" -ForegroundColor Gray

Write-Host "`nComandi utili:" -ForegroundColor Cyan
Write-Host "  - Vedere workspaces:           " -ForegroundColor White -NoNewline
Write-Host "wsl bash -c 'sudo k3s kubectl get workspaces'" -ForegroundColor Gray
Write-Host "  - Vedere tenants:              " -ForegroundColor White -NoNewline
Write-Host "wsl bash -c 'sudo k3s kubectl get tenants'" -ForegroundColor Gray
Write-Host "  - Log tenant-operator:         " -ForegroundColor White -NoNewline
Write-Host "wsl bash -c 'tail -f /tmp/tenant-operator.log'" -ForegroundColor Gray
Write-Host "  - Fermare tutto:               " -ForegroundColor White -NoNewline
Write-Host ".\stop-local-dev.ps1" -ForegroundColor Gray

Write-Host "`nAttendi 10-15 secondi, poi apri il browser:" -ForegroundColor Yellow
Write-Host "   http://localhost:3000`n" -ForegroundColor White
