#!/bin/bash
# =============================================================================
# Avvio componenti k3s per CrownLabs
# =============================================================================
# Avvia k3s e kubectl proxy
# =============================================================================

set -e

echo ""
echo "============================================"
echo "  Avvio componenti k3s"
echo "============================================"
echo ""

# [1/3] Verifica e avvia k3s
echo "[1/3] Verifico k3s..."
K3S_STATUS=$(systemctl is-active k3s 2>/dev/null || echo "inactive")

if [ "$K3S_STATUS" != "active" ]; then
    echo "  k3s non attivo. Avvio..."
    sudo systemctl start k3s
    sleep 8
    
    K3S_STATUS=$(systemctl is-active k3s 2>/dev/null || echo "inactive")
    if [ "$K3S_STATUS" != "active" ]; then
        echo "  [X] k3s non si avvia"
        echo "      Esegui prima: ./setup-local-k3s.ps1"
        exit 1
    fi
fi
echo "  [OK] k3s attivo"

# [2/3] Verifica CRD
echo ""
echo "[2/3] Verifico CRD..."
CRD_COUNT=$(sudo k3s kubectl get crds 2>/dev/null | grep crownlabs | wc -l)
if [ "$CRD_COUNT" -lt 5 ]; then
    echo "  [X] CRD mancanti. Esegui prima: ./setup-local-k3s.ps1"
    exit 1
fi
echo "  [OK] CRD presenti: $CRD_COUNT"

# [3/3] Avvio kubectl proxy
echo ""
echo "[3/3] Avvio kubectl proxy..."

# Cleanup vecchi proxy
sudo pkill -f 'kubectl proxy' 2>/dev/null || true
sleep 2

# Avvia proxy
nohup sudo k3s kubectl proxy --port=8001 --address=0.0.0.0 --accept-hosts='.*' --request-timeout=120s > /tmp/kubectl-proxy.log 2>&1 &
sleep 4

# Test proxy
PROXY_OK=false
for i in {1..5}; do
    if curl -s http://localhost:8001/version > /dev/null 2>&1; then
        PROXY_OK=true
        break
    fi
    sleep 1
done

if [ "$PROXY_OK" = false ]; then
    echo "  [X] kubectl proxy non risponde"
    echo "  Log:"
    cat /tmp/kubectl-proxy.log 2>/dev/null || echo "Nessun log disponibile"
    exit 1
fi

echo "  [OK] kubectl proxy attivo (porta 8001)"

# Riepilogo
echo ""
echo "============================================"
echo "  [OK] Componenti k3s avviati!"
echo "============================================"
echo ""
echo "Servizi attivi:"
echo "  - k3s cluster"
echo "  - kubectl proxy        http://localhost:8001"
echo ""
echo "Ora puoi avviare i servizi CrownLabs con:"
echo "  ./start-services.ps1"
echo ""
