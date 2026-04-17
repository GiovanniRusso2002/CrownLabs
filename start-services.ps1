# =============================================================================
# Avvio servizi CrownLabs (requires k3s + kubectl-proxy già attivi)
# =============================================================================

$ErrorActionPreference = "Continue"
$ROOT = $PSScriptRoot

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "  Avvio Servizi CrownLabs" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan

# Verifica prerequisiti
Write-Host "[1/5] Verifica prerequisiti..." -ForegroundColor Yellow

try {
    $proxyTest = Invoke-WebRequest -Uri 'http://localhost:8001/version' -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    Write-Host "  [OK] kubectl proxy attivo" -ForegroundColor Green
} catch {
    Write-Host "  [X] kubectl proxy NON attivo!" -ForegroundColor Red
    Write-Host "      Eseguilo prima con: wsl sudo bash /mnt/c/Users/giovi/Desktop/EURECOM/CrownLabs/start-k3s-components.sh" -ForegroundColor Yellow
    exit 1
}

# Cleanup processi vecchi
Write-Host "`n[2/5] Pulizia processi precedenti..." -ForegroundColor Yellow
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
wsl bash -c "pkill -f 'go run.*operator'; pkill -f '/tmp/operator'" 2>$null
Start-Sleep -Seconds 2
Write-Host "  [OK] Processi puliti" -ForegroundColor Green

# Compila e avvia tenant-operator
Write-Host "`n[3/5] Avvio tenant-operator..." -ForegroundColor Yellow
Write-Host "  Compilazione..." -ForegroundColor Gray

$buildCmd = "cd /mnt/c/Users/giovi/Desktop/EURECOM/CrownLabs/operators; go build -o /tmp/operator cmd/operator/main.go"
wsl bash -c $buildCmd 2>$null

$operatorCmd = "cd /mnt/c/Users/giovi/Desktop/EURECOM/CrownLabs/operators; nohup /tmp/operator --enable-tenant=true --enable-workspace=false --enable-instance=false --enable-keycloak=false --enable-webhooks=false --target-label=crownlabs.polito.it/operator-selector=local > /tmp/tenant-operator.log 2>&1 &"
wsl bash -c $operatorCmd

Start-Sleep -Seconds 3
Write-Host "  [OK] Tenant operator avviato" -ForegroundColor Green
Write-Host "      Log: wsl bash -c 'tail -f /tmp/tenant-operator.log'" -ForegroundColor Gray

#  Avvio qlkube
Write-Host "`n[4/5] Avvio qlkube..." -ForegroundColor Yellow
$env:IN_CLUSTER = 'false'
$env:KUBECONFIG = "$ROOT\qlkube\kubeconfig-proxy.yaml"

Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "cd '$ROOT\qlkube'; `$env:IN_CLUSTER='false'; `$env:KUBECONFIG='$ROOT\qlkube\kubeconfig-proxy.yaml'; Write-Host '=== qlkube ===' -ForegroundColor Cyan; node src/index.js"
) -WindowStyle Normal

Start-Sleep -Seconds 8

$qlkubeOk = $false
for ($i = 1; $i -le 10; $i++) {
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
    Write-Host "  [!] qlkube in avvio (controlla la finestra)" -ForegroundColor Yellow
}

# Avvio frontend
Write-Host "`n[5/5] Avvio frontend..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "cd '$ROOT\frontend'; Write-Host '=== Frontend ===' -ForegroundColor Cyan; npm start"
) -WindowStyle Normal

Start-Sleep -Seconds 5
Write-Host "  [OK] Frontend in avvio (porta 3000)" -ForegroundColor Green

# Riepilogo
Write-Host "`n============================================" -ForegroundColor Green
Write-Host "  [OK] Tutti i servizi avviati!" -ForegroundColor Green  
Write-Host "============================================`n" -ForegroundColor Green

Write-Host "Servizi:" -ForegroundColor Cyan
Write-Host "  - k3s cluster (WSL)" -ForegroundColor Gray
Write-Host "  - kubectl proxy        http://localhost:8001" -ForegroundColor Gray
Write-Host "  - tenant-operator      (log: wsl bash -c 'tail -f /tmp/tenant-operator.log')" -ForegroundColor Gray
Write-Host "  - qlkube               http://localhost:8080" -ForegroundColor White
Write-Host "  - frontend             http://localhost:3000" -ForegroundColor Yellow

Write-Host "`nApri il browser:" -ForegroundColor Cyan
Write-Host "  http://localhost:3000`n" -ForegroundColor White
