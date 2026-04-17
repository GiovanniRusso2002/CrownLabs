# 🚀 CrownLabs Local Development - Quick Reference

## Setup Veloce

```powershell
# 1. Setup iniziale (solo prima volta)
.\setup-local-k3s.ps1

# 2. Avvia tutto
.\start-local-dev.ps1

# 3. Apri browser → http://localhost:3000
```

## Script Disponibili

| Script | Descrizione |
|--------|-------------|
| `setup-local-k3s.ps1` | 🔧 Setup iniziale k3s + CRD (esegui UNA VOLTA) |
| `start-local-dev.ps1` | ▶️ Avvia tutti i servizi |
| `stop-local-dev.ps1` | ⏹️ Ferma tutti i servizi |
| `check-status.ps1` | 🔍 Verifica stato componenti |
| `start-qlkube-local.sh` | 🔀 Avvia qlkube da WSL (alternativo) |

## Architettura

```
Frontend (3000) → qlkube (8080) → kubectl proxy (8001) → k3s (WSL)
                                                             ↑
                                                    tenant-operator
```

## Porte Usate

- `3000` - Frontend React
- `8080` - qlkube (GraphQL)
- `8001` - kubectl proxy (API k8s)
- `6443` - k3s API server (interno WSL)

## Componenti Attivi

✅ **k3s cluster** (WSL) - con CRD CrownLabs  
✅ **kubectl proxy** - espone API k8s su HTTP  
✅ **tenant-operator** - solo tenant controller (workspace/instance/keycloak disabilitati)  
✅ **qlkube** - backend GraphQL  
✅ **frontend** - interfaccia React  

## Comandi Utili

```powershell
# Verifica stato
.\check-status.ps1

# Vedere risorse k8s
wsl bash -c "sudo k3s kubectl get tenants,workspaces,templates,instances --all-namespaces"

# Log tenant-operator
wsl bash -c "tail -f /tmp/tenant-operator.log"

# Log kubectl proxy
wsl bash -c "tail -f /tmp/kubectl-proxy.log"

# Riavvia k3s
wsl bash -c "sudo systemctl restart k3s"

# Test kubectl proxy
curl http://localhost:8001/version

# Test qlkube
curl http://localhost:8080

# Test API CrownLabs
curl http://localhost:8001/apis/crownlabs.polito.it/v1alpha1/workspaces
```

## Utente di Test

- **ID**: s343424
- **Nome**: Giovanni Russo
- **Email**: giovanni.developer@local.dev
- **Workspaces**: my-workspace (manager), shared-workspace (user)

## Troubleshooting

### Frontend bloccato su "Loading..."
```powershell
# Aspetta 15-20 secondi, poi ricarica la pagina
# Se persiste, verifica i servizi:
.\check-status.ps1
```

### kubectl proxy non risponde
```powershell
wsl bash -c "sudo pkill -f 'kubectl proxy'; nohup sudo k3s kubectl proxy --port=8001 --address=0.0.0.0 --accept-hosts='.*' > /tmp/kubectl-proxy.log 2>&1 &"
```

### qlkube non parte
```powershell
# Verifica che kubectl proxy sia attivo
curl http://localhost:8001/version

# Verifica il kubeconfig
Get-Content qlkube\kubeconfig-proxy.yaml
```

### Reset completo
```powershell
.\stop-local-dev.ps1
wsl bash -c "sudo systemctl stop k3s"
wsl bash -c "sudo /usr/local/bin/k3s-uninstall.sh"  # Opzionale: rimuove k3s
.\setup-local-k3s.ps1
```

## File Importanti

- `qlkube/kubeconfig-proxy.yaml` - Config qlkube → kubectl proxy
- `provisioning/local-dev/sample-resources.yaml` - Risorse di esempio
- `operators/deploy/crds/` - CRD di CrownLabs
- `/tmp/kubectl-proxy.log` (WSL) - Log kubectl proxy
- `/tmp/tenant-operator.log` (WSL) - Log operator

## Differenze con Produzione

| Aspetto | Locale | Produzione |
|---------|--------|------------|
| Cluster | k3s | Full Kubernetes |
| Controllers | Solo tenant | Tutti i controllers |
| Auth | Bypassata | OIDC/Keycloak |
| Dati | Locali | Persistenti |
| Instance | Mock/fake | VM reali |

## Documentazione Completa

Vedi: [README-LOCAL-DEV-K3S.md](README-LOCAL-DEV-K3S.md)

---

**Requisiti**: Windows 10/11, WSL2, Node.js 18+, Go 1.21+ (in WSL)
