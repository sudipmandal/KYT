#!/usr/bin/env bash
# bootstrap-app-host.sh
# Ubuntu 25.10 headless bootstrap for Portainer, llama.cpp (Vulkan), and Open WebUI
# Run as root: sudo ./bootstrap-app-host.sh
set -euo pipefail

### -------- SETTINGS YOU MAY CHANGE --------
LINUX_USER="sudip"                            # Linux username that owns /home/sudip
APP_BASE="/home/${LINUX_USER}/apps"           # Base folder for bind mounts
PORTAINER_PORT=9000
OPENWEBUI_PORT=3000                           # Host port for Open WebUI -> container 8080
LLAMACPP_PORT=8080                            # Host port for llama.cpp -> container 8080
DOCKER_NETWORK="app_network"
# Optional: set a root password by exporting ROOT_PASSWORD before running
ROOT_PASSWORD=""

# Open WebUI will talk to llama.cpp via OpenAI-compatible API
OPENAI_BASE_URL="http://llama:${LLAMACPP_PORT}/v1"
# Generate a throwaway non-empty key for Open WebUI (the server doesn’t check it)
OPENAI_KEY="${OPENAI_KEY:-sk-$(openssl rand -hex 16)}"

### --------- PRE-FLIGHT CHECKS -------------
if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (sudo)."
  exit 1
fi

if ! id -u "${LINUX_USER}" >/dev/null 2>&1; then
  echo "User ${LINUX_USER} does not exist; please create it first or change LINUX_USER."
  exit 1
fi

mkdir -p "${APP_BASE}/portainer" \
         "${APP_BASE}/llama/models" "${APP_BASE}/llama/cache" \
         "${APP_BASE}/openwebui"
chown -R "${LINUX_USER}:${LINUX_USER}" "${APP_BASE}"

### ---------- ENABLE ROOT SSH --------------
# Permit root login; allow password auth (you can switch to keys later)
SSHD_CFG="/etc/ssh/sshd_config"
if ! grep -q "^PermitRootLogin" "${SSHD_CFG}"; then
  echo "PermitRootLogin yes" >> "${SSHD_CFG}"
else
  sed -i 's/^PermitRootLogin .*/PermitRootLogin yes/' "${SSHD_CFG}"
fi
if ! grep -q "^PasswordAuthentication" "${SSHD_CFG}"; then
  echo "PasswordAuthentication yes" >> "${SSHD_CFG}"
else
  sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' "${SSHD_CFG}"
fi
# Optionally set a root password if provided
if [[ -n "${ROOT_PASSWORD}" ]]; then
  echo "root:${ROOT_PASSWORD}" | chpasswd
fi
systemctl restart ssh || systemctl restart sshd || true

### --------- APT UPDATE/UPGRADE ------------
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get dist-upgrade -y

### ---- ENSURE wget/nano/curl FROM APT -----
# If snaps exist for these, remove them; then install APT packages.
if command -v snap >/dev/null 2>&1; then
  for pkg in wget curl nano docker; do
    if snap list 2>/dev/null | awk '{print $1}' | grep -qx "${pkg}"; then
      snap remove --purge "${pkg}" || true
    fi
  done
fi
apt-get install -y --no-install-recommends ca-certificates wget curl nano

### ------- MESA + VULKAN RUNTIME ----------
# Generic runtime useful for Intel/AMD via Mesa; includes vulkaninfo tool
apt-get install -y --no-install-recommends \
  mesa-utils mesa-vulkan-drivers libvulkan1 vulkan-tools

### -------- INSTALL DOCKER (non-snap) -----
# Official convenience script from get.docker.com
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sh /tmp/get-docker.sh
# Enable and add the regular user to the docker group (no sudo needed)
systemctl enable docker --now
usermod -aG docker "${LINUX_USER}" || true

### -------- CREATE DOCKER NETWORK ---------
# Create a user-defined bridge (attachable by local containers)
if ! docker network inspect "${DOCKER_NETWORK}" >/dev/null 2>&1; then
  docker network create "${DOCKER_NETWORK}" || true
fi

### ------------ CONTAINERS ----------------
# 1) Portainer CE
if docker ps -a --format '{{.Names}}' | grep -qx "portainer"; then
  echo "[portainer] Container exists; ensuring it’s on the network and started..."
  docker network connect "${DOCKER_NETWORK}" portainer 2>/dev/null || true
  docker update --restart unless-stopped portainer >/dev/null
  docker start portainer >/dev/null || true
else
  docker run -d --name portainer --hostname portainer \
    --restart unless-stopped --network "${DOCKER_NETWORK}" \
    -p ${PORTAINER_PORT}:9000 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${APP_BASE}/portainer:/data" \
    portainer/portainer-ce:latest
fi

# 2) llama.cpp (prefer Vulkan build if available; fall back to server)
LLAMA_IMG_VK="ghcr.io/ggml-org/llama.cpp:server-vulkan"
LLAMA_IMG_STD="ghcr.io/ggml-org/llama.cpp:server"
LLAMA_IMAGE=""
echo "[llama.cpp] Trying Vulkan-tagged image..."
if docker pull "${LLAMA_IMG_VK}"; then
  LLAMA_IMAGE="${LLAMA_IMG_VK}"
else
  echo "[llama.cpp] Vulkan image not available; falling back to CPU/server image."
  docker pull "${LLAMA_IMG_STD}"
  LLAMA_IMAGE="${LLAMA_IMG_STD}"
fi

if docker ps -a --format '{{.Names}}' | grep -qx "llama"; then
  echo "[llama] Container exists; updating restart policy and starting..."
  docker update --restart unless-stopped llama >/dev/null
  docker start llama >/dev/null || true
  # Ensure on network
  docker network connect "${DOCKER_NETWORK}" llama 2>/dev/null || true
else
  # Start the server listening on 0.0.0.0. If no model is mounted yet,
  # llama-server can be controlled via its OpenAI-compatible API to load one later.
  docker run -d --name llama --hostname llama \
    --restart unless-stopped --network "${DOCKER_NETWORK}" \
    -p ${LLAMACPP_PORT}:8080 \
    -v "${APP_BASE}/llama/models:/models" \
    -v "${APP_BASE}/llama/cache:/root/.cache" \
    --device /dev/dri:/dev/dri \
    "${LLAMA_IMAGE}" \
    --host 0.0.0.0
fi

# 3) Open WebUI (Docker Hub mirror -> talks to llama at http://llama:8080/v1)
# Note: primary upstream is ghcr.io/open-webui/open-webui; we use an
# unofficial Docker Hub mirror to satisfy "from Docker Hub" preference.
OPENWEBUI_IMG="backplane/open-webui:latest"
docker pull "${OPENWEBUI_IMG}"

if docker ps -a --format '{{.Names}}' | grep -qx "openwebui"; then
  echo "[openwebui] Container exists; restarting with updated env and mounts..."
  docker rm -f openwebui >/dev/null
fi

docker run -d --name openwebui --hostname openwebui \
  --restart unless-stopped --network "${DOCKER_NETWORK}" \
  -p ${OPENWEBUI_PORT}:8080 \
  -v "${APP_BASE}/openwebui:/app/backend/data" \
  -e OPENAI_API_BASE_URLS="${OPENAI_BASE_URL}" \
  -e OPENAI_API_KEYS="${OPENAI_KEY}" \
  "${OPENWEBUI_IMG}"

### --------------- SUMMARY ----------------
cat <<EOF

All set ✅

• Root SSH: enabled. If you set ROOT_PASSWORD, 'root' password updated.
• APT packages: wget, nano, curl from apt (not snap).
• Mesa + Vulkan runtime installed.
• Docker installed from get.docker.com and enabled.
• Docker network: ${DOCKER_NETWORK}

Containers (restart unless-stopped), all on ${DOCKER_NETWORK}:
  - Portainer CE   : http://<server-ip>:${PORTAINER_PORT}
    Data: ${APP_BASE}/portainer
  - llama.cpp      : http://<server-ip>:${LLAMACPP_PORT}  (OpenAI API at /v1)
    Models dir: ${APP_BASE}/llama/models   (place your *.gguf models here)
  - Open WebUI     : http://<server-ip>:${OPENWEBUI_PORT}
    Data: ${APP_BASE}/openwebui
    Connected to llama via ${OPENAI_BASE_URL} (key: ${OPENAI_KEY})

Tips:
  - After copying a model into ${APP_BASE}/llama/models, you can load it from Open WebUI
    (Settings → Connections) or via llama.cpp API.
  - To change ports or paths, rerun this script after editing the SETTINGS block at top.

EOF

