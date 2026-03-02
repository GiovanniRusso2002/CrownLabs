# Start All CrownLabs Services
# Questo script avvia k3s, kubectl proxy, tenant-operator, qlkube e frontend

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "  Avvio Completo CrownLabs" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan

# Step 1: Avvio k3s
Write-Host "[1/5] Avvio k3s in WSL..." -ForegroundColor Yellow
wsl bash -c "sudo systemctl start k3s"
if ($LASTEXITCODE -ne 0) {
    Write-Host "  [X] Errore nell'avvio di k3s" -ForegroundColor Red
    Write-Host "  Inserisci la password quando richiesta" -ForegroundColor Yellow
    exit 1
}
Write-Host "  [OK] k3s avviato" -ForegroundColor Green
Start-Sleep -Seconds 3

# Step 2: Avvio kubectl proxy
Write-Host "`n[2/5] Avvio kubectl proxy..." -ForegroundColor Yellow
& .\start-proxy.ps1
Write-Host "`nPremi INVIO quando kubectl proxy è attivo (controlla la finestra che si è aperta)..." -ForegroundColor Cyan
Read-Host

# Verifica che kubectl proxy sia attivo
$proxyCheck = curl.exe -s http://localhost:8001/version 2>&1 | Select-String "major" -Quiet
if ($proxyCheck) {
    Write-Host "  [OK] kubectl proxy attivo" -ForegroundColor Green
} else {
    Write-Host "  [X] kubectl proxy non risponde" -ForegroundColor Red
    Write-Host "  Assicurati di aver inserito la password sudo nella finestra WSL" -ForegroundColor Yellow
    exit 1
}

# Step 3-5: Avvio servizi Node.js
Write-Host "`n[3/5] Avvio servizi (tenant-operator, qlkube, frontend)..." -ForegroundColor Yellow
.\start-services.ps1

Write-Host "`n============================================" -ForegroundColor Green
Write-Host "  [OK] Tutti i servizi avviati!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green

Write-Host "`nApri il browser: http://localhost:3000" -ForegroundColor Cyan
