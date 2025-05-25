#!/usr/bin/env bash
set -euo pipefail

# Minimal deployment script for High Peaks ML Platform

# Usage: ./deploy.sh [local|k8s]

local_deploy() {
  docker compose -f infrastructure/docker-compose.yml up -d
  echo "✅ Local deployment complete"
}

# Print disk usage information for operators
disk_usage_report() {
  echo "📊 Disk usage summary:" >&2
  df -h / /tmp | awk 'NR==1 || /\/$|\/tmp/' >&2
  if check_cmd docker; then
    echo "📊 Docker system disk usage:" >&2
    docker system df -v >&2 || true
  fi
}

k8s_deploy() {
  TMPDIR=$(mktemp -d)
  export TMPDIR
  trap 'rm -rf "$TMPDIR"' EXIT

  install_docker
  install_kubectl
  install_kind

  kind create cluster --name highpeaks-ml \
    --config infrastructure/k8s/kind-cluster.yaml 2>/dev/null || true

  echo "🐳 Building Docker image..."
  docker build -t highpeaks-ml-platform:latest .
  
  echo "🔄 Creating (or reusing) kind cluster..."
  if kind get clusters | grep -q highpeaks-ml; then
    echo "✔️ kind cluster 'highpeaks-ml' already exists"
  else
    kind create cluster --name highpeaks-ml \
      --config infrastructure/k8s/kind-cluster.yaml
  fi
  
  echo "📥 Loading image into kind..."
    if ! kind load docker-image highpeaks-ml-platform:latest --name highpeaks-ml; then
      echo "⚠️ kind load failed, attempting docker save fallback..." >&2
      if docker save highpeaks-ml-platform:latest -o "$TMPDIR/images.tar" && \
         kind load image-archive "$TMPDIR/images.tar" --name highpeaks-ml; then
        echo "✔️ Image loaded via docker save fallback"
      else
        echo "❌ Failed to load Docker image into kind" >&2
        disk_usage_report
        exit 1
    fi
  fi

  kubectl apply -f infrastructure/k8s/namespace.yaml
  kubectl apply -f infrastructure/k8s/storage.yaml
  kubectl apply -f infrastructure/k8s/mlflow.yaml
  kubectl apply -f infrastructure/k8s/deployment.yaml
  kubectl apply -f infrastructure/k8s/service.yaml

  echo "✅ Kubernetes deployment complete"
}

MODE="${1:-local}"
case "$MODE" in
  local) local_deploy ;;
  k8s)   k8s_deploy   ;;
  *)
    echo "Usage: $0 [local|k8s]" >&2
    exit 1
    ;;
esac

echo "🎉 Deployment finished"
