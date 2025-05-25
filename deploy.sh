#!/usr/bin/env bash
set -euo pipefail

# Force all Docker/Kind temp files into /tmp
export TMPDIR=/tmp

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

# Print disk usage information for operators
disk_usage_report() {
  echo "📊 Disk usage summary:" >&2
  df -h / /tmp | awk 'NR==1 || /\/$|\/tmp/' >&2
  if check_cmd docker; then
    echo "📊 Docker system disk usage:" >&2
    docker system df -v >&2 || true
  fi
}

# Ensure the given path has at least the specified bytes free
# Returns 0 if sufficient, 1 otherwise
require_space() {
  local path="$1"
  local required="$2"
  local avail
  avail=$(df --output=avail "$path" | tail -1)
  if (( avail * 1024 < required )); then
    echo "❌ Not enough space in $path (need $((required/1024/1024)) MiB, have $((avail/1024)) MiB)" >&2
    return 1
  fi
  return 0
}

# Ensure space exists; attempt docker cleanup once if not enough
ensure_space() {
  local path="$1"
  local required="$2"
  if require_space "$path" "$required"; then
    return 0
  fi
  if check_cmd docker; then
    echo "🧹 Attempting to free space with 'docker system prune'..." >&2
    docker system prune -af --volumes >/dev/null || true
  fi
  require_space "$path" "$required"
}

local_deploy() {
  install_docker
  echo "🐳 Building Docker image..."
  docker build -t highpeaks-ml-platform:latest .
  disk_usage_report
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

  disk_usage_report
  echo "🔄 Creating (or reusing) kind cluster..."
  if kind get clusters | grep -q highpeaks-ml; then
    echo "✔️ kind cluster 'highpeaks-ml' already exists"
  else
    kind create cluster --name highpeaks-ml \
      --config infrastructure/k8s/kind-cluster.yaml
  fi

  echo "🔧 Exporting kubeconfig..."
  kind export kubeconfig --name highpeaks-ml

  # force Kind to use /tmp as its scratch space
  unset TMPDIR

  # trying to clear "no space left on device" error
  echo "🧹 Cleaning up old temp folders and pruning volumes"
  TMPDIR="${DEPLOY_TMPDIR:-/tmp}"
  rm -f "$TMPDIR/highpeaks-ml-platform.tar"
  rm -f "$TMPDIR/.docker_temp_*" 2>/dev/null || true
  docker system prune --volumes

  echo "📥 Saving image to tarball in /tmp…"
  docker save highpeaks-ml-platform:latest -o /tmp/highpeaks-ml-platform.tar

  echo "📥 Loading image into kind from /tmp…"
  kind load image-archive /tmp/highpeaks-ml-platform.tar --name highpeaks-ml
  rm -f /tmp/highpeaks-ml-platform.tar

  echo "📑 Applying Kubernetes manifests..."
  kubectl apply -f infrastructure/k8s/namespace.yaml
  kubectl apply -f infrastructure/k8s/storage.yaml
  kubectl apply -f infrastructure/k8s/deployment.yaml
  kubectl apply -f infrastructure/k8s/service.yaml
  kubectl apply -f infrastructure/k8s/mlflow.yaml
  
  echo "✅ Kubernetes deployment complete"
  echo
  echo "🔍 Service Endpoints (cluster-internal IPs):"
  echo
  echo " • ML Platform API:"
  echo "     \$ kubectl get svc highpeaks-ml-platform -n highpeaks-ml"
  echo "     ➜ ClusterIP:$(kubectl get svc highpeaks-ml-platform -n highpeaks-ml -o jsonpath='{.spec.clusterIP}') Port:80"
  echo
  echo " • MLflow tracking UI:"
  echo "     \$ kubectl get svc mlflow-service      -n highpeaks-ml"
  echo "     ➜ ClusterIP:$(kubectl get svc mlflow-service      -n highpeaks-ml -o jsonpath='{.spec.clusterIP}') Port:5000"
  echo
  echo " • MinIO Console/API:"
  echo "     \$ kubectl get svc minio               -n highpeaks-ml"
  echo "     ➜ Console/API IP:$(kubectl get svc minio           -n highpeaks-ml -o jsonpath='{.spec.clusterIP}') Ports:9001/9000"
  echo
  echo "👉 To connect from your laptop, port-forward each service in a separate shell:"
  echo "     kubectl port-forward svc/highpeaks-ml-platform  -n highpeaks-ml 5000:80   # then curl http://localhost:5000/predict"
  echo "     kubectl port-forward svc/mlflow-service       -n highpeaks-ml 5001:5000 # then browse http://localhost:5001"
  echo "     kubectl port-forward svc/minio                -n highpeaks-ml 9001:9001 # then browse http://localhost:9001 (user/minioadmin)"
  echo
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
