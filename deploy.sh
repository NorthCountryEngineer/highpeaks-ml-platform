#!/usr/bin/env bash
set -euo pipefail

# Check if a command exists
check_cmd() {
  command -v "$1" >/dev/null 2>&1
}

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


install_minikube() {
  if check_cmd minikube; then
    echo "✔️ minikube already installed"
    return
  fi
  echo "🛠️ Installing minikube..."
  curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  chmod +x minikube
  sudo mv minikube /usr/local/bin/minikube
  echo "✔️ minikube installed: $(minikube version --short)"
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
  install_minikube

  minikube start --driver=docker || true

  echo "🐳 Building Docker image..."
  docker build -t highpeaks-ml-platform:latest .
  
  echo "🔄 Creating (or reusing) minikube cluster..."
  minikube status >/dev/null 2>&1 || minikube start --driver=docker

  echo "📥 Loading image into minikube..."
  if ! minikube image load highpeaks-ml-platform:latest; then
    echo "❌ Failed to load Docker image into minikube" >&2
    disk_usage_report
    exit 1
  fi

  kubectl apply -f infrastructure/k8s/namespace.yaml
  kubectl apply -f infrastructure/k8s/storage.yaml
  kubectl apply -f infrastructure/k8s/mlflow.yaml
  kubectl apply -f infrastructure/k8s/deployment.yaml
  kubectl apply -f infrastructure/k8s/service.yaml

  echo "✅ Kubernetes deployment complete"
}

# Print access information for the selected mode
print_endpoints() {
  if [[ "$1" == "local" ]]; then
    cat <<EOF
📬 Endpoints:
  - Flask API:       http://localhost:5000
  - MLflow Tracking: http://localhost:5001
  - MinIO Console:   http://localhost:9001
EOF
  else
    cat <<EOF
📬 Endpoints inside the cluster:
  - Flask API service: highpeaks-ml-platform.highpeaks-ml.svc.cluster.local:80
  - MLflow service:    mlflow-service.highpeaks-ml.svc.cluster.local:5000

To access them from the host, run:
  kubectl port-forward svc/highpeaks-ml-platform -n highpeaks-ml 5000:80 &
  kubectl port-forward svc/mlflow-service -n highpeaks-ml 5001:5000 &
EOF
  fi
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
print_endpoints "$MODE"
