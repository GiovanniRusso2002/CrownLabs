# CrownLabs - Sviluppo Locale con k3s + Tenant Controller

Setup semplificato per sviluppare il frontend CrownLabs usando:
- **k3s** locale (WSL) con le CRD di CrownLabs
- **tenant-controller** (tutti gli altri controller disabilitati)
- **qlkube** (reale, non mock) che interroga k3s via kubectl proxy
- **frontend** React

## 🚀 Quick Start

### 1. Setup Iniziale (solo la prima volta)

```powershell
.\setup-local-k3s.ps1
```

Questo script:
- Installa k3s in WSL (se non presente)
- Installa tutte le CRD di CrownLabs
- Crea risorse di esempio (Tenant + Workspaces)

### 2. Avvia i Servizi

```powershell
.\start-local-dev.ps1
```

Questo script:
- Avvia k3s (se non attivo)
- Avvia kubectl proxy (porta 8001)
- Compila e avvia tenant-operator (solo tenant controller)
- Avvia qlkube (porta 8080)
- Avvia frontend (porta 3000)

**Attendi 10-15 secondi**, poi apri: **http://localhost:3000**

### 3. Ferma i Servizi

```powershell
.\stop-local-dev.ps1
```

(k3s rimane attivo in background)

## 📋 Architettura

```
┌─────────────┐
│  Frontend   │ http://localhost:3000
│  (React)    │
└──────┬──────┘
       │
       ↓ GraphQL
┌─────────────┐
│   qlkube    │ http://localhost:8080
└──────┬──────┘
       │
       ↓ HTTP
┌─────────────┐
│kubectl proxy│ http://localhost:8001
└──────┬──────┘
       │
       ↓ K8s API
┌─────────────┐       ┌──────────────────┐
│     k3s     │◄──────┤ tenant-operator  │
│   (WSL)     │       │ (solo tenant)    │
└─────────────┘       └──────────────────┘
     │
     └─ CRD: Tenant, Workspace, Template, Instance
```

## 🔧 Componenti

### k3s (WSL)
- Cluster Kubernetes locale
- Contiene le CRD di CrownLabs
- Gestito da systemd: `wsl bash -c "systemctl status k3s"`

### kubectl proxy
- Espone le API di k3s su `http://localhost:8001`
- Senza autenticazione (per sviluppo locale)
- Log: `wsl bash -c "cat /tmp/kubectl-proxy.log"`

### tenant-operator
- **Solo tenant controller abilitato**
- Gli altri controller sono disabilitati:
  - ❌ workspace controller
  - ❌ instance controller
  - ❌ keycloak controller
  - ❌ webhooks
- Log: `wsl bash -c "tail -f /tmp/tenant-operator.log"`

### qlkube
- Backend GraphQL che interroga k3s
- Configurato con `kubeconfig-proxy.yaml` → `http://localhost:8001`
- `IN_CLUSTER=false` (usa kubectl proxy invece di ServiceAccount)

### frontend
- Interfaccia React
- Si connette a qlkube su `http://localhost:8080`

## 👤 Utente di Test

L'utente configurato per lo sviluppo locale è:

- **ID**: `s343424`
- **Nome**: Giovanni Russo
- **Email**: giovanni.developer@local.dev
- **Workspaces**:
  - `my-workspace` (manager)
  - `shared-workspace` (user)

## 🔍 Comandi Utili

### Verificare lo stato

```powershell
# k3s attivo?
wsl bash -c "systemctl is-active k3s"

# kubectl proxy risponde?
curl http://localhost:8001/version

# qlkube risponde?
curl http://localhost:8080

# Vedere le workspaces
wsl bash -c "sudo k3s kubectl get workspaces"

# Vedere i tenants
wsl bash -c "sudo k3s kubectl get tenants"

# Vedere tutte le risorse CrownLabs
wsl bash -c "sudo k3s kubectl get tenants,workspaces,templates,instances --all-namespaces"
```

### Log dei servizi

```powershell
# Log kubectl proxy
wsl bash -c "tail -f /tmp/kubectl-proxy.log"

# Log tenant-operator
wsl bash -c "tail -f /tmp/tenant-operator.log"

# Log qlkube (vedi finestra PowerShell separata)

# Log frontend (vedi finestra PowerShell separata)
```

### Ricreare le risorse di esempio

```powershell
wsl bash -c "sudo k3s kubectl delete -f /mnt/c/Users/giovi/Desktop/EURECOM/CrownLabs/provisioning/local-dev/sample-resources.yaml"
wsl bash -c "sudo k3s kubectl apply -f /mnt/c/Users/giovi/Desktop/EURECOM/CrownLabs/provisioning/local-dev/sample-resources.yaml"
```

## 🐛 Troubleshooting

### Frontend bloccato su "Loading..."

Le API di k3s possono essere lente al primo avvio. Attendi 15-20 secondi e ricarica la pagina.

### kubectl proxy non risponde

```powershell
# Verifica lo stato
curl http://localhost:8001/version

# Riavvia il proxy
wsl bash -c "sudo pkill -f 'kubectl proxy'"
wsl bash -c "nohup sudo k3s kubectl proxy --port=8001 --address=0.0.0.0 --accept-hosts='.*' > /tmp/kubectl-proxy.log 2>&1 &"
```

### Tenant operator non parte

```powershell
# Verifica che Go sia installato in WSL
wsl bash -c "go version"

# Verifica il log
wsl bash -c "tail -50 /tmp/tenant-operator.log"

# Ricompila manualmente
wsl bash -c "cd /mnt/c/Users/giovi/Desktop/EURECOM/CrownLabs/operators && go build -o /tmp/operator cmd/operator/main.go"
```

### qlkube non si connette

```powershell
# Verifica che kubectl proxy sia attivo
curl http://localhost:8001/apis/crownlabs.polito.it

# Verifica la configurazione
Get-Content qlkube\kubeconfig-proxy.yaml

# Avvia manualmente
cd qlkube
$env:IN_CLUSTER='false'
$env:KUBECONFIG="$PWD\kubeconfig-proxy.yaml"
node src/index.js
```

### Porta già in uso

```powershell
# Ferma tutti i servizi
.\stop-local-dev.ps1

# Verifica che non ci siano processi rimasti
Get-Process node -ErrorAction SilentlyContinue
wsl bash -c "ps aux | grep kubectl"
```

### k3s non parte

```powershell
# Verifica lo stato
wsl bash -c "sudo systemctl status k3s"

# Riavvia k3s
wsl bash -c "sudo systemctl restart k3s"

# Se k3s non è installato, reinstallalo
wsl bash -c "curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 --disable traefik"
```

### Reset completo

```powershell
# 1. Ferma tutto
.\stop-local-dev.ps1

# 2. Ferma k3s
wsl bash -c "sudo systemctl stop k3s"

# 3. (Opzionale) Rimuovi k3s completamente
wsl bash -c "sudo /usr/local/bin/k3s-uninstall.sh"

# 4. Ricomincia dal setup
.\setup-local-k3s.ps1
```

## 📁 File Importanti

- `setup-local-k3s.ps1` - Setup iniziale (esegui una volta sola)
- `start-local-dev.ps1` - Avvia tutti i servizi
- `stop-local-dev.ps1` - Ferma tutti i servizi
- `qlkube/kubeconfig-proxy.yaml` - Configurazione qlkube per kubectl proxy
- `provisioning/local-dev/sample-resources.yaml` - Risorse di esempio (Tenant, Workspaces, ecc.)
- `operators/deploy/crds/` - Custom Resource Definitions di CrownLabs

## 🎯 Differenza con Mock Server

| Aspetto | Mock Server | k3s + Tenant Controller |
|---------|-------------|------------------------|
| **Dati** | Fake/statici | Reali dal cluster k3s |
| **CRD** | ❌ No | ✅ Installate |
| **Controller** | ❌ No | ✅ Tenant controller attivo |
| **Persistenza** | ❌ No | ✅ Dati persistiti in k3s |
| **CRUD** | ⚠️ Simulato | ✅ Reale (create/update/delete) |
| **Setup** | Semplice | Richiede k3s + WSL |

## 📝 Note

- k3s rimane attivo anche dopo `stop-local-dev.ps1`
- Il tenant operator gestisce **solo** i tenant, gli altri controller sono disabilitati
- Non serve far girare instance-controller, workspace-controller, ecc.
- L'autenticazione OIDC è bypassata in sviluppo locale
- I dati sono locali e non sincronizzati con il cluster di produzione

---

**Requisiti**: Windows 10/11, WSL2, Node.js 18+, Go 1.21+ (in WSL)
