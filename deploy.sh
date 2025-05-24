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
