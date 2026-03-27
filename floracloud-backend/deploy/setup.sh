#!/bin/bash
# FloraCloud – script de instalação no servidor (Ubuntu 22.04)
# Execute como root ou com sudo: bash setup.sh

set -e

echo "=== FloraCloud: instalação do servidor ==="

# ── Docker ────────────────────────────────────────────────────────────────────
if ! command -v docker &> /dev/null; then
    echo "[1/4] Instalando Docker..."
    apt-get update -qq
    apt-get install -y -qq ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        > /etc/apt/sources.list.d/docker.list
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl enable docker
    echo "[1/4] Docker instalado."
else
    echo "[1/4] Docker já instalado."
fi

# ── Diretório de dados ────────────────────────────────────────────────────────
echo "[2/4] Criando diretório de dados..."
mkdir -p /data/floracloud/sessions

# ── Clone do repositório ──────────────────────────────────────────────────────
echo "[3/4] Clonando repositório..."
if [ ! -d "/opt/floracloud" ]; then
    git clone --branch claude/create-floracloud-app-tivsf \
        https://github.com/eduwerneck/projetos.git /opt/floracloud-repo
    ln -s /opt/floracloud-repo/floracloud-backend /opt/floracloud
else
    echo "  Repositório já existe. Atualizando..."
    git -C /opt/floracloud-repo pull
fi

# ── Arquivo .env ──────────────────────────────────────────────────────────────
echo "[4/4] Configurando .env..."
if [ ! -f "/opt/floracloud/.env" ]; then
    cp /opt/floracloud/.env.example /opt/floracloud/.env
    echo "  IMPORTANTE: edite /opt/floracloud/.env se necessário."
fi

# ── Subir os serviços ─────────────────────────────────────────────────────────
echo "=== Iniciando FloraCloud com Docker Compose... ==="
cd /opt/floracloud
docker compose up -d --build

echo ""
echo "✓ FloraCloud está rodando!"
echo "  API:  http://$(curl -s ifconfig.me):8000"
echo "  Docs: http://$(curl -s ifconfig.me):8000/docs"
echo ""
echo "Para ver os logs: docker compose -f /opt/floracloud/docker-compose.yml logs -f"
