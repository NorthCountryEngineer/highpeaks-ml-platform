#!/usr/bin/env bash
set -euo pipefail

# Minimal deployment script for High Peaks ML Platform

# Usage: ./deploy.sh [local|k8s]

local_deploy() {
  docker compose -f infrastructure/docker-compose.yml up -d
  echo "✅ Local deployment complete"
}

k8s_deploy() {
  TMPDIR=$(mktemp -d)
  export TMPDIR
  trap "rm -rf $TMPDIR" EXIT

  install_docker
  install_kubectl
  install_kind

k8s_deploy() {
  tmpdir=$(mktemp -d)
  export TMPDIR="$tmpdir"
  trap 'rm -rf "$tmpdir"' EXIT

  kind create cluster --name highpeaks-ml \
    --config infrastructure/k8s/kind-cluster.yaml 2>/dev/null || true

  docker build -t highpeaks-ml-platform:latest .

  echo "📥 Loading image into kind..."
  if ! kind load docker-image highpeaks-ml-platform:latest --name highpeaks-ml; then
    echo "⚠️ kind load failed, attempting docker save fallback..." >&2
    # kind may have cleaned up $TMPDIR on failure, recreate if needed
    if [[ ! -d "$TMPDIR" ]]; then
      TMPDIR=$(mktemp -d)
      export TMPDIR
    fi
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
