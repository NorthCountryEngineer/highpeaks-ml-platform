#!/usr/bin/env bash
set -euo pipefail

# High Peaks ML Platform deployment script
# Usage: ./deploy.sh [local|k8s]
# If no argument is provided, prompts for deployment type.

check_cmd() {
  command -v "$1" &>/dev/null
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

local_deploy() {
  install_docker
  echo "🐳 Building Docker image..."
  docker build -t highpeaks-ml-platform:latest .
  echo "📦 Starting local stack via Docker Compose..."
  docker compose -f infrastructure/docker-compose.yml up -d
  echo "✅ Local docker-compose deployment complete"
}

k8s_deploy() {
  install_docker
  install_kubectl
  install_kind

  echo "🐳 Building Docker image..."
  docker build -t highpeaks-ml-platform:latest .

  echo "🔄 Creating (or reusing) kind cluster..."
  if kind get clusters | grep -q highpeaks-ml; then
    echo "✔️ kind cluster 'highpeaks-ml' already exists"
  else
    kind create cluster --name highpeaks-ml \
      --config infrastructure/k8s/kind-cluster.yaml
  fi

  echo "📥 Saving image to tarball and loading into kind..."
  IMAGE_TAR="/tmp/highpeaks-ml-platform.tar"
  docker save -o "$IMAGE_TAR" highpeaks-ml-platform:latest
  kind load image-archive "$IMAGE_TAR" --name highpeaks-ml
  rm -f "$IMAGE_TAR"

  echo "📑 Applying Kubernetes manifests..."
  kubectl apply -f infrastructure/k8s/
  echo "✅ Kubernetes deployment complete"
}


################################################################################
# Main
################################################################################

MODE="${1:-}"
if [[ -z "$MODE" ]]; then
  echo "Select deployment target:"
  echo "  1) Local docker-compose"
  echo "  2) Kubernetes (kind)"
  read -rp "Enter choice [1/2]: " choice
  if [[ "$choice" == "2" ]]; then
    MODE="k8s"
  else
    MODE="local"
  fi
fi

case "$MODE" in
  local) local_deploy ;;
  k8s)   k8s_deploy   ;;
  *)
    echo "Unknown mode: $MODE" >&2
    exit 1
    ;;
esac

echo "🎉 All done!"
