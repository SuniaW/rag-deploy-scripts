#!/bin/bash
# ============================================================
# 服务器 A 部署脚本（124.223.22.34 | 4核4G | 上海）
# Ollama + AgentX Java 后端
# ============================================================

set -e

DEPLOY_DIR="/usr/service"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_DIR="$DEPLOY_DIR/server-A"

echo "============================================"
echo " 服务器 A：全栈推理节点部署"
echo "============================================"

# 1. 环境检查
command -v docker &>/dev/null || { echo "❌ 请先安装 Docker"; exit 1; }
docker compose version &>/dev/null || { echo "❌ 需要 Docker Compose 插件"; exit 1; }

# 2. 创建目录 & 复制文件
mkdir -p "$SERVER_DIR/data/ollama"
cp docker-compose.yml "$SERVER_DIR/"
cd "$SERVER_DIR"

# 3. 停止旧服务（清理环境）
docker compose down --remove-orphans 2>/dev/null || true

# 4. 启动服务
echo "⏳ 正在启动 Ollama + AgentX 后端..."
docker compose up -d

# 5. 等待 Ollama 就绪
echo "⏳ 等待 Ollama 服务就绪..."
sleep 10

# 6. 拉取模型
echo "🧠 拉取聊天模型 qwen2.5:1.5b..."
docker exec agentx-ollama ollama pull qwen2.5:1.5b

echo "🧠 拉取向量模型 bge-m3..."
docker exec agentx-ollama ollama pull bge-m3

# 7. 模型预热（确保模型加载到内存）
echo "🔥 模型预热中..."
curl -s -X POST http://localhost:11434/api/generate \
  -d '{"model": "qwen2.5:1.5b", "prompt": "hi", "stream": false}' > /dev/null
curl -s -X POST http://localhost:11434/api/embeddings \
  -d '{"model": "bge-m3", "prompt": "warmup"}' > /dev/null

echo "============================================"
echo " ✅ 服务器 A 部署完成！"
echo "    Ollama API:    http://124.223.22.34:11434"
echo "    AgentX 后端:   http://124.223.22.34:8080"
echo ""
echo " ⚡ 模型常驻内存中，首请求无需加载时间"
echo "============================================"
