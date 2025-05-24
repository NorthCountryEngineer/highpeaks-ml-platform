#!/usr/bin/env bash

set -e

# High Peaks ML Platform deployment script
# Usage: ./deploy.sh [local|k8s]
# If no argument is provided, the script prompts for deployment type.

check_cmd() {
  command -v "$1" >/dev/null 2>&1
}

install_docker() {
  if check_cmd docker; then
    return
  fi
  echo "Docker not found. Attempting installation..."
  if check_cmd apt-get; then
    sudo apt-get update && sudo apt-get install -y docker.io docker-compose-plugin || true
  elif check_cmd brew; then
    brew install docker docker-compose || true
  else
    echo "Please install Docker manually." >&2
  fi
}

install_kubectl() {
  if check_cmd kubectl; then
    return
  fi
  echo "kubectl not found. Attempting installation..."
  if check_cmd apt-get; then
    sudo apt-get update && sudo apt-get install -y kubectl || true
  elif check_cmd brew; then
    brew install kubectl || true
  else
    echo "Please install kubectl manually." >&2
  fi
}

install_kind() {
  if check_cmd kind; then
    return
  fi
  echo "kind not found. Attempting installation..."
  if check_cmd apt-get; then
    sudo apt-get update && sudo apt-get install -y kind || true
  elif check_cmd brew; then
    brew install kind || true
  else
    echo "Please install kind manually." >&2
  fi
}

local_deploy() {
  install_docker
  echo "Building Docker image..."
  docker build -t highpeaks-ml-platform:latest .
  echo "Starting local stack via docker compose..."
  docker compose -f infrastructure/docker-compose.yml up -d
}

k8s_deploy() {
  install_docker
  install_kubectl
  install_kind

  echo "Building Docker image..."
  docker build -t highpeaks-ml-platform:latest .

  echo "Creating kind cluster if needed..."
  if ! kind get clusters | grep -q highpeaks-ml; then
    kind create cluster --config infrastructure/k8s/kind-cluster.yaml --name highpeaks-ml
  fi

  echo "Loading image into kind..."
  kind load docker-image highpeaks-ml-platform:latest --name highpeaks-ml

  echo "Applying Kubernetes manifests..."
  kubectl apply -f infrastructure/k8s/
}

MODE="$1"
if [[ -z "$MODE" ]]; then
  echo "Select deployment target:" >&2
  echo "1) Local docker-compose" >&2
  echo "2) Kubernetes (kind)" >&2
  read -rp "Enter choice [1/2]: " choice
  if [[ "$choice" == "2" ]]; then
    MODE="k8s"
  else
    MODE="local"
  fi
fi

case "$MODE" in
  local)
    local_deploy
    ;;
  k8s)
    k8s_deploy
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    exit 1
    ;;
fi

echo "Deployment complete."
