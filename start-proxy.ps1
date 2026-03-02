# Script per avviare solo kubectl proxy in una finestra separata
Write-Host "Avvio kubectl proxy in finestra separata..." -ForegroundColor Cyan

# Prova prima con Windows Terminal
try {
    Start-Process wt -ArgumentList "wsl", "sudo", "k3s", "kubectl", "proxy", "--port=8001"
    Write-Host "[OK] kubectl proxy avviato in Windows Terminal" -ForegroundColor Green
} catch {
    # Fallback su WSL diretto
    Start-Process wsl -ArgumentList "sudo", "k3s", "kubectl", "proxy", "--port=8001"
    Write-Host "[OK] kubectl proxy avviato in finestra WSL" -ForegroundColor Green
}

Write-Host "`nAttendo 5 secondi per l'avvio..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Verifica
$check = curl.exe -s http://localhost:8001/version 2>&1 | Select-String "major" -Quiet
if ($check) {
    Write-Host "[OK] kubectl proxy confermato attivo!" -ForegroundColor Green
} else {
    Write-Host "[!] kubectl proxy potrebbe richiedere la password sudo" -ForegroundColor Yellow
    Write-Host "    Controlla la finestra che si è aperta" -ForegroundColor Yellow
}
