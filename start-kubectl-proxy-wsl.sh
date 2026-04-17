#!/bin/bash
# Avvia kubectl proxy

echo "Avvio kubectl proxy..."
sudo k3s kubectl proxy --port=8001 --address=0.0.0.0 --accept-hosts='.*' --request-timeout=120s
