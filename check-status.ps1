# =============================================================================
# CrownLabs - Verifica Stato Servizi
# =============================================================================
# Controlla lo stato di tutti i componenti del setup locale
# =============================================================================

$ErrorActionPreference = "Continue"

Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  CrownLabs - Verifica Stato Componenti                ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$allOk = $true

# ============================================================================
# [1] k3s
# ============================================================================
Write-Host "[1/7] k3s cluster..." -ForegroundColor Yellow
try {
    $k3sStatus = wsl bash -c "systemctl is-active k3s 2>&1"
    if ($k3sStatus -eq "active") {
        Write-Host "  ✓ k3s attivo" -ForegroundColor Green
        
        # Verifica nodi
        $nodes = wsl bash -c "sudo k3s kubectl get nodes --no-headers 2>/dev/null | wc -l"
        Write-Host "    Nodi: $nodes" -ForegroundColor Gray
    } else {
        Write-Host "  ✗ k3s NON attivo (stato: $k3sStatus)" -ForegroundColor Red
        $allOk = $false
    }
} catch {
    Write-Host "  ✗ Errore verifica k3s: $_" -ForegroundColor Red
    $allOk = $false
}

# ============================================================================
# [2] CRD
# ============================================================================
Write-Host "`n[2/7] CRD CrownLabs..." -ForegroundColor Yellow
try {
    $crds = wsl bash -c "sudo k3s kubectl get crds 2>/dev/null | grep crownlabs"
    if ($crds) {
        $crdCount = ($crds -split "`n").Count
        Write-Host "  ✓ $crdCount CRD installate" -ForegroundColor Green
        $crds -split "`n" | ForEach-Object {
            Write-Host "    • $($_ -split '\s+' | Select-Object -First 1)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ✗ Nessuna CRD trovata. Esegui: .\setup-local-k3s.ps1" -ForegroundColor Red
        $allOk = $false
    }
} catch {
    Write-Host "  ✗ Errore verifica CRD: $_" -ForegroundColor Red
    $allOk = $false
}

# ============================================================================
# [3] Risorse CrownLabs
# ============================================================================
Write-Host "`n[3/7] Risorse CrownLabs..." -ForegroundColor Yellow
try {
    $tenants = wsl bash -c "sudo k3s kubectl get tenants --no-headers 2>/dev/null | wc -l"
    $workspaces = wsl bash -c "sudo k3s kubectl get workspaces --no-headers 2>/dev/null | wc -l"
    $templates = wsl bash -c "sudo k3s kubectl get templates --all-namespaces --no-headers 2>/dev/null | wc -l"
    $instances = wsl bash -c "sudo k3s kubectl get instances --all-namespaces --no-headers 2>/dev/null | wc -l"
    
    Write-Host "  Tenants:    $tenants" -ForegroundColor Gray
    Write-Host "  Workspaces: $workspaces" -ForegroundColor Gray
    Write-Host "  Templates:  $templates" -ForegroundColor Gray
    Write-Host "  Instances:  $instances" -ForegroundColor Gray
    
    if ([int]$tenants -eq 0 -or [int]$workspaces -eq 0) {
        Write-Host "  ! Poche risorse. Verifica: wsl bash -c 'sudo k3s kubectl get tenants,workspaces'" -ForegroundColor Yellow
    } else {
        Write-Host "  ✓ Risorse presenti" -ForegroundColor Green
    }
} catch {
    Write-Host "  ✗ Errore verifica risorse: $_" -ForegroundColor Red
}

# ============================================================================
# [4] kubectl proxy
# ============================================================================
Write-Host "`n[4/7] kubectl proxy..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri 'http://localhost:8001/version' -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Write-Host "  ✓ kubectl proxy attivo (porta 8001)" -ForegroundColor Green
        
        # Test API CrownLabs
        try {
            $apiTest = Invoke-WebRequest -Uri 'http://localhost:8001/apis/crownlabs.polito.it' -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
            Write-Host "    API CrownLabs accessibili" -ForegroundColor Gray
        } catch {
            Write-Host "    ! API CrownLabs non accessibili" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "  ✗ kubectl proxy NON risponde" -ForegroundColor Red
    Write-Host "    Avvialo con: wsl bash -c 'nohup sudo k3s kubectl proxy --port=8001 --address=0.0.0.0 --accept-hosts=\".*\" > /tmp/kubectl-proxy.log 2>&1 &'" -ForegroundColor Yellow
    $allOk = $false
}

# ============================================================================
# [5] tenant-operator
# ============================================================================
Write-Host "`n[5/7] tenant-operator..." -ForegroundColor Yellow
try {
    $operatorProc = wsl bash -c "ps aux | grep '/tmp/operator' | grep -v grep"
    if ($operatorProc) {
        Write-Host "  ✓ tenant-operator attivo" -ForegroundColor Green
        
        # Controlla log per errori
        $recentLog = wsl bash -c "tail -5 /tmp/tenant-operator.log 2>/dev/null"
        if ($recentLog -match "error|panic|fatal") {
            Write-Host "    ! Possibili errori nei log recenti" -ForegroundColor Yellow
        }
    } else {
        $goRunProc = wsl bash -c "ps aux | grep 'go run.*operator' | grep -v grep"
        if ($goRunProc) {
            Write-Host "  ⚠ tenant-operator in esecuzione (go run mode)" -ForegroundColor Yellow
        } else {
            Write-Host "  ✗ tenant-operator NON attivo" -ForegroundColor Red
            Write-Host "    Log: wsl bash -c 'tail /tmp/tenant-operator.log'" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "  ✗ Errore verifica operator: $_" -ForegroundColor Red
}

# ============================================================================
# [6] qlkube
# ============================================================================
Write-Host "`n[6/7] qlkube..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri 'http://localhost:8080' -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Write-Host "  ✓ qlkube attivo (porta 8080)" -ForegroundColor Green
        
        # Test GraphQL query
        try {
            $headers = @{'Content-Type'='application/json'}
            $body = '{"query":"{ __typename }"}'
            $gqlTest = Invoke-WebRequest -Uri 'http://localhost:8080/' -Method POST -Headers $headers -Body $body -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
            if ($gqlTest.StatusCode -eq 200) {
                Write-Host "    GraphQL endpoint funzionante" -ForegroundColor Gray
            }
        } catch {
            Write-Host "    ! GraphQL endpoint non risponde correttamente" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "  ✗ qlkube NON risponde" -ForegroundColor Red
    
    # Verifica se il processo node è attivo
    $nodeProcs = Get-Process node -ErrorAction SilentlyContinue
    if ($nodeProcs) {
        Write-Host "    Processo node attivo ma non risponde (potrebbe essere in avvio)" -ForegroundColor Yellow
    } else {
        Write-Host "    Nessun processo node attivo" -ForegroundColor Red
    }
    $allOk = $false
}

# ============================================================================
# [7] frontend
# ============================================================================
Write-Host "`n[7/7] frontend..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri 'http://localhost:3000' -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Write-Host "  ✓ frontend attivo (porta 3000)" -ForegroundColor Green
    }
} catch {
    Write-Host "  ⚠ frontend non risponde (potrebbe essere in avvio o non partito)" -ForegroundColor Yellow
    Write-Host "    Verifica la finestra PowerShell del frontend" -ForegroundColor Gray
}

# ============================================================================
# Riepilogo
# ============================================================================
Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
if ($allOk) {
    Write-Host "║  ✓ Tutti i componenti critici sono attivi!           ║" -ForegroundColor Green
} else {
    Write-Host "║  ⚠ Alcuni componenti non sono attivi                 ║" -ForegroundColor Yellow
}
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# ============================================================================
# Suggerimenti
# ============================================================================
Write-Host "Comandi utili:" -ForegroundColor Cyan
Write-Host "  • Riavvia tutto:               " -ForegroundColor White -NoNewline
Write-Host ".\stop-local-dev.ps1 ; .\start-local-dev.ps1" -ForegroundColor Gray
Write-Host "  • Log kubectl proxy:           " -ForegroundColor White -NoNewline
Write-Host "wsl bash -c 'tail -f /tmp/kubectl-proxy.log'" -ForegroundColor Gray
Write-Host "  • Log tenant-operator:         " -ForegroundColor White -NoNewline
Write-Host "wsl bash -c 'tail -f /tmp/tenant-operator.log'" -ForegroundColor Gray
Write-Host "  • Lista workspaces:            " -ForegroundColor White -NoNewline
Write-Host "wsl bash -c 'sudo k3s kubectl get workspaces'" -ForegroundColor Gray
Write-Host "  • Descrivi tenant:             " -ForegroundColor White -NoNewline
Write-Host "wsl bash -c 'sudo k3s kubectl describe tenant s343424'" -ForegroundColor Gray
Write-Host ""
