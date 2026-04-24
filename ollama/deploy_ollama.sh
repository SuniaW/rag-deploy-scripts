#!/bin/bash
# =================================================================
# AgentX 基础设施部署脚本 - Ollama + Qwen2.5 (私有化 AI 大脑)
# =================================================================

DEPLOY_DIR="/usr/service/ollama"
MODEL_NAME="qwen2.5:1.5b"
EMBED_MODEL="bge-m3"

echo "🚀 开始部署 AgentX 私有大脑..."

# 1. 环境检查
if ! command -v docker &> /dev/null; then
    echo "❌ 错误: 未检测到 Docker，请先安装。"
    exit 1
fi

# 2. 创建目录
mkdir -p $DEPLOY_DIR
cd $DEPLOY_DIR || exit

# 4. 启动服务
echo "⏳ 正在启动 Ollama 容器..."
if docker compose version &> /dev/null; then
    docker compose down --remove-orphans &> /dev/null
    docker compose up -d
else
    docker-compose down --remove-orphans &> /dev/null
    docker-compose up -d
fi

# 5. 等待服务就绪并拉取模型
echo "📡 正在等待 Ollama 服务响应 (可能需要 10 秒)..."
sleep 10

echo "🧠 正在拉取聊天模型: $MODEL_NAME ..."
docker exec -it agentx-ollama ollama pull $MODEL_NAME

echo "🎨 正在拉取向量模型: $EMBED_MODEL ..."
docker exec -it agentx-ollama ollama pull $EMBED_MODEL

# 6. 获取 IPv4 地址并显示结果
IPV4_ADDR=$(curl -s -4 ifconfig.me || echo "124.223.22.34")

echo "-------------------------------------------------------"
if [ "$(docker ps -q -f name=agentx-ollama)" ]; then
    echo "✅ AgentX 私有大脑部署成功！"
    echo "🌐 API 访问地址: http://${IPV4_ADDR}:11434"
    echo "🤖 聊天模型: $MODEL_NAME"
    echo "🔎 向量模型: $EMBED_MODEL"
    echo ""
    echo "💡 [AgentX Java 配置提醒]:"
    echo "请修改 application.yml 中的 ai.ollama.base-url 为:"
    echo "http://${IPV4_ADDR}:11434"
else
    echo "❌ 部署失败，请运行 'docker logs agentx-ollama' 查看原因。"
fi
echo "-------------------------------------------------------"
EOF
