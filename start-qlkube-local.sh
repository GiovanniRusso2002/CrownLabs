#!/bin/bash
# =============================================================================
# Avvia qlkube da WSL (alternativa a avviarlo da Windows)
# =============================================================================

set -e

export PATH=$PATH:/usr/local/go/bin

echo "╔════════════════════════════════════════════════════════╗"
echo "║  qlkube - Avvio da WSL                                ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Verifica kubectl proxy
echo "[1/3] Verifico kubectl proxy..."
if ! curl -s http://localhost:8001/version --connect-timeout 2 > /dev/null; then
    echo "  ✗ kubectl proxy non risponde su porta 8001"
    echo ""
    echo "  Avvialo con:"
    echo "    nohup sudo k3s kubectl proxy --port=8001 --address=0.0.0.0 --accept-hosts='.*' > /tmp/kubectl-proxy.log 2>&1 &"
    echo ""
    exit 1
fi
echo "  ✓ kubectl proxy attivo"

# Verifica Node.js
echo ""
echo "[2/3] Verifico Node.js..."
if ! command -v node &> /dev/null; then
    echo "  ✗ Node.js non trovato. Installalo con:"
    echo "    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -"
    echo "    sudo apt-get install -y nodejs"
    exit 1
fi
NODE_VERSION=$(node --version)
echo "  ✓ Node.js $NODE_VERSION"

# Ferma istanze precedenti
echo ""
echo "[3/3] Pulizia processi precedenti..."
pkill -f 'node.*qlkube' 2>/dev/null || true
sleep 1
echo "  ✓ Processi puliti"

# Avvia qlkube
echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  Avvio qlkube...                                      ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

cd /mnt/c/Users/giovi/Desktop/EURECOM/CrownLabs/qlkube

export IN_CLUSTER=false
export KUBECONFIG=/mnt/c/Users/giovi/Desktop/EURECOM/CrownLabs/qlkube/kubeconfig-proxy.yaml

echo "Configurazione:"
echo "  • IN_CLUSTER: $IN_CLUSTER"
echo "  • KUBECONFIG: $KUBECONFIG"
echo "  • kubectl proxy: http://localhost:8001"
echo ""
echo "qlkube sarà disponibile su: http://localhost:8080"
echo "─────────────────────────────────────────────────────────"
echo ""

node src/index.js
