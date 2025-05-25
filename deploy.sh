#!/usr/bin/env bash
set -euo pipefail

# Minimal deployment script for High Peaks ML Platform

# Usage: ./deploy.sh [local|k8s]

local_deploy() {
  docker compose -f infrastructure/docker-compose.yml up -d
  echo "✅ Local deployment complete"
}

install_docker() {
  if check_cmd docker; then
    echo "✔️ Docker already installed"
  else
    echo "🛠️ Installing Docker..."
    sudo apt-get update
    sudo apt-get install -y docker.io docker-compose-plugin
    echo "✔️ Docker installed"
  fi

  # ensure 'docker' group exists
  if ! getent group docker >/dev/null; then
    echo "👥 Creating 'docker' group..."
    sudo groupadd docker
  fi

  # pick the non-root user that invoked this script
  TARGET_USER="${SUDO_USER:-$USER}"
  if [[ "$TARGET_USER" == "root" ]]; then
    echo "⚠️  Running as root; skipping 'docker' group membership (not needed for root)."
  else
    if id -nG "$TARGET_USER" | grep -qw docker; then
      echo "✔️ $TARGET_USER is already in the 'docker' group"
    else
      echo "🔐 Adding $TARGET_USER to 'docker' group (you may need to log out & back in)..."
      sudo usermod -aG docker "$TARGET_USER"
    fi
  fi
}

install_kubectl() {
  if check_cmd kubectl; then
    echo "✔️ kubectl already installed"
    return
  fi
  echo "🛠️ Installing kubectl..."
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

  # fetch Google APT signing key into the recommended location
  sudo mkdir -p /usr/share/keyrings

  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | \
    sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

  # add the official k8s repo
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" \
    | sudo tee /etc/apt/sources.list.d/kubernetes.list

  # update & install
  sudo apt-get update
  sudo apt-get install -y kubectl

  echo "✔️ kubectl installed: $(kubectl version --client --short)"
}


install_kind() {
  if check_cmd kind; then
    echo "✔️ kind already installed"
    return
  fi
  echo "🛠️ Installing kind..."
  KIND_VER=v0.24.0
  curl -fsSL "https://kind.sigs.k8s.io/dl/${KIND_VER}/kind-linux-amd64" -o ./kind
  chmod +x ./kind
  sudo mv ./kind /usr/local/bin/kind
  echo "✔️ kind installed: $(kind version)"
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
